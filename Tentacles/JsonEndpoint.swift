//
//  JsonEndpoint.swift
//  Tentacles
//
//  Created by Mike Leavy on 6/19/20.
//  Copyright © 2020 Squid Store. All rights reserved.
//

import Foundation

public typealias JsonEndpointCompletion = (Decodable?, Response?, Error?) -> Void
open class JsonEndpoint: Hashable {
    
    public let endpoint: Endpoint!
        
    public init(session: Session) {
        endpoint = Endpoint(session: session)
    }
    
    public init(endpoint: Endpoint) {
        self.endpoint = endpoint
    }
    
    public init() {
        endpoint = Endpoint()
    }
    
    public static func == (lhs: JsonEndpoint, rhs: JsonEndpoint) -> Bool {
        return lhs.endpoint == rhs.endpoint
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(endpoint.task?.identifier)
    }
    
    @discardableResult
    open func get<T: Decodable>(_ path: String, responseObjectType: T.Type, completion: @escaping JsonEndpointCompletion) -> JsonEndpoint {
        return get(path, parameters: nil, responseObjectType: responseObjectType, dateFormatters: nil, keyDecodingStrategy: .useDefaultKeys, completion: completion)
    }
    
    @discardableResult
    open func get<T: Decodable>(_ path: String, responseObjectType: T.Type, dateFormatters: [DateFormatter], completion: @escaping JsonEndpointCompletion) -> JsonEndpoint {
        return get(path, parameters: nil, responseObjectType: responseObjectType, dateFormatters: dateFormatters, keyDecodingStrategy: .useDefaultKeys, completion: completion)
    }
    
    @discardableResult
    open func get<T: Decodable>(_ path: String, responseObjectType: T.Type, dateFormatters: [DateFormatter], keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy, completion: @escaping JsonEndpointCompletion) -> JsonEndpoint {
        return get(path, parameters: nil, responseObjectType: responseObjectType, dateFormatters: dateFormatters, keyDecodingStrategy: keyDecodingStrategy, completion: completion)
    }
    
    @discardableResult
    open func get<T: Decodable>(_ path: String, parameters: Any?, responseObjectType: T.Type, dateFormatters: [DateFormatter]?, keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy, completion: @escaping JsonEndpointCompletion) -> JsonEndpoint {
        endpoint.get(path, parameters: parameters) {
            result in
            switch result {
            case .success(let response):
                do {
                    let json = try response.decoded(responseObjectType)
                    completion(json, response, nil)
                }
                catch(let error) {
                    completion(nil, response, error)
                }
            case .failure(let response, let error):
                completion(nil, response, error)
            }
        }
        return self
    }
}



