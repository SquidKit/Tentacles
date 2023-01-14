//
//  DownloadAsyncTests.swift
//  TentaclesTests
//
//  Created by Donald Largen on 1/12/23.
//  Copyright © 2023 Squid Store. All rights reserved.
//

import XCTest

final class DownloadAsyncTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Tentacles.shared.logger = Logger()
        Tentacles.shared.logLevel = TentaclesLogLevel.all
    }
    
    func testDownloadImageData() async throws {
        
        let sessionConfig = Session.SessionConfiguration(
            scheme: "http",
            host: "httpbin.org",
            authorizationHeaderKey: nil,
            authorizationHeaderValue: nil,
            headers: nil,
            isWrittingDisabled: false,
            timeout: 60)
        
        let asynSession = AsyncSession(sessionConfiguration: sessionConfig)
        var complete: Double? = nil
        let data = try await asynSession.download(
            "/image/jpeg",
            parameters: nil,
            progress: { bytesWritten, totalBytesWritten, totalBytesExpectedToWrite, percentComplete in
                complete = percentComplete
            })
        
        guard let _ = complete else {
            XCTFail()
            return
        }
        
        guard let _ = UIImage(data: data) else {
            XCTFail()
            return
        }
        
        
    }
}
