//
//  couchdb_vapor.swift
//  couchdb-vapor
//
//  Created by Sergey Armodin on 06/03/2019.
//

import Foundation
import NIO
import NIOHTTP1
import AsyncHTTPClient


public class CouchDBClient: NSObject {
	public enum CouchDBProtocol: String {
		case http
		case https
	}
	
	// MARK: - Public properties
	
	/// Flag if did authorize in CouchDB
	public var isAuthorized: Bool { authData?.ok ?? false }
	
	// MARK: - Private properties
	/// Protocol
	private var couchProtocol: CouchDBProtocol = .http
	/// Host
	private var couchHost: String = "127.0.0.1"
	/// Port
	private var couchPort: Int = 5984
	/// Base URL
	private var couchBaseURL: String = ""
	/// Session cookie for requests that needs authorization
	private var sessionCookie: String?
	/// CouchDB user name
	private var userName: String = ""
	/// CouchDB user password
	private var userPassword: String = ""
	/// Authorization response from CouchDB
	private var authData: CreateSessionResponse?


	// MARK: - Init

	/// Init method
	/// - Parameters:
	///   - couchProtocol: protocol (http or https)
	///   - couchHost: host
	///   - couchPort: port
	///   - userName: username
	///   - userPassword: user password
	public init(couchProtocol: CouchDBProtocol = .http, couchHost: String = "127.0.0.1", couchPort: Int = 5984, userName: String = "", userPassword: String = "") {
		self.couchProtocol = couchProtocol
		self.couchHost = couchHost
		self.couchPort = couchPort
		self.userName = userName

		self.userPassword = userPassword.isEmpty
		? ProcessInfo.processInfo.environment["ADMINPASS"] ?? userPassword
		: userPassword
		
		super.init()
	}
	
	
	// MARK: - Public methods

	/// Get DBs list
	/// - Parameter worker: Worker (EventLoopGroup)
	/// - Returns: Future (EventLoopFuture) with array of strings containing DBs names
	public func getAllDBs(worker: EventLoopGroup) async throws -> [String]? {
		let httpClient = HTTPClient(eventLoopGroupProvider: .shared(worker))
		defer {
			DispatchQueue.main.async {
				try? httpClient.syncShutdown()
			}
		}
		
		let url = buildUrl(path: "/_all_dbs")
		try await authIfNeed(worker: worker)

		let request = try self.buildRequest(fromUrl: url, withMethod: .GET)
		let response = try await httpClient
			.execute(request: request)
			.get()

		guard var body = response.body, let bytes = body.readBytes(length: body.readableBytes) else { return nil }

		let data = Data(bytes)
		return try JSONDecoder().decode([String].self, from: data)
	}

	/// Get data from DB
	/// - Parameters:
	///   - dbName: DB name
	///   - uri: uri (view or document id)
	///   - query: requst query
	///   - worker: Worker (EventLoopGroup)
	/// - Returns: Future (EventLoopFuture) with response
	public func get(dbName: String, uri: String, query: [String: String]? = nil, worker: EventLoopGroup) async throws -> HTTPClient.Response {
		let httpClient = HTTPClient(eventLoopGroupProvider: .shared(worker))
		
		defer {
			DispatchQueue.main.async {
				try? httpClient.syncShutdown()
			}
		}
		
		var queryItems: [URLQueryItem] = []
		if let queryArray = query {
			for item in queryArray {
				queryItems.append(
					URLQueryItem(name: item.key, value: item.value)
				)
			}
		}
		let url = buildUrl(path: "/" + dbName + "/" + uri, query: queryItems)
		
		return try await httpClient
			.get(url: url)
			.get()
	}

	/// Update data in DB
	/// - Parameters:
	///   - dbName: DB name
	///   - uri: uri (view or document id)
	///   - body: data which will be in request body
	///   - worker: Worker (EventLoopGroup)
	/// - Returns: Future (EventLoopFuture) with update response (CouchUpdateResponse)
	public func update(dbName: String, uri: String, body: HTTPClient.Body, worker: EventLoopGroup ) async throws -> CouchUpdateResponse {
		let httpClient = HTTPClient(eventLoopGroupProvider: .shared(worker))
		
		defer {
			DispatchQueue.main.async {
				try? httpClient.syncShutdown()
			}
		}

		let url = buildUrl(path: "/" + dbName + "/" + uri)
		
		var request = try HTTPClient.Request(url:url, method: .PUT)
		request.headers.add(name: "Content-Type", value: "application/json")
		request.body = body

		let response = try await httpClient
			.execute(request: request, deadline: .now() + .seconds(30))
			.get()
		
		guard var body = response.body, let bytes = body.readBytes(length: body.readableBytes) else {
			return CouchUpdateResponse(ok: false, id: "", rev: "")
		}

		let data = Data(bytes)
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .secondsSince1970
		return try decoder.decode(CouchUpdateResponse.self, from: data)
	}

