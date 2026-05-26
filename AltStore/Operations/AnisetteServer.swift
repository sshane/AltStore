//
//  AnisetteServer.swift
//  AltStore
//
//  Created by Caroline Moore on 5/26/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import Foundation

import Roxas

struct AnisetteServer: Codable
{
    var name: String
    var url: URL
}

extension AnisetteServer: Identifiable
{
    var id: URL { self.url }
}

extension AnisetteServer
{
    private static let listURL = URL(string: "https://cdn.altstore.io/file/altstore/altstore/anisette-servers.json")!

    static func fetchAvailable(using session: URLSession = .shared) async throws -> [AnisetteServer]
    {
        struct Response: Decodable
        {
            var servers: [AnisetteServer]
        }

        let (data, _) = try await session.data(from: Self.listURL)
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.servers
    }

    static func validate(url: URL) async throws
    {
        let clientInfoURL = url.appending(components: "v3", "client_info")

        var request = URLRequest(url: clientInfoURL)
        request.timeoutInterval = 30

        let (data, urlResponse) = try await URLSession.shared.data(for: request)

        if let urlResponse = urlResponse as? HTTPURLResponse
        {
            // URL points at something that isn't an anisette server.
            if urlResponse.statusCode == 404
            {
                throw OperationError.invalidAnisetteServer()
            }

            guard urlResponse.statusCode == 200 else { throw URLError(.badServerResponse) }
        }

        struct Response: Decodable
        {
            var clientInfo: String
            var userAgent: String
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        _ = try decoder.decode(Response.self, from: data)
    }
}
