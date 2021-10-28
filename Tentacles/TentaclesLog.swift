//
//  TentaclesLog.swift
//  Tentacles
//
//  Created by Michael Leavy on 10/28/21.
//  Copyright © 2021 Squid Store. All rights reserved.
//

import Foundation

public protocol TentaclesLogging {
    func log(_ message: String, logOption: TentaclesLog.LogOption)
    func log(_ dictionary: [String: String], logOption: TentaclesLog.LogOption)
}

public struct TentaclesLog {

    public struct NetworkRequestLogOption: OptionSet, CustomStringConvertible {
        public let rawValue: Int
        
        public static let url = NetworkRequestLogOption(rawValue: 1)
        public static let cURL = NetworkRequestLogOption(rawValue: 2)
        public static let pretty = NetworkRequestLogOption(rawValue: 4)
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        public var description: String {
            switch rawValue {
            case NetworkRequestLogOption.url.rawValue:
                return "url"
            case NetworkRequestLogOption.cURL.rawValue:
                return "curl"
            case NetworkRequestLogOption.pretty.rawValue:
                return "pretty"
            default:
                return "unknown"
            }
        }
    }
    
    public struct LogOption: OptionSet, CustomStringConvertible {
        public let rawValue: Int
        
        public static let request = LogOption(rawValue: 1)
        public static let response = LogOption(rawValue: 2)
        public static let warning = LogOption(rawValue: 4)
        public static let error = LogOption(rawValue: 8)
        public static let info = LogOption(rawValue: 16)
        public static let all: LogOption = [.request, .response, .warning, .error, .info]
        public static let none: LogOption = []
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        public var description: String {
            switch rawValue {
            case LogOption.request.rawValue:
                return "request"
            case LogOption.response.rawValue:
                return "response"
            case LogOption.warning.rawValue:
                return "warning"
            case LogOption.error.rawValue:
                return "error"
            case LogOption.info.rawValue:
                return "info"
            default:
                return "unknown"
            }
        }
    }
    
    public var networkRequestLogOptions: [NetworkRequestLogOption] = [.url]
    public var logger: TentaclesLogging?
    public var logOptions: LogOption = .none
    public var redactions: [String] = ["password"]
    public var redactionSubstitute = "<redacted>"
    
    
    internal func log(_ message: String, logOption: LogOption) {
        logger?.log(message, logOption: logOption)
    }
    
    internal func logRequest(_ request: URLRequest) {
        var dictionary = [String: String]()
        let isPretty = networkRequestLogOptions.contains(.pretty)
        for option in networkRequestLogOptions {
            switch option.rawValue {
            case NetworkRequestLogOption.url.rawValue:
                dictionary[option.description] = request.absoluteString(redactions: redactions, redactionSubstitute: redactionSubstitute)
            case NetworkRequestLogOption.cURL.rawValue:
                dictionary[option.description] = request.cURL(pretty: isPretty, redactions: redactions, redactionSubstitute: redactionSubstitute)
            default:
                break
            }
        }
        
        logger?.log(dictionary, logOption: .request)
    }
}

private extension String {
    mutating func appendIf(_ string: String?) {
        if let s = string {
            self.append(s)
        }
    }
    
    mutating func append(_ queryItem: URLQueryItem) {
        self.append(self.count == 0 ? "?" : "&")
        self.append(queryItem.name)
        self.append("=")
        self.appendIf(queryItem.value)
    }
}

extension URLRequest {
    public func absoluteString(redactions: [String], redactionSubstitute: String) -> String {
        guard let url = url else {return ""}
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var path = ""
        path.appendIf(components?.scheme)
        if path.count > 0 {
            path.append("://")
        }
        path.appendIf(components?.host)
        path.appendIf(components?.path)
        
        var queryItems = [URLQueryItem]()
        
        if let items = components?.queryItems {
            for item in items {
                if redactions.contains(item.name) {
                    queryItems.append(URLQueryItem(name: item.name, value: redactionSubstitute))
                }
                else {
                    queryItems.append(item)
                }
            }
        }
        
        var queryString = ""
        for item in queryItems {
            queryString.append(item)
        }
        
        path.append(queryString)
        return path
    }

    public func cURL(pretty: Bool, redactions: [String], redactionSubstitute: String) -> String {
        let newLine = pretty ? "\\\n" : ""
        let method = (pretty ? "--request " : "-X ") + "\(self.httpMethod ?? "GET") \(newLine)"
        let url: String = (pretty ? "--url " : "") + "\'\(self.absoluteString(redactions: redactions, redactionSubstitute: redactionSubstitute))\' \(newLine)"
        
        var cURL = "curl "
        var header = ""
        var data: String = ""
        
        if let httpHeaders = self.allHTTPHeaderFields, httpHeaders.keys.count > 0 {
            for (key,value) in httpHeaders {
                let resultValue = redactions.contains(key) ? redactionSubstitute : value
                header += (pretty ? "--header " : "-H ") + "\'\(key): \(resultValue)\' \(newLine)"
            }
        }
        
        if let bodyData = self.httpBody, let bodyString = String(data: bodyData, encoding: .utf8),  !bodyString.isEmpty {
            let redacted = redact(bodyString, redactions: redactions, redactionSubstitute: redactionSubstitute)
            data = "--data '\(redacted)'"
        }
        
        cURL += method + url + header + data
        
        return cURL
    }
    
    private func redact(_ from: String, redactions: [String], redactionSubstitute: String) -> String {
        // preconditions
        guard from.first == "{", from.last == "}" else {return from}
        
        
        let quotedRedactions = redactions.map { item in
            return "\"\(item)\""
        }
        
        var s = from
        s.removeFirst()
        s.removeLast()
        var components = [String]()
        let outerComponents = s.components(separatedBy: ",")
        for component in outerComponents {
            let innerComponents = component.components(separatedBy: ":")
            guard innerComponents.count == 2 else {
                components.append(component)
                continue
            }
            if quotedRedactions.contains(innerComponents[0]) {
                components.append(innerComponents[0] + ":" + "\"\(redactionSubstitute)\"")
            }
            else {
                components.append(component)
            }
        }
        
        var result = ""
        for component in components {
            if result.count > 0 {
                result.append(",")
            }
            result.append(component)
        }
        result = "{" + result
        result.append("}")
        
        return result
    }
}

private extension Data {
    func redacted(redactions: [String], redactionSubstitute: String) -> Data {
        do {
            let decoded = try JSONSerialization.jsonObject(with: self, options: [])
            guard var dictionary = decoded as? [String: Any] else {return self}
            print("got json dict")
            print(dictionary)
            
            redact(dictionary: &dictionary, redactions: redactions, redactionSubstitute: redactionSubstitute)
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: [])
                return jsonData
            }
            catch {
                return self
            }
        }
        catch {
            return self
        }
    }
    
    func redact(dictionary: inout [String: Any], redactions: [String], redactionSubstitute: String) {
        for (key, value) in dictionary {
            if redactions.contains(key) {
                dictionary[key] = redactionSubstitute
            }
            else if var innerDictionary = value as? [String: Any] {
                redact(dictionary: &innerDictionary, redactions: redactions, redactionSubstitute: redactionSubstitute)
                dictionary[key] = innerDictionary
            }
        }
    }
}
