//
//  TentaclesTests.swift
//  TentaclesTests
//
//  Created by Mike Leavy on 3/28/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import XCTest
@testable import Tentacles



typealias LoggerCallback = (_ message: String, _ foundLevel: Bool) -> Void
typealias LoggerMessageCallback = (_ message: String, _ level: TentaclesLogLevel) -> Void

class Logger: Logable {
    var callback: LoggerCallback?
    var messageCallback: LoggerMessageCallback?
    
    func log(_ message: String, level: TentaclesLogLevel) {
        callback?(message, expectedLogLevel.contains(level))
        messageCallback?(message, level)
        print("\n===========\n\n🦑🧪 \(message)\n\n===========\n")
    }
            
    var expectedLogLevel: [TentaclesLogLevel] = []
}

class TentaclesTests: XCTestCase {
    
    static var timeout: TimeInterval = 10
    var textExpectation: XCTestExpectation?
    var logger: Logger?
    
    class func printError(_ error: Error?) {
        print(error?.localizedDescription ?? "no error description")
    }
    
    class func printString(_ string: String?) {
        print(string ?? "nil string")
    }
    
    override func setUp() {
        super.setUp()
        Session.shared.host = "httpbin.org"
        logger = Logger()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func expect() {
        textExpectation = XCTestExpectation(description: "")
    }
    
    func wait() {
        if let expectation = textExpectation {
            wait(for: [expectation], timeout: TentaclesTests.timeout)
        }
    }
    
    func fullfill() {
        textExpectation?.fulfill()
    }
    
    func testLoggingInvalid() {
        
        logger?.expectedLogLevel = TentaclesLogLevel.none
        logger?.callback = { (message, found) in
            XCTAssertFalse(found, "expected found log level to be false (logger is expecting none, but Tentacles is expecting all")
        }
        
        Tentacles.shared.logger = logger
        Tentacles.shared.logLevel = TentaclesLogLevel.all
        
        expect()
        
        Endpoint().get("get") { [weak self] (result) in
            switch result {
            case .success(_):
                break
            case .failure(_, _):
                XCTFail()
            }
            self?.fullfill()
        }
        
        wait()
    }
    
    func testLoggingValid() {
        
        logger?.expectedLogLevel = [TentaclesLogLevel.request(TentaclesLog.NetworkRequestLogOption.default, TentaclesLog.Redaction.requestDefault)]
        logger?.callback = { (message, found) in
            XCTAssertTrue(found, "expected found log level to be true")
        }
        
        Tentacles.shared.logger = logger
        Tentacles.shared.logLevel = logger?.expectedLogLevel ?? []
        
        expect()
        
        Endpoint().get("get") { [weak self] (result) in
            switch result {
            case .success(_):
                break
            case .failure(_, _):
                XCTFail()
            }
            self?.fullfill()
        }
        
        wait()
    }
    
    func testLogRedactionDefaultValid() {
        logger?.expectedLogLevel = [TentaclesLogLevel.request(TentaclesLog.NetworkRequestLogOption.default, TentaclesLog.Redaction.requestDefault)]
        logger?.messageCallback = { (message, level) in
            switch level {
            case .request(_, _):
                guard message.contains(TentaclesLog.Redaction.requestDefault.substitute) else {
                    XCTFail()
                    return
                }
            case .response(_, _):
                guard message.contains("should be redacted") else {
                    XCTFail()
                    return
                }
                
            default:
                break
            }
        }
        
        Tentacles.shared.logger = logger
        Tentacles.shared.logLevel = logger?.expectedLogLevel ?? []
        Tentacles.shared.logLevel = [
            .request(TentaclesLog.NetworkRequestLogOption.default, .requestDefault),
            .response(TentaclesLog.NetworkResponseLogOption.default, .responseDefault)
        ]
        
        expect()
        
        let params = ["password": "should be redacted", "not_password": "should not be redacted"]
        
        Endpoint().get("get", parameters: params) { [weak self] (result) in
            switch result {
            case .success(_):
                break
            case .failure(_, _):
                XCTFail()
            }
            self?.fullfill()
        }
        
        wait()
    }
    
    func testLogRedactionResponseValid() {
        logger?.expectedLogLevel = [TentaclesLogLevel.request(TentaclesLog.NetworkRequestLogOption.default, TentaclesLog.Redaction.requestDefault)]
        logger?.messageCallback = { (message, level) in
            switch level {
            case .request(_, _):
                guard message.contains(TentaclesLog.Redaction.requestDefault.substitute) else {
                    XCTFail()
                    return
                }
            case .response(_, _):
                guard message.contains("<redacted>") else {
                    XCTFail()
                    return
                }
                
            default:
                break
            }
        }
        
        Tentacles.shared.logger = logger
        Tentacles.shared.logLevel = logger?.expectedLogLevel ?? []
        Tentacles.shared.logLevel = [
            .request(TentaclesLog.NetworkRequestLogOption.default, .requestDefault),
            .response(TentaclesLog.NetworkResponseLogOption.default, TentaclesLog.Redaction(redactables: ["password"], substitute: TentaclesLog.Redaction.responseDefault.substitute))
        ]
        
        expect()
        
        let params = ["password": "should be redacted", "not_password": "should not be redacted"]
        
        Endpoint().get("get", parameters: params) { [weak self] (result) in
            switch result {
            case .success(_):
                break
            case .failure(_, _):
                XCTFail()
            }
            self?.fullfill()
        }
        
        wait()
    }
    
    func testLogCURL() {
        logger?.messageCallback = { (message, level) in
            switch level {
            case .request(_, _):
                guard message.contains(TentaclesLog.Redaction.requestDefault.substitute) else {
                    XCTFail()
                    return
                }
                
            default:
                break
            }
        }
        
        Tentacles.shared.logger = logger
        Tentacles.shared.logLevel = [
            .request([.pretty, .cURL], .requestDefault)
        ]
        
        expect()
        
        let params = ["password": "should be redacted", "not_password": "should not be redacted"]
        
        Endpoint().get("get", parameters: params) { [weak self] (result) in
            switch result {
            case .success(_):
                break
            case .failure(_, _):
                XCTFail()
            }
            self?.fullfill()
        }
        
        wait()
    }
}
