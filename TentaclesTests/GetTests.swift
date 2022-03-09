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
    
    func testGetDefaultEncodedParams() {
        let expectation = XCTestExpectation(description: "")
        
        session.host = "httpbin.org"
        let params = ["foo": "bar"]
        
        Endpoint().get("get", parameters: params) { (result) in
            switch result {
            case .success(let response):
                print(response.debugDescription)
                guard let args = response.jsonDictionary["args"] as? [String: String] else {
                    XCTFail()
                    return
                }
                guard args["foo"] == "bar" else {
                    XCTFail()
                    return
                }
            case .failure(let response, let error):
                print(response.debugDescription)
                TentaclesTests.printError(error)
                XCTFail()
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
    func testGetJSONEncodedParams() {
        let expectation = XCTestExpectation(description: "")
        
        session.host = "httpbin.org"
        let params = ["foo": "bar"]
        
        Endpoint().get("get", parameterType: .json, parameters: params) { (result) in
            switch result {
            case .success(let response):
                print(response.debugDescription)
                guard let args = response.jsonDictionary["args"] as? [String: String] else {
                    XCTFail()
                    return
                }
                guard args["foo"] == "bar" else {
                    XCTFail()
                    return
                }
            case .failure(let response, let error):
                print(response.debugDescription)
                TentaclesTests.printError(error)
                XCTFail()
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
    func testGetJSONEncodedParamsWithCustomKeys() {
        let expectation = XCTestExpectation(description: "")
        
        session.host = "httpbin.org"
        let params: [String: Any] = ["foo": "bar", "custom": [1,2,3]]
        
        let customParameterType: Endpoint.ParameterType = .customKeys("application/json", ["custom"]) { key, value in
            guard let array = value as? [Int] else {return nil}
            var result = [String]()
            for element in array {
                let s = "myRepeatingKey=\(element)"
                result.append(s)
            }
            return result
        }
        
        Endpoint().get("get", parameterType: customParameterType, parameters: params) { (result) in
            switch result {
            case .success(let response):
                print(response.debugDescription)
                guard let args = response.jsonDictionary["args"] as? [String: Any] else {
                    XCTFail()
                    return
                }
                print(args)
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
