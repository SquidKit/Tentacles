//
//  DecodeTests.swift
//  TentaclesTests
//
//  Created by Mike Leavy on 4/3/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import XCTest
@testable import Tentacles

struct PathResponse: Codable {
    let args: Args
    
    enum CodingKeys: String, CodingKey {
        case args
    }
}

struct Args: Codable {
    let string: String
    let shortDate: Date?
    let longDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case string
        case shortDate = "short_date"
        case longDate = "long_date"
    }
}

class DecodeTests: XCTestCase {
    
    var parameters: [String: Any] = ["string": "hello"]
    
    override func setUp() {
        super.setUp()
        Session.shared.host = "httpbin.org"
        Tentacles.shared.logger = Logger()
        Tentacles.shared.logLevel = .all
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testBasicDecoding() {
        let expectation = XCTestExpectation(description: "")
        
        Endpoint().get("get", parameters: parameters) { (result) in
            switch result {
            case .success(let response):
                print(response.jsonDictionary)
                let pathResponse = try? response.decoded(PathResponse.self)
                XCTAssertNotNil(pathResponse, "PathResponse struct failed decoding")
                XCTAssertEqual(pathResponse?.args.string, "hello", "expected args.string to be \"hello\"")
                XCTAssertNil(pathResponse?.args.shortDate, "expected short date to be nil")
            case .failure(_, _):
                XCTFail()
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
    func testDecodingFailure() {
        let expectation = XCTestExpectation(description: "")
        
        parameters = ["zzzstring": "hello"]
        
        Endpoint().get("get", parameters: parameters) { (result) in
            switch result {
            case .success(let response):
                let pathResponse = try? response.decoded(PathResponse.self)
                XCTAssertNil(pathResponse?.args, "Arg struct should have failed decoding")
            case .failure(_, _):
                XCTFail()
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
    func testDateDecoding() {
        let expectation = XCTestExpectation(description: "")
        
        parameters = ["string": "hello", "short_date": "2018-04-03", "long_date": "2018-06-06T17:00:00.000-04:00"]
        
        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "yyyy-MM-dd"
        
        let longFormatter = DateFormatter()
        longFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        
        Endpoint().get("get", parameters: parameters) { (result) in
            switch result {
            case .success(let response):
                print(response.jsonDictionary)
                do {
                    let pathResponse = try response.decoded(PathResponse.self, dateFormatters: [shortFormatter, longFormatter])
                    XCTAssertNotNil(pathResponse.args, "Arg struct failed decoding")
                    XCTAssertNotNil(pathResponse.args.shortDate, "short date should be non-nil")
                    XCTAssertNotNil(pathResponse.args.longDate, "long date should be non-nil")
                }
                catch {
                    print(error.localizedDescription)
                    XCTFail()
                }
                
            case .failure(_, _):
                XCTFail()
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
    func testDateDecodingFailure() {
        let expectation = XCTestExpectation(description: "")
        
        parameters = ["string": "hello", "short_date": "2018-04-03", "long_date": "2018-06-06T17:00:00.000-04:00"]
        
        
        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "yyyy-MM-dd"
        
        Endpoint().get("get", parameters: parameters) { (result) in
            switch result {
            case .success(let response):
                print(response.jsonDictionary)
                let pathResponse = try? response.decoded(PathResponse.self, dateFormatters: [shortFormatter])
                XCTAssertNil(pathResponse?.args, "Arg struct should have failed decoding")
                
            case .failure(_, _):
                XCTFail()
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
}
