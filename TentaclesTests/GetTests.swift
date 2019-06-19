//
//  GetTests.swift
//  TentaclesTests
//
//  Created by Mike Leavy on 3/30/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import XCTest
@testable import Tentacles


class GetTests: XCTestCase {
    
    let session = Session()
    var endpoint: Endpoint?
    
    override func setUp() {
        super.setUp()
        
        session.host = "jsonplaceholder.typicode.com"
        Session.shared = session
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
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
    
    func testArrayResponse() {
        let expectation = XCTestExpectation(description: "")
        
        Endpoint().get("posts") { (result) in
            switch result {
            case .success(let response):
                guard !response.jsonArray.isEmpty else {
                    XCTFail("empty array")
                    return
                }
                TentaclesTests.printString(String.fromJSON(response.jsonArray, pretty: true))
            case .failure(let response, let error):
                print(response.debugDescription)
                TentaclesTests.printError(error)
                XCTFail()
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
    func testDictionaryResponse() {
        let expectation = XCTestExpectation(description: "")
        
        Endpoint().get("posts/1") { (result) in
            switch result {
            case .success(let response):
                guard !response.jsonDictionary.isEmpty else {
                    XCTFail("empty array")
                    return
                }
                TentaclesTests.printString(String.fromJSON(response.jsonDictionary, pretty: true))
            case .failure(let response, let error):
                print(response.debugDescription)
                TentaclesTests.printError(error)
                XCTFail()
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
    func testDecodableResponse() {
        let expectation = XCTestExpectation(description: "")
        
        struct Post: Codable {
            let body: String
            let id: Int
            let title: String
            let userId: Int
            
            enum CodingKeys: String, CodingKey {
                case body, id, title, userId
            }
        }
        
        Endpoint().get("posts/1") { (result) in
            switch result {
            case .success(let response):
                guard let post = try? response.decoded(Post.self) else {
                    XCTFail("decoding failed")
                    return
                }
                print(post.title)
            case .failure(let response, let error):
                print(response.debugDescription)
                TentaclesTests.printError(error)
                XCTFail()
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
    func testDecodableFailure() {
        let expectation = XCTestExpectation(description: "")
        
        struct Post: Codable {
            let bodyzzz: String
            
            enum CodingKeys: String, CodingKey {
                case bodyzzz
            }
        }
        
        Endpoint().get("posts/1") { (result) in
            switch result {
            case .success(let response):
                let post = try? response.decoded(Post.self)
                XCTAssertNil(post, "post should be nil")
            case .failure(let response, let error):
                print(response.debugDescription)
                TentaclesTests.printError(error)
                XCTFail()
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
    func testStringGetFullyQualified() {
        let expectation = XCTestExpectation(description: "")
        
        "http://jsonplaceholder.typicode.com/posts/1".get { (result) in
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
    
    func testStringGetPartialPath() {
        let expectation = XCTestExpectation(description: "")
        
        // This is expected to fail, since there is no session from
        // which to infer a host
        "posts/1".get { (result) in
            switch result {
            case .success(let response):
                print(response.debugDescription)
                XCTFail("a partial-path string get with no session should fail")
            case .failure(let response, let error):
                print(response.debugDescription)
                TentaclesTests.printError(error)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
        
    }
}
