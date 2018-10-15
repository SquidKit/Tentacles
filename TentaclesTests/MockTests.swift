//
//  MockTests.swift
//  TentaclesTests
//
//  Created by Mike Leavy on 10/15/18.
//  Copyright © 2018 Squid Store. All rights reserved.
//

import XCTest

class MockTests: XCTestCase {
    
    let session = Session()
    var endpoint: Endpoint?

    override func setUp() {
        super.setUp()
        
        session.host = "jsonplaceholder.typicode.com"
        Session.shared = session
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testMockData() {
        let mockData =
            """
            {
            "userId": 1,
            "id": 1,
            "title": "My Title",
            "body": "body"
            }
            """
        guard let data = mockData.data(using: .utf8) else {
            XCTFail()
            return
        }
        
        let expectation = XCTestExpectation(description: "")
        
        endpoint = Endpoint(session: session)
        endpoint?.mock(data: data)
        
        endpoint?.get("foo", completion: { (result) in
            switch result {
            case .success(let response):
                let json = response.jsonDictionary
                guard let title = json["title"] as? String else {
                    XCTFail()
                    return
                }
                guard title == "My Title" else {
                    XCTFail()
                    return
                }
                print(json)
            case .failure(_, _):
                XCTFail()
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }

    func testMockString() {
        let mockJSON =
        """
            {
            "userId": 1,
            "id": 1,
            "title": "My Title",
            "body": "body"
            }
            """
        
        let expectation = XCTestExpectation(description: "")
        
        endpoint = Endpoint(session: session)
        endpoint?.mock(jsonString: mockJSON)
        
        endpoint?.get("foo", completion: { (result) in
            switch result {
            case .success(let response):
                let json = response.jsonDictionary
                guard let title = json["title"] as? String else {
                    XCTFail()
                    return
                }
                guard title == "My Title" else {
                    XCTFail()
                    return
                }
                print(json)
            case .failure(_, _):
                XCTFail()
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
    func testMockStringFailure() {
        let mockJSON =
        """
            {
            "userId": 1,
            "id": 1,
            "title": "My Title",
            "body": "body"
            }
            """
        
        let expectation = XCTestExpectation(description: "")
        
        endpoint = Endpoint(session: session)
        endpoint?.mock(jsonString: mockJSON)
        
        endpoint?.get("foo", completion: { (result) in
            switch result {
            case .success(let response):
                let json = response.jsonDictionary
                guard let title = json["title"] as? String else {
                    XCTFail()
                    return
                }
                guard title == "My Title" else {
                    XCTFail()
                    return
                }
                print(json)
            case .failure(_, _):
                XCTFail()
            }
            expectation.fulfill()
            
        })
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
        
        
        let expectation2 = XCTestExpectation(description: "")
        
        endpoint?.get("foo", completion: { (result) in
            switch result {
            case .success(_):
                XCTFail()
            case .failure(_, _):
                break
            }
            expectation2.fulfill()
        })
        
        wait(for: [expectation2], timeout: TentaclesTests.timeout)
    }

}
