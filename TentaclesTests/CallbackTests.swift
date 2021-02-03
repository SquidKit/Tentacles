//
//  CallbackTests.swift
//  TentaclesTests
//
//  Created by Mike Leavy on 9/25/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import XCTest

class CallbackTests: XCTestCase {
    let session = Session()
    var started: String?
    var completed: String?
    var unauthorized: Bool = false

    override func setUp() {
        session.host = "jsonplaceholder.typicode.com"
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCallback() {
        
        session.requestStartedAction = { [weak self] (endpoint) in
            self?.started = endpoint.userDescription
        }
        
        session.requestCompletedAction = { [weak self] (endpoint, response) in
            self?.completed = "goodbye"
        }
        
        let expectation = XCTestExpectation(description: "")
        
        Endpoint(session: session).with("hello").get("posts") { [weak self] (result) in
            XCTAssertEqual(self?.started, "hello")
            XCTAssertEqual(self?.completed, "goodbye")
            switch result {
            case .success(let response):
                print(response.debugDescription)
            case .failure(let response, let error):
                print(response.debugDescription)
                TentaclesTests.printError(error)
                XCTFail()
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
    func testUnauthorizedNoContinue() {
        session.host = "httpbin.org"
        
        let path = "status/401"
        
        let expectation = XCTestExpectation(description: "")
        expectation.isInverted = true
        
        session.unauthorizedRequestCallback = { [weak self] in
            self?.unauthorized = true
            return false
        }
        
        Endpoint(session: session).get(path) { [weak self]
            result in
            print(result.debugDescription)
            guard let unauthorized = self?.unauthorized, unauthorized == true else {
                XCTFail()
                return
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
    func testUnauthorizedWithContinue() {
        session.host = "httpbin.org"
        
        let path = "status/401"
        
        let expectation = XCTestExpectation(description: "")
        
        session.unauthorizedRequestCallback = { [weak self] in
            self?.unauthorized = true
            return true
        }
        
        Endpoint(session: session).get(path) { [weak self]
            result in
            print(result.debugDescription)
            guard let unauthorized = self?.unauthorized, unauthorized == true else {
                XCTFail()
                return
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
}
