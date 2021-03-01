//
//  PostTests.swift
//  TentaclesTests
//
//  Created by Mike Leavy on 3/30/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import XCTest
@testable import Tentacles

class PostTests: XCTestCase {
    
    var endpoint: Endpoint?
    
    override func setUp() {
        super.setUp()
        Session.shared.host = "jsonplaceholder.typicode.com"
        endpoint = Endpoint()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testPost() {
        let body = ["title": "fake"]
        
        let expectation = XCTestExpectation(description: "")
        endpoint = Endpoint()
        
        endpoint!.post("posts", parameterType: .formURLEncoded, parameters: body) { (result) in
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
                guard let _ = response.jsonDictionary["title"] as? String else {
                    XCTFail("no \"title\" element in response")
                    return
                }
                TentaclesTests.printString(String.fromJSON(response.jsonDictionary, pretty: true))
            case .failure(let response, let error):
                print(response.debugDescription)
                TentaclesTests.printError(error)
                XCTFail()
            }
            
            print(self.endpoint!.debugDescription)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
}
