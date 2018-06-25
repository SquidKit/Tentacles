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
class Logger: Logable {
    var callback: LoggerCallback?
    
    func log(_ message: String, level: LogLevel) {
        callback?(message, expectedLogLevel.contains(level))
        print("\n===========\n\n\(message)\n\n===========\n")
    }
    
    var expectedLogLevel: LogLevel = []
}

class TentaclesTests: XCTestCase {
    
    static var timeout: TimeInterval = 10
    var textExpectation: XCTestExpectation?
    
    class func printError(_ error: Error?) {
        print(error?.localizedDescription ?? "no error description")
    }
    
    class func printString(_ string: String?) {
        print(string ?? "nil string")
    }
    
    override func setUp() {
        super.setUp()
        Session.shared.host = "httpbin.org"
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
        
        let logger = Logger()
        logger.expectedLogLevel = .none
        logger.callback = { (message, found) in
            XCTAssertFalse(found, "expected found log level to be false (logger is expecting none, but Tentacles is expecting all")
        }
        
        Tentacles.shared.logger = logger
        Tentacles.shared.logLevel = .all
        
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
        
        let logger = Logger()
        logger.expectedLogLevel = .request
        logger.callback = { (message, found) in
            XCTAssertTrue(found, "expected found log level to be true")
        }
        
        Tentacles.shared.logger = logger
        Tentacles.shared.logLevel = logger.expectedLogLevel
        
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
}
