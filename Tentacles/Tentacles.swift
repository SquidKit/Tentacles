//
//  Tentacles.swift
//  Tentacles
//
//  Created by Mike Leavy on 3/28/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import Foundation


public struct LogLevel: OptionSet, CustomStringConvertible {
    public let rawValue: Int
    
    public static let request = LogLevel(rawValue: 1)
    public static let response = LogLevel(rawValue: 2)
    public static let warning = LogLevel(rawValue: 4)
    public static let error = LogLevel(rawValue: 8)
    public static let info = LogLevel(rawValue: 16)
    public static let all: LogLevel = [.request, .response, .warning, .error, .info]
    public static let none: LogLevel = []
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public var description: String {
        switch rawValue {
        case LogLevel.request.rawValue:
            return "request"
        case LogLevel.response.rawValue:
            return "response"
        case LogLevel.warning.rawValue:
            return "warning"
        case LogLevel.error.rawValue:
            return "error"
        case LogLevel.info.rawValue:
            return "info"
        default:
            return "unknown"
        }
    }
}

public protocol Logable {
    func log(_ message: String, level: LogLevel)
}

class TentaclesLogger: Logable {
    func log(_ message: String, level: LogLevel) {
        print("🦑 " + level.description + ": " + message)
    }
}


open class Tentacles {
    public static let networkingModeChanged = Notification.Name("com.squidstore.tentacles.networkingModeChanged")
    public enum NetworkingMode {
        case `default`
        case simulatedOffline
    }
    public static var domain: String = "com.squidstore.tentacles"
    public static var errorDomain: String = "com.squidstore.tentacles.error"
    
    
    public var logLevel: LogLevel = []
    public var logger: Logable?
    public var networkingMode: NetworkingMode = .default {
        didSet {
            NotificationCenter.default.post(name: Tentacles.networkingModeChanged, object: networkingMode)
        }
    }
    
    public static let shared = Tentacles()
    private init() {
        self.logger = TentaclesLogger()
    }
    
    public func log(_ message: String, level: LogLevel) {
        if logLevel.contains(level) {
            logger?.log(message, level: level)
        }
    }
}






