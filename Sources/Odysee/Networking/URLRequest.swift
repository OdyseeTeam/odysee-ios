//
//  URLRequest.swift
//  
//
//  Created by Alsey Coleman Miller on 8/5/23.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol OdyseeURLRequest {
    
    static var method: HTTPMethod { get }
        
    static var contentType: String? { get }
    
    var body: Data? { get }
    
    func url(for server: OdyseeServer) -> URL
}

public extension OdyseeURLRequest {
    
    static var method: HTTPMethod { .get }
    
    static var contentType: String? { nil }
        
    var body: Data? { nil }
}

public extension URLRequest {
    
    init<T: OdyseeURLRequest>(
        request: T,
        server: OdyseeServer = .production
    ) {
        self.init(url: request.url(for: server))
        self.httpMethod = T.method.rawValue
        self.httpBody = request.body
    }
}

public extension URLClient {
    
    @discardableResult
    func request<Request>(
        _ request: Request,
        server: OdyseeServer = .production,
        authorization authorizationToken: AuthorizationToken? = nil,
        statusCode: Int = 200,
        headers: [String: String] = [:]
    ) async throws -> Data where Request: OdyseeURLRequest {
        var urlRequest = URLRequest(
            request: request,
            server: server
        )
        if let token = authorizationToken {
            urlRequest.setAuthorization(token)
        }
        if let contentType = Request.contentType {
            urlRequest.addValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        for (header, value) in headers.sorted(by: { $0.key < $1.key }) {
            urlRequest.addValue(value, forHTTPHeaderField: header)
        }
        let (data, urlResponse) = try await self.data(for: urlRequest)
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            fatalError("Invalid response type \(urlResponse)")
        }
        guard httpResponse.statusCode == statusCode else {
            throw OdyseeError.invalidStatusCode(httpResponse.statusCode)
        }
        return data
    }
}
