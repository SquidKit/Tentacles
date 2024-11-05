//
//  PostAsyncTests.swift
//  TentaclesTests
//
//  Created by Donald Largen on 1/19/23.
//  Copyright © 2023 Squid Store. All rights reserved.
//

import XCTest

final class PostAsyncTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Tentacles.shared.logger = Logger()
        Tentacles.shared.logLevel = TentaclesLogLevel.all
    }
    
    
    func testPost() async throws {
        let body = ["title": 100]
        
        let sessionConfig = Session.SessionConfiguration(
            scheme: "http",
            host: "jsonplaceholder.typicode.com",
            authorizationHeaderKey: nil,
            authorizationHeaderValue: nil,
            headers: nil,
            isWrittingDisabled: false,
            timeout: 60)
        
        let asyncSession = AsyncSession(sessionConfiguration: sessionConfig)
        let inputFormatter = DateFormatter()
        
        let postResult: [String: Int] = try await asyncSession.post(
            path: "posts",
            body: body,
            inputDateFormatter: inputFormatter,
            dateFormatters: [])
        
        guard postResult["title"] == 100 else {
            XCTFail()
            return
        }
        
    }
    

}
