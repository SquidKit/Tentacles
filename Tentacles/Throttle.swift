//
//  Throttle.swift
//  Tentacles
//
//  Created by Michael Leavy on 7/10/22.
//  Copyright © 2022 Squid Store. All rights reserved.
//

import Foundation

public struct Throttle: CustomDebugStringConvertible {
    public var debugDescription: String {
        "Throttle > count: \(count) interval: \(interval) initial time: \(initialRequestTime) window count: \(throttleWindowCount)"
    }
    
    public let count: Int
    public let interval: TimeInterval
    fileprivate var initialRequestTime = Date.distantPast
    fileprivate var throttleWindowCount = 0
    
    public init(count: Int, interval: TimeInterval) {
        self.count = count
        self.interval = interval
    }
    
    mutating fileprivate func update() {
        initialRequestTime = Date()
        throttleWindowCount += 1
    }
    
    mutating fileprivate func updateCount() {
        throttleWindowCount += 1
    }
}

internal class Throttler {
    
    internal static let shared = Throttler()
    
    var throttles: [String: Throttle] = [String: Throttle]()
    
    internal func throttled(url: URL, throttle: Throttle) -> Bool {
        let name = url.throttledName
        guard var rule = throttles[name] else {
            var updated = throttle
            updated.update()
            throttles[name] = updated
            print("throttle added")
            return false
        }
        
        guard rule.count == throttle.count, rule.interval == throttle.interval else {
            var updated = throttle
            updated.update()
            throttles[name] = updated
            print("throttle updated")
            return false
        }
        
        guard Date().timeIntervalSince(rule.initialRequestTime) >= rule.interval else {
            rule.updateCount()
            throttles[name] = rule
            if rule.throttleWindowCount > rule.count {
                return true
            }
            else {
                return false
            }
        }
        
        rule.updateCount()
        throttles[name] = rule
        cleanup()
        return false
    }
    
    func cleanup() {
        let now = Date()
        var removableKeys = [String]()
        throttles.forEach { key, value in
            if now.timeIntervalSince(value.initialRequestTime) > value.interval {
                removableKeys.append(key)
            }
        }
        
        removableKeys.forEach { key in
            throttles.removeValue(forKey: key)
        }
    }
}
