//
//  Reachability.swift
//  Tentacles
//
//  Created by Mike Leavy on 4/5/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import Foundation
import SystemConfiguration


open class Reachability {
    
    public static let reachabilityChanged = Notification.Name("reachabilityChanged")
    
    public enum ReachabilityError: Error, CustomStringConvertible {
        case callback
        case dispatchQueue
        
        public var description: String {
            switch self {
            case .callback:
                return "Unable to set callback (SCNetworkReachabilitySetCallback)"
            case .dispatchQueue:
                return "Unable to set dispatch queue (SCNetworkReachabilitySetDispatchQueue)"
            }
        }
    }
    
    public enum ConnectionType: CustomStringConvertible {
        case none, wifi, cellular
        public var description: String {
            switch self {
            case .cellular: return "Cellular"
            case .wifi: return "WiFi"
            case .none: return "No Connection"
            }
        }
    }
    
    public typealias ReachabilityChangedCallback = (ConnectionType) -> ()
    
    private let reachabilityRef: SCNetworkReachability
    private var notiifer: ReachabilityNotifier?
    
    
    required public init(reachabilityRef: SCNetworkReachability) {
        self.reachabilityRef = reachabilityRef
    }
    
    public convenience init?(hostname: String) {
        
        guard let ref = SCNetworkReachabilityCreateWithName(nil, hostname) else {return nil}
        
        self.init(reachabilityRef: ref)
    }
    
    public convenience init?() {
        
        var zeroAddress = sockaddr()
        zeroAddress.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zeroAddress.sa_family = sa_family_t(AF_INET)
        
        guard let ref = SCNetworkReachabilityCreateWithAddress(nil, &zeroAddress) else {return nil}
        
        self.init(reachabilityRef: ref)
    }
    
    @discardableResult
    public func startNotifier(reachabilityCallback: ReachabilityChangedCallback?) -> Error? {
        do {
            notiifer = try ReachabilityNotifier(reachabilityRef: reachabilityRef, reachabilityChangedCallback: reachabilityCallback)
            return nil
        }
        catch {
            return error
        }
    }
    
    public func stopNotifier() {
        notiifer = nil
    }

}


func callback(reachability:SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutableRawPointer?) {
    
    guard let info = info else {return}
    
    let reachability = Unmanaged<ReachabilityNotifier>.fromOpaque(info).takeUnretainedValue()
    reachability.reachabilityChanged()
}


internal class ReachabilityNotifier {
    
    private let reachabilityRef: SCNetworkReachability
    private var previousFlags: SCNetworkReachabilityFlags?
    private let queue = DispatchQueue(label: "com.squidstore.tentacles.reachability")
    
    var flags: SCNetworkReachabilityFlags {
        var flags = SCNetworkReachabilityFlags()
        if SCNetworkReachabilityGetFlags(reachabilityRef, &flags) {
            return flags
        }
        else {
            return SCNetworkReachabilityFlags()
        }
    }
    
    private var isSimulator: Bool = {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }()
    
    fileprivate var connection: Reachability.ConnectionType {
        
        guard flags.isReachable else {return .none}
        
        guard !isSimulator else {return .wifi}
        
        var connection: Reachability.ConnectionType = .none
        
        if !flags.isConnectionRequired {
            connection = .wifi
        }
        
        if flags.isConnectionOnTrafficOrDemand {
            if !flags.isInterventionRequired {
                connection = .wifi
            }
        }
        
        if flags.isWWANConnection {
            connection = .cellular
        }
        
        return connection
    }
    
    internal var reachabilityChangedCallback: Reachability.ReachabilityChangedCallback?
    
    init(reachabilityRef: SCNetworkReachability, reachabilityChangedCallback: Reachability.ReachabilityChangedCallback?) throws {
        self.reachabilityRef = reachabilityRef
        self.reachabilityChangedCallback = reachabilityChangedCallback
        var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        
        context.info = UnsafeMutableRawPointer(Unmanaged<ReachabilityNotifier>.passUnretained(self).toOpaque())
        
        if !SCNetworkReachabilitySetCallback(reachabilityRef, callback, &context) {
            stop()
            throw Reachability.ReachabilityError.callback
        }
        
        if !SCNetworkReachabilitySetDispatchQueue(reachabilityRef, queue) {
            stop()
            throw Reachability.ReachabilityError.dispatchQueue
        }
        
        queue.async {
            self.reachabilityChanged()
        }
    }
    
    deinit {
        stop()
    }
    
    private func stop() {
        SCNetworkReachabilitySetCallback(reachabilityRef, nil, nil)
        SCNetworkReachabilitySetDispatchQueue(reachabilityRef, nil)
    }
    
    internal func reachabilityChanged() {
        guard previousFlags != flags else {return}
        
        DispatchQueue.main.async {
            self.reachabilityChangedCallback?(self.connection)
            NotificationCenter.default.post(name: Reachability.reachabilityChanged, object:self.connection)
        }
        
        previousFlags = flags
    }
}

extension SCNetworkReachabilityFlags {
    var isReachable: Bool {
        return self.contains(.reachable)
    }
    
    var isConnectionRequired: Bool {
        return self.contains(.connectionRequired)
    }
    
    var isConnectionOnTraffic: Bool {
        return self.contains(.connectionOnTraffic)
    }
    
    var isInterventionRequired: Bool {
        return self.contains(.interventionRequired)
    }
    
    var isConnectionOnTrafficOrDemand: Bool {
        return !self.intersection([.connectionOnTraffic, .connectionOnDemand]).isEmpty
    }
    
    var isWWANConnection: Bool {
        #if os(iOS)
        return self.contains(.isWWAN)
        #else
        return false
        #endif
    }
}



