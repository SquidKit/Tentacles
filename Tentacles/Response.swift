//
//  Response.swift
//  Tentacles
//
//  Created by Mike Leavy on 3/29/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import UIKit

/**
 The result types for an object conforming to the ResponseMaking protocol.
 
 - success: The request was successful
 - failure:  The request failed
 */
public enum ResponseMakingResult {
    case success
    case failure
}

/// Protocol that clients use to handle their own `Response` types
public protocol ResponseMaking {
    func make(data: Data?, urlResponse: URLResponse, error: Error?, responseType: Endpoint.ResponseType) -> Response
    var result: ResponseMakingResult {get}
    var error: Error? {get}
}

/// The `Response` class encapsulates the data representations of an `Endpoint` request (HTTP request) operation.
open class Response: CustomStringConvertible, CustomDebugStringConvertible {
    /// The `Foundation` URLResponse for the request
    public let urlResponse: URLResponse
    
    private let responseJSON: JSON?
    private let responseImage: UIImage?
    private let responseData: Data?
    
    init(json: JSON, data: Data, urlResponse: URLResponse) {
        self.responseJSON = json
        self.responseImage = nil
        self.responseData = data
        self.urlResponse = urlResponse
    }
    
    init(image: UIImage, data: Data, urlResponse: URLResponse) {
        self.responseJSON = nil
        self.responseImage = image
        self.responseData = data
        self.urlResponse = urlResponse
    }
    
    public init(data: Data?, urlResponse: URLResponse) {
        self.responseImage = nil
        self.responseJSON = nil
        self.responseData = data
        self.urlResponse = urlResponse
    }
    
    /// The response data in JSON dictionary format. An empty dictionary may be returned
    /// if there is no data, or if the response format is not representable as a JSON dictionary.
    open var jsonDictionary: [String: Any] {
        if let json = responseJSON {
            return json.dictionary
        }
        return [String: Any]()
    }
    
    /// The response data in JSON array format. An empty arry may be returned
    /// if there is no data, or if the response format is not representable as a JSON array.
    open var jsonArray: [[String: Any]] {
        if let json = responseJSON {
            return json.array
        }
        return [[String: Any]]()
    }
    
    /// The response data as a `UIImage`. `nil` may be returned
    /// if there is no data, or if the response format is not representable as a `UIImage`.
    open var image: UIImage? {
        if let data = responseData, data.count > 0 {
            let image = UIImage(data: data)
            return image
        }
        return nil
    }
    
    /// The response's raw data. `nil` may be returned
    /// if there is no data.
    open var data: Data? {
        return responseData
    }
    
    /// The response's HTTP status code, or `nil`
    public var httpStatus: Int? {
        return (urlResponse as? HTTPURLResponse)?.statusCode
    }
    
    public var headers: [AnyHashable: Any]? {
        return (urlResponse as? HTTPURLResponse)?.allHeaderFields
        
    }
    
    open var description: String {
        if !jsonDictionary.isEmpty {
            return String(jsonObject: jsonDictionary, pretty: true) ?? ""
        }
        else if !jsonArray.isEmpty {
            return String(jsonObject: jsonArray, pretty: true) ?? ""
        }
        else if let image = image {
            return image.description
        }
        else if let data = data {
            return data.description
        }
        return ""
    }
    
    /// The debug description of the response data
    open var debugDescription: String {
        var debugString = urlResponse.debugDescription
        if !jsonDictionary.isEmpty {
            debugString.append("\nJSON Dictionary:\n" + jsonDictionary.debugDescription)
        }
        if !jsonArray.isEmpty {
            debugString.append("\nJSON Array:\n" + jsonArray.debugDescription)
        }
        if let image = image {
            debugString.append("\nImage:\n" + image.debugDescription)
        }
        if let data = data {
            debugString.append("\nData:\n" + data.debugDescription)
        }
        return debugString
    }
    
    /**
     `decoded` will attempt to decode the response `data` into the given type (which must conform to the
     `Decodable` protocol).
     
     - Throws: If the data is not valid JSON, this method throws the dataCorrupted error. If a value within the JSON fails to decode, this method throws the corresponding error. If `dateFormatters` are given, this will throw a dataCorrupted error if a date string in the response cannot be decoded into a corresponding `Date` object in the given `Decodable` type. Throws a `tentaclesError` if the data to be decoded is nil.
     
     - Parameter type:   The type of the object conforming to `Decodable`.
     - Parameter dateFormatters:   An array of `DateFormatter` objects that will be used to transform date strings into
     valid `Date` objects. Specify nil if no date decoding is required.
     */
    public func decoded<T:Decodable>(_ type: T.Type, dateFormatters: [DateFormatter]? = nil) throws -> T {
        return try decoded(type, dateFormatters: dateFormatters, keyDecodingStrategy: .useDefaultKeys)
    }
    
