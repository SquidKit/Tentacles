//
//  EndpointAsyncTests.swift
//  Tentacles
//
//  Created by Donald Largen on 1/30/23.
//  Copyright © 2023 Squid Store. All rights reserved.
//

import XCTest

final class EndpointAsyncTests: XCTestCase {

    struct GetResult: Codable {
        let args: [String: String]
    }
    
    func testGet () async throws {
          
        let sessionConfig = Session.SessionConfiguration(
            scheme: "http",
            host: "httpbin.org",
            authorizationHeaderKey: nil,
            authorizationHeaderValue: nil,
            headers: nil,
            isWrittingDisabled: false,
            timeout: 60)
            let session = Session()
            session.sessionConfiguration = sessionConfig
        
        let endPoint = Endpoint(session: session)
        let params = ["foo": "bar"]
        
        let getResult:GetResult = try await endPoint.get(
            path: "get",
            parameters: params,
            dateFormatters: [])
        
        guard getResult.args["foo"] == "bar" else {
              XCTFail()
              return
        }
    }
    
    func testPost() async throws {
        let body = ["title": 100]
        
        let sessionConfig = Session.SessionConfiguration(
            scheme: "https",
            host: "jsonplaceholder.typicode.com",
            authorizationHeaderKey: nil,
            authorizationHeaderValue: nil,
            headers: nil,
            isWrittingDisabled: false,
            timeout: 60)
            
            let session = Session()
            session.sessionConfiguration = sessionConfig
    
            let endPoint = Endpoint(session: session)
            let inputFormatter = DateFormatter()
            
            let postResult: [String: Int] = try await endPoint.post(
                path: "posts",
                body: body,
                inputDateFormatter: inputFormatter,
                dateFormatters: [])
            
            guard postResult["title"] == 100 else {
                XCTFail("Title should be 100")
                return
            }
            
        }
}

