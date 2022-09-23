//
//  Endpoint+Description.swift
//  Tentacles
//
//  Created by Mike Leavy on 1/15/21.
//  Copyright © 2021 Squid Store. All rights reserved.
//

import Foundation

extension Endpoint: CustomDebugStringConvertible {
    public var debugDescription: String {
        return requestDescription ?? "<no description>"
    }
    
    internal func appendToDescription(request: URLRequest, requestType: RequestType, parameterType: ParameterType, parameters: Any?) {
        appendToDescription(string: "Request:\n\(requestType.rawValue) \(request.debugDescription)\n")
        appendToDescription(string: "-parameter type: \(parameterType.description)\n")
        if let parameters = parameters, let json = parameters as? [String: Any] {
            appendToDescription(string: "-parameters:\n")
            appendToDescription(string: json.debugDescription)
            appendToDescription(string: "\n")
        }
        appendToDescription(string: "\n")
    }
    
    internal func appendToDescription(string: String) {
        if requestDescription == nil {
            requestDescription = String()
        }
        requestDescription?.append(string)
    }
}
