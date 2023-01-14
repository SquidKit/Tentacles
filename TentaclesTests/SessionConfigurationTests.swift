//
//  SessionConfigurationTests.swift
//  TentaclesTests
//
//  Created by Mike Leavy on 1/20/21.
//  Copyright © 2021 Squid Store. All rights reserved.
//

import XCTest

class SessionConfigurationTests: XCTestCase {
    
    let session = Session()
    var endpoint: Endpoint?

    override func setUpWithError() throws {
        session.host = "jsonplaceholderxxx.typicode.com"
        Session.shared = session
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testNoConfiguration() throws {
        let expectation = XCTestExpectation(description: "")
        
        endpoint = Endpoint(session: session)
        
        // we expect failure here, because the host as set up initially in invalid
        endpoint?.get("posts") { (result) in
            switch result {
            case .success(let response):
                print(response.debugDescription)
                XCTFail()
            case .failure(let response, let error):
                print(response.debugDescription)
                TentaclesTests.printError(error)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }

    func testWtihConfiguration() throws {
        let expectation = XCTestExpectation(description: "")
        
        endpoint = Endpoint(session: session)
        session.sessionConfigurationCallback = {
            return Session.SessionConfiguration(scheme: "http", host: "jsonplaceholder.typicode.com", authorizationHeaderKey: nil, authorizationHeaderValue: nil, headers: nil, isWrittingDisabled: nil, timeout: nil)
        }
        
        endpoint?.get("posts") { (result) in
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
