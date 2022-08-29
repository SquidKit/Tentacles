//
//  Tentacles.swift
//  Tentacles
//
//  Created by Mike Leavy on 3/28/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import Foundation


public enum TentaclesLogLevel: Equatable {
    public static func == (lhs: TentaclesLogLevel, rhs: TentaclesLogLevel) -> Bool {
        return lhs.identifier == rhs.identifier
    }
    
    case request([TentaclesLog.NetworkRequestLogOption], TentaclesLog.Redaction)
    case response([TentaclesLog.NetworkResponseLogOption], TentaclesLog.Redaction)
    case warning
    case error
    case info
    case throttle
    
    
    public static let all: [TentaclesLogLevel] = [.request(TentaclesLog.NetworkRequestLogOption.default, .requestDefault),
                                            .response(TentaclesLog.NetworkResponseLogOption.default, .responseDefault),
                                            .warning,
                                            .error,
                                            .info,
                                            .throttle]
    
    public static let none: [TentaclesLogLevel] = []
    
    public var description: String {
        switch self {
        case .request(let options, let redaction):
            return "\(identifier) - \(options), \(redaction)"
        case .response(let options, let redaction):
            return "\(identifier) - \(options), \(redaction)"
        default:
            return identifier
        }
    }
    
    public var identifier: String {
        switch self {
        case .request(_, _):
            return "request"
        case .response(_, _):
            return "response"
        case .warning:
            return "warning"
        case .error:
            return "error"
        case .info:
            return "info"
        case .throttle:
            return "throttle"
        }
    }
}

public protocol Logable {
    func log(_ message: String, level: TentaclesLogLevel)
    func log(_ dictionary: [String: String], level: TentaclesLogLevel)
}

public extension Logable {
    func log(_ message: String, level: TentaclesLogLevel) {
        print("🦑 " + level.identifier + ": " + message)
    }
    
    func log(_ dictionary: [String: String], level: TentaclesLogLevel) {
        log("\(dictionary)", level: level)
    }
}

class TentaclesLogger: Logable {
}


open class Tentacles {
    public static let networkingModeChanged = Notification.Name("com.squidstore.tentacles.networkingModeChanged")
    public enum NetworkingMode {
        case `default`
        case simulatedOffline
    }
    public static var domain: String = "com.squidstore.tentacles"
    public static var errorDomain: String = "com.squidstore.tentacles.error"
    
    
    public var logLevel: [TentaclesLogLevel] = TentaclesLogLevel.none
    public var logger: Logable?
    internal let internalLogger: TentaclesLog!
    
    public var networkingMode: NetworkingMode = .default {
        didSet {
            NotificationCenter.default.post(name: Tentacles.networkingModeChanged, object: networkingMode)
        }
    }
    
    public static let shared = Tentacles()
    private init() {
        self.logger = TentaclesLogger()
        self.internalLogger = TentaclesLog()
    }
    
    public func log(_ message: String, level: TentaclesLogLevel) {
        if logLevel.contains(level) {
            logger?.log(message, level: level)
        }
    }
}






