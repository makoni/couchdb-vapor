//
//  CouchDB+Deprecated.swift
//
//
//  Created by Sergei Armodin on 02.04.2024.
//

import Foundation
import AsyncHTTPClient
import NIO
import NIOHTTP1

extension CouchDBClient {
	/// Get data from DB.
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
	/// Get document by ID:
	/// ```swift
	/// // get data from DB by document ID
	/// var response = try await couchDBClient.get(dbName: "databaseName", uri: "documentId")
	///
	/// // parse JSON
	/// let bytes = response.body!.readBytes(length: response.body!.readableBytes)!
	/// let doc = try JSONDecoder().decode(ExpectedDoc.self, from: Data(bytes))
	/// ```
	///
	/// You can also provide CouchDB view document as uri and key in query.
	///
	/// Get data and parse `RowsResponse`:
	/// ```swift
	/// let response = try await couchDBClient.get(
	///     dbName: "databaseName",
	///     uri: "_design/all/_view/by_url",
	///     query: ["key": "\"\(url)\""]
	/// )
	/// let bytes = response.body!.readBytes(length: response.body!.readableBytes)!
	/// let decodedResponse = try JSONDecoder().decode(RowsResponse<ExpectedDoc>.self, from: data)
	/// print(decodedResponse.rows)
	/// print(decodedResponse.rows.first?.value)
	/// ```
	///
	/// - Parameters:
	///   - dbName: DB name.
	///   - uri: URI (view or document id).
	///   - query: Request query items.
	///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
	/// - Returns: Request response.
	@available(*, deprecated, message: "Use the new `get(fromDB:uri:queryItems:eventLoopGroup)` method.")
	public func get(dbName: String, uri: String, queryItems: [URLQueryItem]? = nil, eventLoopGroup: EventLoopGroup? = nil) async throws -> HTTPClient.Response {
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

		let url = buildUrl(path: "/" + dbName + "/" + uri, query: queryItems ?? [])
		let request = try buildRequestOld(fromUrl: url, withMethod: .GET)
		let response = try await httpClient
			.execute(request: request, deadline: .now() + .seconds(requestsTimeout))
			.get()

		if response.status == .unauthorized {
			throw CouchDBClientError.unauthorized
		}

		return response
	}

	/// Find data in DB by selector.
	///
	/// Example:
	/// ```swift
	/// let selector = ["selector": ["name": "Greg"]]
	/// let bodyData = try JSONEncoder().encode(selector)
	/// var findResponse = try await couchDBClient.find(in: testsDB, body: .data(bodyData))
	///
	/// let bytes = findResponse.body!.readBytes(length: findResponse.body!.readableBytes)!
	/// let docs = try JSONDecoder().decode(CouchDBFindResponse<ExpectedDoc>.self, from: Data(bytes)).docs
	/// ```
	/// - Parameters:
	///   - dbName: DB name.
	///   - body: Request body data.
	///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
	/// - Returns: Request response.
	@available(*, deprecated, message: "Use the new 'find(inDB:body:eventLoopGroup)' method.")
	public func find(in dbName: String, body: HTTPClient.Body, eventLoopGroup: EventLoopGroup? = nil) async throws -> HTTPClient.Response {
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

		let url = buildUrl(path: "/" + dbName + "/_find", query: [])
		var request = try buildRequestOld(fromUrl: url, withMethod: .POST)
		request.body = body
		let response = try await httpClient
			.execute(request: request, deadline: .now() + .seconds(requestsTimeout))
			.get()

		if response.status == .unauthorized {
			throw CouchDBClientError.unauthorized
		}

		return response
	}

	/// Build HTTP request from url string.
	/// - Parameters:
	///   - url: URL string.
	///   - method: HTTP method.
	/// - Returns: HTTP Request.
	private func buildRequestOld(fromUrl url: String, withMethod method: HTTPMethod) throws -> HTTPClient.Request  {
		var headers = HTTPHeaders()
		headers.add(name: "Content-Type", value: "application/json")
		if let cookie = sessionCookie {
			headers.add(name: "Cookie", value: cookie)
		}
		return try HTTPClient.Request(
			url: url,
			method: method,
			headers: headers,
			body: nil
		)
	}

	@available(*, deprecated, renamed: "get", message: "Renamed to: get(fromDB:uri:queryItems:dateDecodingStrategy:eventLoopGroup)")
	public func get <T: Codable & CouchDBRepresentable>(dbName: String, uri: String, queryItems: [URLQueryItem]? = nil, dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .secondsSince1970, eventLoopGroup: EventLoopGroup? = nil) async throws -> T {
		return try await get(fromDB: dbName, uri: uri, queryItems: queryItems, dateDecodingStrategy: dateDecodingStrategy, eventLoopGroup: eventLoopGroup)
	}

	@available(*, deprecated, renamed: "find", message: "Renamed to: find(inDB:selector:dateDecodingStrategy:eventLoopGroup)")
	public func find<T: Codable & CouchDBRepresentable>(in dbName: String, selector: Codable, dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .secondsSince1970, eventLoopGroup: EventLoopGroup? = nil) async throws -> [T] {
		return try await find(inDB: dbName, selector: selector, dateDecodingStrategy: dateDecodingStrategy, eventLoopGroup: eventLoopGroup)
	}
}
