//
//  CustomResultTests.swift
//  TentaclesTests
//
//  Created by Mike Leavy on 3/31/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import XCTest
@testable import Tentacles

class MyResponse: Response, ResponseMaking {
    func make(data: Data?, urlResponse: URLResponse, error: Error?, responseType: Endpoint.ResponseType) -> Response {
        return MyResponse(data: data, urlResponse: urlResponse, error: error, responseType: responseType)
    }
    
    var result: ResponseMakingResult {
        if let _ = _error {
            return .failure
        }
        else {
            return .success
        }
    }
    
    var error: Error? {
        return _error
    }
    
    var _error: Error?
    var json: JSON?
    
    init(data: Data?, urlResponse: URLResponse, error: Error?, responseType: Endpoint.ResponseType) {
        _error = error
        super.init(data: data, urlResponse: urlResponse)
        
        guard let data = data else {return}
        
        json = JSON(data)
        switch json! {
        case .error(let jsonError):
            _error = error ?? jsonError
        default:
            break
        }
    }
    
    init() {
        super.init(data: nil, urlResponse: URLResponse())
    }
}

class CustomResultTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        Session.shared.host = "httpbin.org"
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testGet() {
        let expectation = XCTestExpectation(description: "")
        
        Endpoint().get("get", parameters: nil, responseType: .custom("application/json", MyResponse())) { (result) in
            switch result {
            case .success(let response):
                let isEmpty = (response as? MyResponse)?.json?.dictionary.isEmpty ?? true
                XCTAssertFalse(isEmpty, "Unexpected: empty dictionary")
                print((response as? MyResponse)?.json?.prettyString ?? "")
            case .failure(let response, _):
                print("\n\n========= FAILURE ===========\n\n")
                print(response.debugDescription)
                XCTFail()
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
    
}