	/// Insert document in DB
	/// - Parameters:
	///   - dbName: DB name
	///   - body: data which will be in request body
	///   - worker: Worker (EventLoopGroup)
	/// - Returns: Future (EventLoopFuture) with insert response (CouchUpdateResponse)
	public func insert(dbName: String, body: HTTPClient.Body, worker: EventLoopGroup) async throws -> CouchUpdateResponse {
		let httpClient = HTTPClient(eventLoopGroupProvider: .shared(worker))
		
		defer {
			DispatchQueue.main.async {
				try? httpClient.syncShutdown()
			}
		}

		let url = buildUrl(path: "/\(dbName)")

		var request = try HTTPClient.Request(url:url, method: .POST)
		request.headers.add(name: "Content-Type", value: "application/json")
		request.body = body

		let response = try await httpClient
			.execute(request: request, deadline: .now() + .seconds(30))
			.get()
		
		guard var body = response.body, let bytes = body.readBytes(length: body.readableBytes) else {
			return CouchUpdateResponse(ok: false, id: "", rev: "")
		}

		let data = Data(bytes)
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .secondsSince1970
		return try decoder.decode(CouchUpdateResponse.self, from: data)
	}

	/// Delete document from DB
	/// - Parameters:
	///   - dbName: DB name
	///   - uri: document uri (usually _id)
	///   - rev: document revision (usually _rev)
	///   - worker: Worker (EventLoopGroup)
	/// - Returns: Future (EventLoopFuture) with delete response (CouchUpdateResponse)
	public func delete(fromDb dbName: String, uri: String, rev: String, worker: EventLoopGroup) async throws -> CouchUpdateResponse {
		let httpClient = HTTPClient(eventLoopGroupProvider: .shared(worker))
		
		defer {
			DispatchQueue.main.async {
				try? httpClient.syncShutdown()
			}
		}

		let url = buildUrl(path: "/" + dbName + "/" + uri, query: [
			URLQueryItem(name: "rev", value: rev)
		])

		let response = try await httpClient
			.delete(url: url)
			.get()

		guard var body = response.body, let bytes = body.readBytes(length: body.readableBytes) else {
			return CouchUpdateResponse(ok: false, id: "", rev: "")
		}

		let data = Data(bytes)
		return try JSONDecoder().decode(CouchUpdateResponse.self, from: data)
	}
}


// MARK: - Private methods
internal extension CouchDBClient {
	/// Build URL string
	/// - Parameters:
	///   - path: path
	///   - query: URL query
	/// - Returns: URL string
	func buildUrl(path: String, query: [URLQueryItem] = []) -> String {
		var components = URLComponents()
		components.scheme = couchProtocol.rawValue
		components.host = couchHost
		components.port = couchPort
		components.path = path
		
		components.queryItems = query.isEmpty ? nil : query
		
		if components.url?.absoluteString == nil {
			assertionFailure("url should not be nil")
		}
		return components.url?.absoluteString ?? ""
	}

	/// Get authorization cookie in didn't yet. This cookie will be added automatically to requests that require authorization
	/// API reference: https://docs.couchdb.org/en/stable/api/server/authn.html#session
	/// - Parameter worker: Worker (EventLoopGroup)
	/// - Returns: Future (EventLoopFuture) with authorization response (CreateSessionResponse)
	@discardableResult
	func authIfNeed(worker: EventLoopGroup) async throws -> CreateSessionResponse? {
		// already authorized
		if let authData = authData {
			return authData
		}
		
		let httpClient = HTTPClient(eventLoopGroupProvider: .shared(worker))
		
		defer {
			DispatchQueue.main.async {
				try? httpClient.syncShutdown()
			}
		}
		
		let url = buildUrl(path: "/_session")
		
		var request = try HTTPClient.Request(url:url, method: .POST)
		request.headers.add(name: "Content-Type", value: "application/x-www-form-urlencoded")
		let dataString = "name=\(userName)&password=\(userPassword)"
		request.body = HTTPClient.Body.string(dataString)

		let response = try await httpClient
			.execute(request: request, deadline: .now() + .seconds(30))
			.get()

		var cookie = ""
		response.headers.forEach { (header: (name: String, value: String)) in
			if header.name == "Set-Cookie" {
				cookie = header.value
			}
		}
		sessionCookie = cookie

		guard var body = response.body, let bytes = body.readBytes(length: body.readableBytes) else { return nil }

		let data = Data(bytes)
		authData = try JSONDecoder().decode(CreateSessionResponse.self, from: data)
		return authData
	}
	
	/// Build HTTP request from url string
	/// - Parameters:
	///   - url: url string
	///   - method: HTTP method
	/// - Returns: request
	func buildRequest(fromUrl url: String, withMethod method: HTTPMethod) throws -> HTTPClient.Request  {
		var headers = HTTPHeaders()
		if let cookie = sessionCookie {
			headers = HTTPHeaders([("Cookie", cookie)])
		}
		return try HTTPClient.Request(
			url: url,
			method: method,
			headers: headers,
			body: nil
		)
	}
}
