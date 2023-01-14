//
//  URLRequest+Tentacles.swift
//  Tentacles
//
//  Created by Mike Leavy on 3/31/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import Foundation

extension URLRequest {
  
    init(
        url: URL,
        cachePolicy: URLRequest.CachePolicy,
        timeoutInterval: TimeInterval,
        authorizationHeaderKey: String?,
        authorizationHeaderValue: String?,
        authorizationBearerToken: String?,
        headers:[String: String]?,
        requestType: Endpoint.RequestType,
        parameterType: Endpoint.ParameterType,
        parameterArrayBehaviors: Endpoint.ParameterArrayBehaviors,
        responseType: Endpoint.ResponseType,
        parameters: Any?,
        cachingStore: Session.CachingStore?) throws {
        
            self = URLRequest(
                url: url,
                cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy,
                timeoutInterval: timeoutInterval )
        
            self.httpMethod = requestType.rawValue
        
            if let contentType = parameterType.contentType {
                self.addValue(contentType, forHTTPHeaderField: "Content-Type")
            }
        
            if let accept = responseType.accept {
                self.addValue(accept, forHTTPHeaderField: "Accept")
            }
            
            if let authKey =  authorizationHeaderKey {
                if let authValue = authorizationHeaderValue {
                    self.setValue(authValue, forHTTPHeaderField: authKey)
                }
                else if let bearer = authorizationBearerToken {
                    self.setValue("Bearer \(bearer)", forHTTPHeaderField: authKey)
                }
            }
            
            if let headerFields = headers {
                for (key, value) in headerFields {
                    self.setValue(value, forHTTPHeaderField: key)
                }
            }
            
            var serializingError: NSError?
            
            func parameterEncoding(customKeys: [String]? = nil, encodingCallback: CustomParameterEncoder? = nil, arrayBehaviors: Endpoint.ParameterArrayBehaviors) {
                guard let parameters = parameters else {return}
                if let parametersDictionary = parameters as? [String: Any] {
                    if !parametersDictionary.isEmpty {
                        do {
                            let formattedParameters = try parametersDictionary.urlEncodedString(customKeys: customKeys, encodingCallback: encodingCallback, arrayBehaviors: arrayBehaviors)
                            switch requestType {
                            case .get, .delete:
                                let path = url.absoluteString
                                let urlEncodedPath: String
                                if path.contains("?") {
                                    if let lastCharacter = path.last, lastCharacter == "?" {
                                        urlEncodedPath = path + formattedParameters
                                    } else {
                                        urlEncodedPath = path + "&" + formattedParameters
                                    }
                                }
                                else {
                                    urlEncodedPath = path + "?" + formattedParameters
                                }
                                if let urlWithQuery = URL(string: urlEncodedPath) {
                                    self.url = urlWithQuery
                                }
                                
                            case .post, .put, .patch:
                                self.httpBody = formattedParameters.data(using: .utf8)
                            }
                        }
                        catch let error as NSError {
                            serializingError = error
                        }
                    }
                }
                else if let array = parameters as? [String] {
                    if !array.isEmpty {
                        let formattedParameters = array.urlEncodedString()
                        let path = url.absoluteString
                        let urlEncodedPath: String
                        if path.contains("?") {
                            if let lastCharacter = path.last, lastCharacter == "?" {
                                urlEncodedPath = path + formattedParameters
                            } else {
                                urlEncodedPath = path + "&" + formattedParameters
                            }
                        }
                        else {
                            urlEncodedPath = path + "?" + formattedParameters
                        }
                        if let urlWithQuery = URL(string: urlEncodedPath) {
                            self.url = urlWithQuery
                        }
                    }
                }
                else {
                    do {
                        self.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
                    }
                    catch let error as NSError {
                        serializingError = error
                    }
                }
            }
            
            switch parameterType {
            case .none:
                break
            case .json:
                if let parameters = parameters {
                    switch requestType {
                    case .get, .delete:
                        parameterEncoding(arrayBehaviors: parameterArrayBehaviors)
                    case .patch, .put, .post:
                        do {
                            self.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
                        }
                        catch {
                            serializingError = error as NSError
                        }
                    }
                }
            case .formURLEncoded:
                parameterEncoding(arrayBehaviors: parameterArrayBehaviors)
            case .custom(_):
                self.httpBody = parameters as? Data
            case .customKeys(_, let keys, let encodingCallback):
                parameterEncoding(customKeys: keys, encodingCallback: encodingCallback, arrayBehaviors: parameterArrayBehaviors)
                
            }
            
            guard serializingError == nil else {
                throw serializingError!
            }
            
            if let store = cachingStore {
                switch store {
                case .system(let config):
                    self.cachePolicy = config.requestCachePolicy
                default:
                    self.cachePolicy = .reloadIgnoringLocalCacheData
                }
            }
            
        }
}
