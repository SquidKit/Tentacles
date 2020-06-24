//
//  AggregateGetTests.swift
//  TentaclesTests
//
//  Created by Mike Leavy on 6/19/20.
//  Copyright © 2020 Squid Store. All rights reserved.
//

import XCTest

struct AggregateTestItem: Codable {
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

struct InvalidAggregateTestItem: Codable {
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

struct Todo: Codable {
    let userId: Int
    let id: Int
    let title: String
    let completed: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId
        case id
        case title
        case completed
    }
}

struct PostResponse: Codable {
    let id: Int
    
    enum CodingKeys: String, CodingKey {
        case id
    }
}

class AggregateGetTests: XCTestCase {

    let session = Session()
    var aggregator: EndpointAggregator!
    
    override func setUpWithError() throws {
        session.host = "jsonplaceholder.typicode.com"
        Session.shared = session
        aggregator = EndpointAggregator(session: session)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAggregate() throws {
        let expectation = XCTestExpectation(description: "")
        
        let item = AggregateItem(path: "posts/1", requestType: .get, parameterType: nil, responseType: nil, parameters: nil)
        let item2 = AggregateItem(path: "posts/2", requestType: .get, parameterType: nil, responseType: nil, parameters: nil)
        
        aggregator.request([item, item2], decoder: { (index, response) in
            do {
                let object = try response.decoded(AggregateTestItem.self)
                return (object, nil)
            }
            catch(let error) {
                return (nil, error)
            }
        }) { (results) in
            defer {
                expectation.fulfill()
            }
            
            guard results.count > 0 else {
                XCTFail()
                return
            }
            
            for result in results {
                guard let object = result.object as? AggregateTestItem else {
                    XCTFail()
                    return
                }
                
                print("\n==========")
                print(object)
                print(object.title)
                print("==========\n")
            }
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }

    func testAggregateFailure() throws {
        let expectation = XCTestExpectation(description: "")
        
        let item = AggregateItem(path: "posts/1", requestType: .get, parameterType: nil, responseType: nil, parameters: nil)
        let item2 = AggregateItem(path: "todos/2", requestType: .get, parameterType: nil, responseType: nil, parameters: nil)
        
        aggregator.request([item, item2], decoder: { (index, response) in
            do {
                let object = try response.decoded(AggregateTestItem.self)
                return (object, nil)
            }
            catch(let error) {
                return (nil, error)
            }
        }) { (results) in
            defer {
                expectation.fulfill()
            }
            
            guard results.count == 2 else {
                XCTFail()
                return
            }
            
            guard let object = results[0].object as? AggregateTestItem else {
                XCTFail()
                return
            }
            
            print(object.title)
            
            guard results[1].object == nil else {
                XCTFail()
                return
            }
            
            guard let error = results[1].error, (error as NSError).code == NSCoderValueNotFoundError else {
                XCTFail()
                return
            }
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
    func testAggregateDifferentPaths() throws {
        let expectation = XCTestExpectation(description: "")
        
        let item = AggregateItem(path: "posts/1", requestType: .get, parameterType: nil, responseType: nil, parameters: nil)
        let item2 = AggregateItem(path: "todos/2", requestType: .get, parameterType: nil, responseType: nil, parameters: nil)
        
        aggregator.request([item, item2], decoder: { (index, response) in
            do {
                switch index {
                case 0:
                    let object = try response.decoded(AggregateTestItem.self)
                    return (object, nil)
                case 1:
                    let object = try response.decoded(Todo.self)
                    return (object, nil)
                default:
                    return nil
                }
                
            }
            catch(let error) {
                return (nil, error)
            }
        }) { (results) in
            defer {
                expectation.fulfill()
            }
            
            guard results.count == 2 else {
                XCTFail()
                return
            }
            
            for i in 0..<results.count {
                
                switch i {
                case 0:
                    guard let object = results[i].object as? AggregateTestItem else {
                        XCTFail()
                        return
                    }
                    
                    print("\n==========")
                    print(object)
                    print(object.title)
                    print("==========\n")
                case 1:
                    guard let object = results[i].object as? Todo else {
                        XCTFail()
                        return
                    }
                    
                    print("\n==========")
                    print(object)
                    print(object.title)
                    print("==========\n")
                default:
                    XCTFail()
                }
                
            }
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
    func testAggregateWithFactory() throws {
        
        aggregator = EndpointAggregator(factory: { [weak self] () -> Endpoint in
            guard let session = self?.session else {
                return MyEndpoint()
            }
            return MyEndpoint(session: session)
        })
        
        let expectation = XCTestExpectation(description: "")
        
        let item = AggregateItem(path: "posts/1", requestType: .get, parameterType: nil, responseType: nil, parameters: nil)
        let item2 = AggregateItem(path: "todos/2", requestType: .get, parameterType: nil, responseType: nil, parameters: nil)
        
        aggregator.request([item, item2], decoder: { (index, response) in
            do {
                switch index {
                case 0:
                    let object = try response.decoded(AggregateTestItem.self)
                    return (object, nil)
                case 1:
                    let object = try response.decoded(Todo.self)
                    return (object, nil)
                default:
                    return nil
                }
                
            }
            catch(let error) {
                return (nil, error)
            }
        }) { (results) in
            defer {
                expectation.fulfill()
            }
            
            guard results.count == 2 else {
                XCTFail()
                return
            }
            
            for i in 0..<results.count {
                
                switch i {
                case 0:
                    guard let object = results[i].object as? AggregateTestItem else {
                        XCTFail()
                        return
                    }
                    
                    print("\n==========")
                    print(object)
                    print(object.title)
                    print("==========\n")
                case 1:
                    guard let object = results[i].object as? Todo else {
                        XCTFail()
                        return
                    }
                    
                    print("\n==========")
                    print(object)
                    print(object.title)
                    print("==========\n")
                default:
                    XCTFail()
                }
                
            }
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }
    
    func testMixedVerbs() throws {
        let expectation = XCTestExpectation(description: "")
        let body = ["title": "fake"]
        
        let item = AggregateItem(path: "posts/1", requestType: .get, parameterType: nil, responseType: nil, parameters: nil)
        let item2 = AggregateItem(path: "posts", requestType: .post, parameterType: .formURLEncoded, responseType: nil, parameters: body)
        
        aggregator.request([item, item2], decoder: { (index, response) in
            do {
                switch index {
                case 0:
                    let object = try response.decoded(AggregateTestItem.self)
                    return (object, nil)
                case 1:
                    let object = try response.decoded(PostResponse.self)
                    return (object, nil)
                default:
                    return nil
                }
                
            }
            catch(let error) {
                return (nil, error)
            }
        }) { (results) in
            defer {
                expectation.fulfill()
            }
            
            guard results.count == 2 else {
                XCTFail()
                return
            }
            
            for i in 0..<results.count {
                
                switch i {
                case 0:
                    guard let object = results[i].object as? AggregateTestItem else {
                        XCTFail()
                        return
                    }
                    
                    print("\n==========")
                    print(object)
                    print(object.title)
                    print("==========\n")
                case 1:
                    guard let object = results[i].object as? PostResponse else {
                        XCTFail()
                        return
                    }
                    
                    print("\n==========")
                    print(object)
                    print(object.id)
                    print("==========\n")
                default:
                    XCTFail()
                }
                
            }
        }
        
        wait(for: [expectation], timeout: TentaclesTests.timeout)
    }

}

class MyEndpoint: Endpoint {
    deinit {
        print("bye, endpoint")
    }
}
