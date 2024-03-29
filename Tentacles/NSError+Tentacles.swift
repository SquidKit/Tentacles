//
//  NSError+Tentacles.swift
//  Tentacles
//
//  Created by Mike Leavy on 3/30/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import Foundation

public enum TentaclesErrorCode: Int {
    case invalidData
    case serializationError
    case decodingError
    case logicError
    case unimplemented
    case fileNotFoundError
    case cachedNotFoundError
    case requestTypeDisabledError
    case requestTimedOutError = -1001
    case requestExceedsThrottleLimitError = -1008
    case simulatedOfflineError = -1009
}

extension NSError {
    static func tentaclesError(code: Int, localizedDescription: String) -> Error {
        let error = NSError(domain: Tentacles.errorDomain, code: code, userInfo: [NSLocalizedDescriptionKey: localizedDescription])
        return error
    }
    
    static func tentaclesError(code: TentaclesErrorCode, localizedDescription: String) -> Error {
        let error = NSError(domain: Tentacles.errorDomain, code: code.rawValue, userInfo: [NSLocalizedDescriptionKey: localizedDescription])
        return error
    }
}

extension Error? {
    public var isCancelled: Bool {
        return (self as NSError?)?.code == NSURLErrorCancelled
    }
}
