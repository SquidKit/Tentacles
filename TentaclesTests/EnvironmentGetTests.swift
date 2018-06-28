//
//  EnvironmentGetTests.swift
//  TentaclesTests
//
//  Created by Mike Leavy on 6/27/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import XCTest
@testable import Tentacles

class EnvironmentGetTests: XCTestCase {
    
    var manager = EnvironmentManager()
    var session = Session()
    var endpoint: Endpoint?
    
    override func setUp() {
        super.setUp()
        
        let json =  """
                    {
                      "environments": [
                        {
                          "name": "HTTPBin",
                          "default_configuration_name": "PROD",
                          "production_configuration_name": "PROD",
                          "testing_configuration_name": "DEV",
                          "configurations": [
                            {
                              "name": "PROD",
                              "host": "httpbin.org",
                              "variables": [
                                {
                                  "key": "myKey",
                                  "value": "get"
                                }
                              ]
                            },
                            {
                              "name": "DEV",
                              "host": "dev.httpbin.org",
                              "scheme": "http",
                            },
                            {
                              "name": "USER"
                            }
                          ]
                        }
                      ]
                    }
                    """
        
        do {
            try manager.loadEnvironments(jsonString: json)
        }
        catch {
            XCTFail("load environments failed")
        }
        
        let environment = manager.environment(named: "HTTPBin")
        XCTAssert(environment != nil, "environment = nil")
        
        session.environmentManager = manager
        session.environment = environment
        Session.shared = session
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testProductionExample() {
        let environment = manager.environment(named: "HTTPBin")
        XCTAssert(environment != nil, "environment = nil")
        
        manager.use(configuration: nil, forEnvironment: environment!)
        
        let expectation = XCTestExpectation(description: "")
        
        Endpoint().get("get") { (result) in
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
    
    func testTestingExample() {
        let environment = manager.environment(named: "HTTPBin")
        XCTAssert(environment != nil, "environment = nil")
        
        manager.use(.testing, forEnvironment: environment!)
        
        let expectation = XCTestExpectation(description: "")
        
        Endpoint().get("get") { (result) in
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
    
    func testProductionScheme() {
        let environment = manager.environment(named: "HTTPBin")
        XCTAssert(environment != nil, "environment = nil")
        
        manager.use(configuration: nil, forEnvironment: environment!)
        
        let expectation = XCTestExpectation(description: "")
        
        let task = Endpoint().get("get") { (result) in
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
        
        let url = task.urlRequest?.url
        XCTAssertNotNil(url, "nil url")
        XCTAssertTrue(url!.absoluteString.contains("https:"))
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
        
    }
    
    func testTestingScheme() {
        let environment = manager.environment(named: "HTTPBin")
        XCTAssert(environment != nil, "environment = nil")
        
        manager.use(.testing, forEnvironment: environment!)
        
        let expectation = XCTestExpectation(description: "")
        
        let task = Endpoint().get("get") { (result) in
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
        
        let url = task.urlRequest?.url
        XCTAssertNotNil(url, "nil url")
        XCTAssertTrue(url!.absoluteString.contains("http:"))
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
    func testResetScheme() {
        let environment = manager.environment(named: "HTTPBin")
        XCTAssert(environment != nil, "environment = nil")
        
        manager.use(.testing, forEnvironment: environment!)
        
        session.environmentManager = nil
        session.host = "httpbin.org"
        
        let expectation = XCTestExpectation(description: "")
        
        let task = Endpoint().get("get") { (result) in
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
        
        let url = task.urlRequest?.url
        XCTAssertNotNil(url, "nil url")
        XCTAssertTrue(url!.absoluteString.contains("https:"))
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
}
