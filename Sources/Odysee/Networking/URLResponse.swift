//
//  URLResponse.swift
//  
//
//  Created by Alsey Coleman Miller on 8/5/23.
//

import Foundation

/// Odysee URL Response
public protocol OdyseeURLResponse: Decodable { }

public extension URLClient {
    
    func response<Request, Response>(
        _ response: Response.Type,
        for request: Request,
        server: OdyseeServer = .production,
        authorization authorizationToken: AuthorizationToken? = nil,
        statusCode: Int = 200,
        headers: [String: String] = [:]
    ) async throws -> Response where Request: OdyseeURLRequest, Response: OdyseeURLResponse {
        var headers = headers
        headers["accept"] = "application/json"
        let data = try await self.request(
            request,
            server: server,
            authorization: authorizationToken,
            statusCode: statusCode,
            headers: headers
        )
        do {
            return try JSONDecoder.odysee.decode(Response.self, from: data)
        } catch {
            #if DEBUG
            throw error
            #else
            throw OdyseeError.invalidResponse(data)
            #endif
        }
    }
}
