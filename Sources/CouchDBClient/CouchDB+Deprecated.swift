//
//  CouchDB+Deprecated.swift
//
//
//  Created by Sergei Armodin on 02.04.2024.
//

import Foundation
import AsyncHTTPClient
import NIO

extension CouchDBClient {
	/// Insert data in DB. Accepts HTTPClient.Body as body parameter.
	///
	/// Examples:
	///
	/// Define your document model:
	/// ```swift
	/// // Example struct
	/// struct ExpectedDoc: CouchDBRepresentable, Codable {
	///     var name: String
	///     var _id: String?
	///     var _rev: String?
	/// }
	/// ```
	///
	///	Create a new document and insert:
	/// ```swift
	/// let testDoc = ExpectedDoc(name: "My name")
	/// let data = try JSONEncoder().encode(testData)
	///
	/// let response = try await couchDBClient.insert(
	///     dbName: "databaseName",
	///     body: .data(data)
	/// )
	///
	/// print(response)
	/// ```
	///
	/// - Parameters:
	///   - dbName: DB name.
	///   - body: Request body data.
	///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
	/// - Returns: Insert request response.
	@available(*, deprecated, message: "Use the insert method that accepts HTTPClientRequest.Body type.")
	public func insert(dbName: String, body: HTTPClient.Body, eventLoopGroup: EventLoopGroup? = nil) async throws -> CouchUpdateResponse {
		try await authIfNeed(eventLoopGroup: eventLoopGroup)

		let httpClient: HTTPClient
		if let eventLoopGroup = eventLoopGroup {
			httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
		} else {
			httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
		}

		defer {
			DispatchQueue.main.async {
				try? httpClient.syncShutdown()
			}
		}

		let url = buildUrl(path: "/\(dbName)")

		var request = try self.buildRequest(fromUrl: url, withMethod: .POST)
		request.body = body

		let response = try await httpClient
			.execute(request: request, deadline: .now() + .seconds(requestsTimeout))
			.get()

		if response.status == .unauthorized {
			throw CouchDBClientError.unauthorized
		}

		guard var body = response.body, let bytes = body.readBytes(length: body.readableBytes) else {
			throw CouchDBClientError.unknownResponse
		}

		let data = Data(bytes)
		let decoder = JSONDecoder()

		do {
			let decodedResponse = try decoder.decode(CouchUpdateResponse.self, from: data)
			return decodedResponse
		} catch let parsingError {
			if let couchdbError = try? decoder.decode(CouchDBError.self, from: data) {
				throw CouchDBClientError.insertError(error: couchdbError)
			}
			throw parsingError
		}
	}

}