    /**
     `decoded` will attempt to decode the response `data` into the given type (which must conform to the
     `Decodable` protocol).
     
     - Throws: If the data is not valid JSON, this method throws the dataCorrupted error. If a value within the JSON fails to decode, this method throws the corresponding error. Throws a `tentaclesError` if the data to be decoded is nil.
     
     - Parameter type:   The type of the object conforming to `Decodable`.
     - Parameter keyDecodingStrategy:   The key decoding strategy to use when decoding the JSON data.
     */
    public func decoded<T:Decodable>(_ type: T.Type, keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy) throws -> T {
        return try decoded(type, dateFormatters: nil, keyDecodingStrategy: .useDefaultKeys)
    }
    
    /**
     `decoded` will attempt to decode the response `data` into the given type (which must conform to the
     `Decodable` protocol).
     
     - Throws: If the data is not valid JSON, this method throws the dataCorrupted error. If a value within the JSON fails to decode, this method throws the corresponding error. If `dateFormatters` are given, this will throw a dataCorrupted error if a date string in the response cannot be decoded into a corresponding `Date` object in the given `Decodable` type. Throws a `tentaclesError` if the data to be decoded is nil.
     
     - Parameter type:   The type of the object conforming to `Decodable`.
     - Parameter dateFormatters:   An array of `DateFormatter` objects that will be used to transform date strings into
     valid `Date` objects. Specify nil if no date decoding is required.
     - Parameter keyDecodingStrategy:   The key decoding strategy to use when decoding the JSON data.
     */
    public func decoded<T:Decodable>(_ type: T.Type, dateFormatters: [DateFormatter]?, keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy) throws -> T {
        if let data = responseData {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = keyDecodingStrategy
            if let formatters = dateFormatters {
                decoder.dateDecodingStrategy = .custom({ (decoder) -> Date in
                    guard let container = try? decoder.singleValueContainer(),
                        let text = try? container.decode(String.self) else {
                            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Could not decode date text"))
                    }
                    var decodedDate: Date?
                    for formatter in formatters {
                        if let date = formatter.date(from: text) {
                            decodedDate = date
                            break
                        }
                    }
                    guard let date = decodedDate else {
                        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(text)")
                    }
                    return date
                })
            }
            do {
                let result = try decoder.decode(type, from: data)
                return result
            }
            catch {
                Tentacles.shared.log(error.localizedDescription, level: .error)
                throw error
            }
        }
        throw NSError.tentaclesError(code: TentaclesErrorCode.invalidData.rawValue, localizedDescription: "Data to decode is nil")
    }
    
}

/**
 The result of a network `Endpoint` operation.
 
 - success: The operation completed successfully.
 - failure: The operation failed
 */
public enum Result: CustomDebugStringConvertible {
    case success(Response)
    case failure(Response, Error?)
    
    public init(data: Data?, urlResponse: URLResponse, error: Error?, responseType: Endpoint.ResponseType) {
        switch responseType {
        case .none:
            self.init(data: data, urlResponse: urlResponse, error: error)
        case .json:
            self.init(jsonData: data, urlResponse: urlResponse, error: error)
        case .image:
            self.init(imageData: data, urlResponse: urlResponse, error: error)
        case .data:
            self.init(data: data, urlResponse: urlResponse, error: error)
        case .custom(_, let maker):
            let response = maker.make(data: data, urlResponse: urlResponse, error: error, responseType: responseType)
            switch maker.result {
            case .success:
                self = .success(response)
            case .failure:
                self = .failure(response, maker.error)
            }
        }
        
        Tentacles.shared.log(self.debugDescription, level: .response)
    }
    
    private init(jsonData: Data?, urlResponse: URLResponse, error: Error?) {
        guard let data = jsonData, data.count > 0 else {
            self = .failure(Response(data: jsonData, urlResponse: urlResponse), error)
            Tentacles.shared.log("Result: Invalid JSON response", level: .response)
            return
        }
        
        let json = JSON(data)
        switch json {
        case .error(let jsonError):
            self = .failure(Response(json: json, data: data, urlResponse: urlResponse), error ?? jsonError)
        default:
            if let error = error {
                self = .failure(Response(json: json, data: data, urlResponse: urlResponse), error)
            }
            else {
                self = .success(Response(json: json, data: data, urlResponse: urlResponse))
            }
        }
    }
    
    private init(imageData: Data?, urlResponse: URLResponse, error: Error?) {
        guard let data = imageData, data.count > 0 else {
            self = .failure(Response(data: imageData, urlResponse: urlResponse), error)
            return
        }
        
        guard let image = UIImage(data: data) else {
            self = .failure(Response(data: imageData, urlResponse: urlResponse), error)
            return
        }
        
        if let error = error {
            self = .failure(Response(image: image, data: data, urlResponse: urlResponse), error)
        }
        else {
            self = .success(Response(image: image, data: data, urlResponse: urlResponse))
        }
    }
    
    private init(data: Data?, urlResponse: URLResponse, error: Error?) {
        if let error = error {
            self = .failure(Response(data: data, urlResponse: urlResponse), error)
        }
        else {
            self = .success(Response(data: data, urlResponse: urlResponse))
        }
    }
    
    public var debugDescription: String {
        switch self {
        case .success(let response):
            return response.debugDescription
        case .failure(let response, let error):
            var debugString = response.debugDescription
            if let error = error {
                debugString.append("\nError:\n" + error.localizedDescription)
            }
            return debugString
        }
    }
}








