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
    public func get(completion: @escaping EndpointCompletion) -> Endpoint.Task {
        return Endpoint().get(self, completion: completion)
    }
}
