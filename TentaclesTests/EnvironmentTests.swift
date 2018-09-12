//
//  EnvironmentTests.swift
//  TentaclesTests
//
//  Created by Mike Leavy on 6/27/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import XCTest
@testable import Tentacles

class EnvironmentTests: XCTestCase {
    
    var manager = EnvironmentManager()
    
    override func setUp() {
        super.setUp()
        manager = EnvironmentManager()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testStringLoad() {
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
                              "name": "QA",
                              "host": "qa.httpbin.org",
                              "scheme": "https"
                            },
                            {
                              "name": "DEV",
                              "host": "dev.httpbin.org"
                            },
                            {
                              "name": "localhost",
                              "host": "localhost",
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
    }
    
    func testEnvironmentByName() {
        testStringLoad()
        
        let environment = manager.environment(named: "HTTPBin")
        XCTAssert(environment != nil, "environment = nil")
        
        XCTAssert(manager.environments?.environments?.count == 1, "expected 1 environment")
        
        let notEnvironment = manager.environment(named: "xhttpbin")
        XCTAssertNil(notEnvironment, "expected nil environment")
        
        let caseInsensitiveEnvironment = manager.environment(named: "httpbin")
        XCTAssertNotNil(caseInsensitiveEnvironment, "caseInsensitiveEnvironment = nil")
    }
    
    func testConfigurations() {
        testStringLoad()
        
        let environment = manager.environment(named: "HTTPBin")
        XCTAssert(environment != nil, "environment = nil")
        manager.cache.set(configuration: nil, forEnvironment: environment!)
        XCTAssert(manager.host(for: environment!) == "httpbin.org", "expected default host")
        
        manager.use(.testing, forEnvironment: environment!)
        XCTAssert(manager.host(for: environment!) == "dev.httpbin.org", "expected testing host")
        
        manager.use(.custom("localhost"), forEnvironment: environment!)
        let scheme = manager.scheme(for: environment!)
        XCTAssertEqual(scheme, "http", "expected an http scheme")
        
    }
    
    func testSetHost() {
        testStringLoad()
        
        let environment = manager.environment(named: "HTTPBin")
        XCTAssert(environment != nil, "environment = nil")
        
        manager.use(.production, forEnvironment: environment!)
        
        let configuration = manager.configuration(named: "PROD", forEnviornment: environment!)
        XCTAssertNotNil(configuration, "configuration is nil")
        var hostSet = manager.setHost("foo", forEnvironment: environment!, forConfiguration: configuration!)
        
        XCTAssertFalse(hostSet)
        
        let mutableConfiguration = manager.configuration(named: "USER", forEnviornment: environment!)
        XCTAssertNotNil(mutableConfiguration, "mutableConfiguration is nil")
        hostSet = manager.setHost("foo", forEnvironment: environment!, forConfiguration: mutableConfiguration!)
        XCTAssertTrue(hostSet)
    }
    
    func testInvalidConfiguration() {
        
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
                              "name": "z",
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
                              "host": "dev.httpbin.org"
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
        
        manager.use(configuration: nil, forEnvironment: environment!)
        
        let environmentHost = manager.host(for: environment!)
        XCTAssertNil(environmentHost, "expected to not find a default host")
        
    }
    
    func testVariables() {
        
        let json =  """
                    {
                      "environments": [
                        {
                          "name": "HTTPBin",
                          "default_configuration_name": "production",
                          "production_configuration_name": "production",
                          "testing_configuration_name": "dev",
                          "configurations": [
                            {
                              "name": "production",
                              "host": "httpbin.org",
                              "variables": [
                                {
                                  "key": "test",
                                  "value": "success"
                                }
                              ]
                            },
                            {
                              "name": "dev",
                              "host": "dev.httpbin.org"
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
        
        let prod = manager.configuration(named: "production", forEnviornment: environment!)
        XCTAssertNotNil(prod, "expected to find production configuration")
        
        manager.use(.production, forEnvironment: environment!)
        let string = "this/is/a/{test}/path"
        let variabled = manager.replaceVariables(in: string, for: environment!)
        XCTAssertEqual(variabled, "this/is/a/success/path", "expected variable replacement")
        
        manager.use(.testing, forEnvironment: environment!)
        let variabled2 = manager.replaceVariables(in: string, for: environment!)
        XCTAssertEqual(variabled2, string, "expected no variable replacement")
        
    }
    
}


















