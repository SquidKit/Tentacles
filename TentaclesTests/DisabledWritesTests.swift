//
//  DisabledWritesTests.swift
//  TentaclesTests
//
//  Created by Mike Leavy on 7/3/19.
//  Copyright © 2019 Squid Store. All rights reserved.
//

import XCTest
@testable import Tentacles

class DisabledWritesTests: XCTestCase {

    let session = Session()
    var endpoint: Endpoint?
    
    override func setUp() {
        super.setUp()
        
        session.host = "jsonplaceholder.typicode.com"
        Session.shared = session
    }

    override func tearDown() {
        
    }
    
    func testGet() {
        let expectation = XCTestExpectation(description: "")
        
        Endpoint().get("posts") { (result) in
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

    func testPost() {
        let body = ["title": "fake"]
        
        let expectation = XCTestExpectation(description: "")
        
        session.isWrittingDisabled = true
        
        // this POST should fail
        Endpoint().post("posts", parameterType: .formURLEncoded, parameters: body) { (result) in
            switch result {
            case .success(let response):
                print(response.debugDescription)
                XCTFail()
            case .failure(let response, let error):
                XCTAssert(error != nil && (error! as NSError).code == TentaclesErrorCode.requestTypeDisabledError.rawValue, "Expected requestTypeDisabledError")
                print(response.debugDescription)
                TentaclesTests.printError(error)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
        
        // but the GET should succeed
        let getExpectation = XCTestExpectation(description: "")
        
        Endpoint().get("posts") { (result) in
            switch result {
            case .success(let response):
                print(response.debugDescription)
            case .failure(let response, let error):
                print(response.debugDescription)
                TentaclesTests.printError(error)
                XCTFail()
            }
            getExpectation.fulfill()
        }
        
        wait(for: [getExpectation], timeout: TentaclesTests.timeout)
        
        
        let expectation2 = XCTestExpectation(description: "")
        
        session.isWrittingDisabled = false
        
        // finally, this POST should succeed
        Endpoint().post("posts", parameterType: .formURLEncoded, parameters: body) { (result) in
            switch result {
            case .success(let response):
                guard !response.jsonDictionary.isEmpty else {
                    XCTFail("empty dictionary")
                    return
                }
                guard let _ = response.jsonDictionary["id"] as? Int else {
                    XCTFail("no \"id\" element in response")
                    return
                }
                TentaclesTests.printString(String.fromJSON(response.jsonDictionary, pretty: true))
            case .failure(let response, let error):
                print(response.debugDescription)
                TentaclesTests.printError(error)
                XCTFail()
            }
            expectation2.fulfill()
        }
        
        wait(for: [expectation2], timeout: TentaclesTests.timeout)
        
        
    }

}
