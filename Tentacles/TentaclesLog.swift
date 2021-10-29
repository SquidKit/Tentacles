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
    
    public struct NetworkResponseLogOption: OptionSet, CustomStringConvertible {
        public let rawValue: Int
        
        public static let status = NetworkResponseLogOption(rawValue: 1)
        public static let body = NetworkResponseLogOption(rawValue: 2)
        public static let headers = NetworkResponseLogOption(rawValue: 4)
        public static let pretty = NetworkResponseLogOption(rawValue: 8)
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        public var description: String {
            switch rawValue {
            case NetworkResponseLogOption.status.rawValue:
                return "status"
            case NetworkResponseLogOption.body.rawValue:
                return "body"
            case NetworkResponseLogOption.headers.rawValue:
                return "headers"
            case NetworkResponseLogOption.pretty.rawValue:
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
    public var networkResponseLogOptions: [NetworkResponseLogOption] = [.status, .body]
    public var logger: TentaclesLogging?
    public var logOptions: LogOption = .none
    public var requestRedactions: [String] = ["password"]
    public var requestRedactionSubstitute = "<redacted>"
    public var responseRedactions: [String] = []
    public var responseRedactionSubstitute = "<redacted>"
    
    static func redact(dictionary: inout [String: Any], redactions: [String], redactionSubstitute: String) {
        guard !redactions.isEmpty else {return}
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
    
    static func redact(dictionaries: [[String: Any]], redactions: [String], redactionSubstitute: String) -> [[String: Any]] {
        guard !redactions.isEmpty else {return dictionaries}
        var result = [[String: Any]]()
        for dictionary in dictionaries {
            var redacted = dictionary
            redact(dictionary: &redacted, redactions: redactions, redactionSubstitute: redactionSubstitute)
            result.append(redacted)
        }
        return result
    }
    
    internal func log(_ message: String, logOption: LogOption) {
        guard logOptions.contains(logOption) else {return}
        logger?.log(message, logOption: logOption)
    }
    
    internal func logRequest(_ request: URLRequest) {
        guard logOptions.contains(.request) else {return}
        var dictionary = [String: String]()
        let isPretty = networkRequestLogOptions.contains(.pretty)
        for option in networkRequestLogOptions {
            switch option.rawValue {
            case NetworkRequestLogOption.url.rawValue:
                dictionary[option.description] = request.asLogString(redactions: requestRedactions, redactionSubstitute: requestRedactionSubstitute)
            case NetworkRequestLogOption.cURL.rawValue:
                dictionary[option.description] = request.cURL(pretty: isPretty, redactions: requestRedactions, redactionSubstitute: requestRedactionSubstitute)
            default:
                break
            }
        }
        
        logger?.log(dictionary, logOption: .request)
    }
    
    internal func logResponse(_ result: Result) {
        guard logOptions.contains(.response) else {return}
        let dictionary = result.asLogDictionary(options: networkResponseLogOptions, redactions: responseRedactions, redactionSubstitute: responseRedactionSubstitute)
        logger?.log(dictionary, logOption: .response)
        
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
    public func asLogString(redactions: [String], redactionSubstitute: String) -> String {
        guard let url = url else {return ""}
        guard !redactions.isEmpty else {return url.absoluteString}
        
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
        let url: String = (pretty ? "--url " : "") + "\'\(self.asLogString(redactions: redactions, redactionSubstitute: redactionSubstitute))\' \(newLine)"
        
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
        guard !redactions.isEmpty else {return from}
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

/*
private extension Data {
    func redact(redactions: [String], redactionSubstitute: String) -> Data {
        guard !redactions.isEmpty else {return self}
        do {
            let decoded = try JSONSerialization.jsonObject(with: self, options: [])
            
            if let redacted = redactAsObject(jsonObject: decoded, redactions: redactions, redactionSubstitute: redactionSubstitute) {
                return redacted
            }
            else if let redacted = redactAsArray(jsonObject: decoded, redactions: redactions, redactionSubstitute: redactionSubstitute) {
                return redacted
            }
            else {
                return self
            }
        }
        catch {
            return self
        }
    }
    
    private func redactAsObject(jsonObject: Any, redactions: [String], redactionSubstitute: String) -> Data? {
        guard var dictionary = jsonObject as? [String: Any] else {return nil}
        
        TentaclesLog.redact(dictionary: &dictionary, redactions: redactions, redactionSubstitute: redactionSubstitute)
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: [])
            return jsonData
        }
        catch {
            return nil
        }
    }
    
    private func redactAsArray(jsonObject: Any, redactions: [String], redactionSubstitute: String) -> Data? {
        guard let dictionaryArray = jsonObject as? [[String: Any]] else {return self}
        
        let redacted = TentaclesLog.redact(dictionaries: dictionaryArray, redactions: redactions, redactionSubstitute: redactionSubstitute)
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: redacted, options: [])
            return jsonData
        }
        catch {
            return nil
        }
    }
}
 */

extension Response {
    func asLogString(redactions: [String], redactionSubstitute: String, pretty: Bool) -> String {
        if !jsonDictionary.isEmpty {
            var dictionary = jsonDictionary
            TentaclesLog.redact(dictionary: &dictionary, redactions: redactions, redactionSubstitute: redactionSubstitute)
            return String(jsonObject: dictionary, pretty: pretty) ?? ""
        }
        else if !jsonArray.isEmpty {
            let dictionaries = TentaclesLog.redact(dictionaries: jsonArray, redactions: redactions, redactionSubstitute: redactionSubstitute)
            return String(jsonObject: dictionaries, pretty: pretty) ?? ""
        }
        else {
            return description
        }
    }
    
    func asLogDictionary(options: [TentaclesLog.NetworkResponseLogOption], redactions: [String], redactionSubstitute: String) -> [String: String] {
        var result = [String: String]()
        
        let isPretty = options.contains(.pretty)
        let newLine = isPretty ? "\\\n" : ""
        
        if options.contains(.body) {
            result[TentaclesLog.NetworkResponseLogOption.body.description] = asLogString(redactions: redactions, redactionSubstitute: redactionSubstitute, pretty: isPretty)
        }
        if options.contains(.status) {
            var status = "n/a"
            if let httpStatus = httpStatus {
                status = "\(httpStatus)"
            }
            result[TentaclesLog.NetworkResponseLogOption.status.description] = status
        }
        if options.contains(.headers) {
            var header = ""
            if let headers = (urlResponse as? HTTPURLResponse)?.allHeaderFields, headers.keys.count > 0 {
                for (key,value) in headers {
                    guard let keyString = key as? String else {continue}
                    let resultValue = redactions.contains(keyString) ? redactionSubstitute : value
                    header += (isPretty ? "--header " : "-H ") + "\'\(key): \(resultValue)\' \(newLine)"
                }
            }
            result[TentaclesLog.NetworkResponseLogOption.headers.description] = header
        }
        
        return result
    }
}

extension Result {
    func asLogDictionary(options: [TentaclesLog.NetworkResponseLogOption], redactions: [String], redactionSubstitute: String) -> [String: String] {
        switch self {
        case .success(let response):
            return response.asLogDictionary(options: options, redactions: redactions, redactionSubstitute: redactionSubstitute)
        case .failure(let response, let error):
            var result = response.asLogDictionary(options: options, redactions: redactions, redactionSubstitute: redactionSubstitute)
            if options.contains(.body) {
                var debugString = response.debugDescription
                if let error = error {
                    debugString.append("\nError:\n" + error.localizedDescription)
                }
                result[TentaclesLog.NetworkResponseLogOption.body.description] = debugString
            }
            return result
        }
    }
}
