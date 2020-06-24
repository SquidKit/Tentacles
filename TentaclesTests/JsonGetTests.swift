//
//  JsonGetTests.swift
//  TentaclesTests
//
//  Created by Mike Leavy on 6/19/20.
//  Copyright © 2020 Squid Store. All rights reserved.
//

import XCTest
@testable import Tentacles

struct Item: Codable {
    let userId: Int
    let id: Int
    let title: String
    let body: String
    
    enum CodingKeys: String, CodingKey {
        case userId
        case id
        case title
        case body
    }
}

struct InvalidItem: Codable {
    let userId: Int
    let id: Int
    let title: String
    let body: String
    
    enum CodingKeys: String, CodingKey {
        case userId
        case id
        case title
        case body = "frog"
    }
}

class JsonGetTests: XCTestCase {
    
    let session = Session()
    var endpoint: JsonEndpoint?

    override func setUpWithError() throws {
        session.host = "jsonplaceholder.typicode.com"
        Session.shared = session
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testGet() throws {
        let expectation = XCTestExpectation(description: "")
        
        endpoint = JsonEndpoint(session: session)
        
        endpoint?.get("posts/1", responseObjectType: Item.self, completion: { (object, response, error) in
            defer {
                expectation.fulfill()
            }
            guard let item = object as? Item else {
                print(error?.localizedDescription ?? "")
                if let error = error {
                    print((error as NSError).code)
                    if (error as NSError).code == NSCoderValueNotFoundError {
                        print("parsing error")
                    }
                }
                XCTFail()
                return
            }
            
            guard error == nil else {
                XCTFail()
                return
            }
            
            guard response?.urlResponse != nil else {
                XCTFail()
                return
            }
            
            print(item)
            print(item.body)
            
            
        })
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
    func testParsingError() throws {
        let expectation = XCTestExpectation(description: "")
        
        endpoint = JsonEndpoint(session: session)
        
        endpoint?.get("posts/1", responseObjectType: InvalidItem.self, completion: { (object, response, error) in
            defer {
                expectation.fulfill()
            }
            
            guard let error = error else {
                XCTFail()
                return
            }
            
            guard (error as NSError).code == NSCoderValueNotFoundError else {
                XCTFail()
                return
            }
        })
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }


}
