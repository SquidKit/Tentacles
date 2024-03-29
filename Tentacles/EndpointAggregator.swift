//
//  EndpointAggregator.swift
//  Tentacles
//
//  Created by Mike Leavy on 6/19/20.
//  Copyright © 2020 Squid Store. All rights reserved.
//

import Foundation

public typealias EndpointAggregatorFactory = () -> Endpoint

public struct AggregateItem {
    public let path: String
    public let requestType: Endpoint.RequestType
    public let parameterType: Endpoint.ParameterType?
    public let responseType: Endpoint.ResponseType?
    public let parameters: Any?
    
    public init(path: String, requestType: Endpoint.RequestType, parameterType: Endpoint.ParameterType?, responseType: Endpoint.ResponseType?, parameters: Any?) {
        self.path = path
        self.requestType = requestType
        self.parameterType = parameterType
        self.responseType = responseType
        self.parameters = parameters
    }
}

public struct AggregateResponseItem {
    public let object: Decodable?
    public let response: Response
    public let error: Error?
}

public typealias EndpointAggregateCompletion = ([AggregateResponseItem]) -> Void
public typealias EndpointAggregateDecoder = (Int, Response) -> (Decodable?, Error?)?

open class EndpointAggregator {
    
    private typealias InternalResponseItem = (Int, AggregateResponseItem)
    private var endpoints = [Endpoint]()
    private var session: Session?
    private var results = [InternalResponseItem]()
    
    private var endpointFactory: EndpointAggregatorFactory?
    
    
    public init(session: Session) {
        self.session = session
    }
    
    public init(factory: @escaping EndpointAggregatorFactory) {
        self.endpointFactory = factory
    }
    
    public init() {
    }
    
    open func request(_ items: [AggregateItem], decoder: @escaping EndpointAggregateDecoder, completion: @escaping EndpointAggregateCompletion) {
        
        endpoints.removeAll()
        results.removeAll()
        
        for _ in 0..<items.count {
            let endpoint: Endpoint!
            if let factory = endpointFactory {
                endpoint = factory()
            }
            else if let s = session {
                endpoint = Endpoint(session: s)
            }
            else {
                endpoint = Endpoint()
            }
            
            endpoints.append(endpoint)
        }
        
        for i in 0..<items.count {
            let item = items[i]
            let endpoint = endpoints[i]
            
            let _ = endpoint.dataRequest(item.path, requestType: item.requestType, responseType: item.responseType ?? .json, parameterType: item.parameterType ?? .none, parameters: item.parameters) { [weak self]
                result in
                switch result {
                case .success(let response):
                    let object = decoder(i, response)
                    let successItem = InternalResponseItem(i, AggregateResponseItem(object: object?.0, response: response, error: object == nil ? nil : object?.1))
                    self?.results.append(successItem)
                case .failure(let response, let error):
                    let failurItem = InternalResponseItem(i, AggregateResponseItem(object: nil, response: response, error: error))
                    self?.results.append(failurItem)
                }
                
                self?.checkCompletion(endpoint: endpoint, completion: completion)
            }
        }
    }
    
    internal func checkCompletion(endpoint: Endpoint, completion: @escaping EndpointAggregateCompletion) {
        if let foundIndex = endpoints.firstIndex(of: endpoint) {
            endpoints.remove(at: foundIndex)
        }

        if endpoints.isEmpty {
            let sortedResults = results.sorted { (first, second) -> Bool in
                return first.0 < second.0
            }.map { (result) -> AggregateResponseItem in
                return result.1
            }
            completion(sortedResults)
        }
    }
}
