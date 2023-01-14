//
//  GetAsyncTests.swift
//  TentaclesTests
//
//  Created by Donald Largen on 1/19/23.
//  Copyright © 2023 Squid Store. All rights reserved.
//

import XCTest

final class GetAsyncTests: XCTestCase {

    struct GetResult: Codable {
        let args: [String: String]
    }
    
    override func setUp() {
        super.setUp()
        Tentacles.shared.logger = Logger()
        Tentacles.shared.logLevel = TentaclesLogLevel.all
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
        
        let asyncSession = AsyncSession(sessionConfiguration: sessionConfig)
        let params = ["foo": "bar"]
        
        let getResult: GetResult = try await asyncSession.get(
            path: "get",
            parameters: params,
            dateFormatters: [])
        
        guard getResult.args["foo"] == "bar" else {
            XCTFail()
            return
        }
    }
}
