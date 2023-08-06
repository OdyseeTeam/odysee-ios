//
//  ContentRequest.swift
//  
//
//  Created by Alsey Coleman Miller on 8/5/23.
//

import Foundation

internal struct ContentRequest: Equatable, Hashable, Codable, OdyseeURLRequest {
    
    public static var method: HTTPMethod { .get }
            
    public var body: Data? { nil }
    
    public func url(for server: OdyseeServer) -> URL {
        URL(server: server)
            .appendingPathComponent("$")
            .appendingPathComponent("api")
            .appendingPathComponent("content")
            .appendingPathComponent("v2")
            .appendingPathComponent("get")
    }
}

internal struct ContentResponse: Equatable, Hashable, Codable, OdyseeURLResponse {
    
    public let status: String
    
    public let error: String?
    
    public let data: [String: Content]
}

public extension URLClient {
    
    /// Fetch Odysee content.
    func fetchContent(
        authorization token: AuthorizationToken? = nil,
        server: OdyseeServer = .production
    ) async throws -> [String: Content] {
        let request = ContentRequest()
        let response = try await self.response(
            ContentResponse.self,
            for: request,
            server: server,
            authorization: token,
            statusCode: 200
        )
        return response.data
    }
}
