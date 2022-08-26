//
//  ArrayParameterTests.swift
//  TentaclesTests
//
//  Created by Michael Leavy on 3/10/22.
//  Copyright © 2022 Squid Store. All rights reserved.
//

import XCTest

class ArrayParameterTests: XCTestCase {
    
    let session = Session()
    var endpoint: Endpoint?

    override func setUpWithError() throws {
        super.setUp()
        
        session.host = "httpbin.org"
        Session.shared = session
    }

    override func tearDownWithError() throws {
        super.tearDown()
    }

    func testDefault() throws {
        let expectation = XCTestExpectation(description: "")
        
        let array = [1,2,3]
        let params: [String: Any] = ["string": "hello", "int": 42, "array": array]
        
        Endpoint().get("get", parameters: params) { (result) in
            switch result {
            case .success(let response):
                print(response.debugDescription)
                guard let args = response.jsonDictionary["args"] as? [String: String] else {
                    XCTFail()
                    return
                }
                guard args["string"] == "hello" && args["int"] == "42" else {
                    XCTFail()
                    return
                }
                guard args["array"] == "[1, 2, 3]" else {
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
    
    func testLists() throws {
        let expectation = XCTestExpectation(description: "")
        
        let array1 = [1,2,3]
        let array2 = ["one", "two", "three"]
        let params: [String: Any] = ["string": "hello", "int": 42, "array1": array1, "array2": array2]
        
        let behaviors: Endpoint.ParameterArrayBehaviors = [.list(","): ["array2"], .list("-z-"): []]
        
        Endpoint().get("get", parameterType: .json, parameterArrayBehaviors: behaviors, parameters: params) { (result) in
            switch result {
            case .success(let response):
                print(response.debugDescription)
                guard let args = response.jsonDictionary["args"] as? [String: String] else {
                    XCTFail()
                    return
                }
                guard args["string"] == "hello" && args["int"] == "42" else {
                    XCTFail()
                    return
                }
                guard args["array1"] == "1-z-2-z-3" else {
                    XCTFail()
                    return
                }
                
                guard args["array2"] == "one,two,three" else {
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
    
    func testListsAndRepeats() throws {
        let expectation = XCTestExpectation(description: "")
        
        let array1 = [1,2,3]
        let array2 = ["one", "two", "three"]
        let repeating = ["hello", "goodbye", "space here"]
        let params: [String: Any] = ["string": "hello", "int": 42, "array1": array1, "array2": array2, "repeating": repeating]
        
        let behaviors: Endpoint.ParameterArrayBehaviors = [.list(","): ["array2"], .list("-z-"): [], .repeat: ["repeating"]]
        
        Endpoint().get("get", parameterType: .json, parameterArrayBehaviors: behaviors, parameters: params) { (result) in
            switch result {
            case .success(let response):
                print(response.debugDescription)
                guard let args = response.jsonDictionary["args"] as? [String: Any] else {
                    XCTFail()
                    return
                }

                guard let s = args["array1"] as? String, s == "1-z-2-z-3" else {
                    XCTFail()
                    return
                }
                
                guard let s = args["array2"] as? String, s == "one,two,three" else {
                    XCTFail()
                    return
                }
                
                guard let array = args["repeating"] as? [String] else {
                    XCTFail()
                    return
                }
                guard array.count == repeating.count else {
                    XCTFail()
                    return
                }
                
                repeating.forEach { element in
                    guard array.contains(element) else {
                        XCTFail()
                        return
                    }
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

}
