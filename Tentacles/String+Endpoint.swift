//
//  String+Endpoint.swift
//  Tentacles
//
//  Created by Mike Leavy on 3/30/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import Foundation

public extension String {
    @discardableResult
    func get(session: Session, completion: @escaping EndpointCompletion) -> Endpoint {
        return Endpoint(session: session).get(self, completion: completion)
    }
    
    @discardableResult
    func get(completion: @escaping EndpointCompletion) -> Endpoint {
        return Endpoint().get(self, completion: completion)
    }
}
