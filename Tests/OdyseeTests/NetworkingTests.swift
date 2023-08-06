//
//  NetworkingTests.swift
//  
//
//  Created by Alsey Coleman Miller on 8/5/23.
//

import Foundation
import XCTest
@testable import Odysee
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class NetworkingTests: XCTestCase {
    
    func testContentResponse() async throws {
        
        let client = MockClient(
            json: .contentResponse,
            url: URL(string: "https://odysee.com/$/api/content/v2/get")!
        )
        let response = try await client.fetchContent()
        XCTAssertEqual(response["en"]?.categories.count, 16)
    }
}
