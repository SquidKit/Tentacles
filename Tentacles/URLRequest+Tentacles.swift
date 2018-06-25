//
//  URLRequest+Tentacles.swift
//  Tentacles
//
//  Created by Mike Leavy on 3/31/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import Foundation

extension URLRequest {
    init(url: URL, cachePolicy: URLRequest.CachePolicy, timeoutInterval: TimeInterval, requestType: Endpoint.RequestType, parameterType: Endpoint.ParameterType, responseType: Endpoint.ResponseType, parameters: Any?, session: Session) throws {
        
        self = URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy, timeoutInterval: session.timeout)
        
        self.httpMethod = requestType.rawValue
        
        if let contentType = parameterType.contentType {
            self.addValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        
        if let accept = responseType.accept {
            self.addValue(accept, forHTTPHeaderField: "Accept")
        }
                
        if let authValue = session.authorizationHeaderValue {
            self.setValue(authValue, forHTTPHeaderField: session.authorizationHeaderKey)
        }
        else if let bearer = session.authorizationBearerToken {
            self.setValue("Bearer \(bearer)", forHTTPHeaderField: session.authorizationHeaderKey)
        }
        
        if let headerFields = session.headers {
            for (key, value) in headerFields {
                self.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        var serializingError: NSError?
        switch parameterType {
        case .none:
            break
        case .json:
            if let parameters = parameters {
                do {
                    self.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
                }
                catch {
                    serializingError = error as NSError
                }
            }
        case .formURLEncoded:
            guard let parametersDictionary = parameters as? [String: Any] else { fatalError("Couldn't convert parameters to a dictionary: \(String(describing: parameters))") }
            do {
                let formattedParameters = try parametersDictionary.urlEncodedString()
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
        case .custom(_):
            self.httpBody = parameters as? Data
            
        }
        
        guard serializingError == nil else {
            throw serializingError!
        }
        
        if let store = session.cachingStore {
            switch store {
            case .system(let config):
                self.cachePolicy = config.requestCachePolicy
            default:
                self.cachePolicy = .reloadIgnoringLocalCacheData
            }
        }
        
    }
}
