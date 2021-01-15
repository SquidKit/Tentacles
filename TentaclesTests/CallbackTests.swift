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

}
