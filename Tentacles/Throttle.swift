//
//  Throttle.swift
//  Tentacles
//
//  Created by Michael Leavy on 7/10/22.
//  Copyright © 2022 Squid Store. All rights reserved.
//

import Foundation

/**
Throttle provides a mechanism for throttling API requests on a URL-by-URL basis. You can attach a Throttle
 object to an Endpoint, and all requests using that same endpoint URL will be throttled according to the parameters
 set here. Throttle uses the URL path and query parameters (which are sorted internally) as the key name for determining if one request
 matches another.
 
 You can omit query key names by passing them in the `ignoredQueryKeys` array.
 You can omit all query keys by passing a value of '*' in the`ignoredQueryKeys` array.

- Parameter paginationHeaderKeys:    The header keys that should be auto-incremented by subsequent mock requests.
*/

public struct Throttle: CustomDebugStringConvertible {
    public var debugDescription: String {
        "Throttle > count: \(count) interval: \(interval) initial time: \(initialRequestTime) window count: \(throttleWindowCount)"
    }
    
    public let count: Int
    public let interval: TimeInterval
    public let ignoredQueryKeys: [String]?
    fileprivate var initialRequestTime = Date.distantPast
    fileprivate var throttleWindowCount = 0
    
    public init(count: Int, interval: TimeInterval, ignoredQueryKeys: [String]?) {
        self.count = count
        self.interval = interval
        self.ignoredQueryKeys = ignoredQueryKeys
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
        let name = url.throttledName(ignoredQueryKeys: throttle.ignoredQueryKeys)
        guard var rule = throttles[name] else {
            var updated = throttle
            updated.update()
            throttles[name] = updated
            display("new:")
            return false
        }
        
        guard rule.count == throttle.count, rule.interval == throttle.interval else {
            var updated = throttle
            updated.update()
            throttles[name] = updated
            display("updated:")
            return false
        }
        
        guard Date().timeIntervalSince(rule.initialRequestTime) >= rule.interval else {
            if rule.throttleWindowCount >= rule.count {
                display("rate limited:")
                return true
            }
            else {
                rule.updateCount()
                throttles[name] = rule
                display("within window:")
                return false
            }
        }
        
        rule.update()
        throttles[name] = rule
        cleanup()
        display("exceeded interval:")
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
    
    func display(_ prefix: String) {
        throttles.forEach { key, value in
            let message = "\(prefix) Throttled:\n\t\(key)\n\t\(value.debugDescription)"
            Tentacles.shared.log(message, level: .throttle)
        }
    }
}
