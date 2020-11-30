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
	var isAuthorized: Bool { authData?.ok ?? false }
	
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
	public override init() {
		super.init()
	}
	
	public init(couchProtocol: CouchDBProtocol = .http, couchHost: String = "127.0.0.1", couchPort: Int = 5984, userName: String = "", userPassword: String = "") {
		self.couchProtocol = couchProtocol
		self.couchHost = couchHost
		self.couchPort = couchPort
		self.userName = userName
		self.userPassword = userPassword
		
		super.init()
	}
	
	
	// MARK: - Public methods
	
	/// Get DBs list
	///
	/// - Parameter worker: Worker (EventLoopGroup)
	/// - Returns: Future (EventLoopFuture) with array of strings containing DBs names
	public func getAllDBs(worker: EventLoopGroup) -> EventLoopFuture<[String]?> {
		let httpClient = HTTPClient(eventLoopGroupProvider: .shared(worker))
		defer { try? httpClient.syncShutdown() }
		
		let url = buildUrl(path: "/_all_dbs")
		
		do {
			return try authIfNeed(worker: worker)
				.flatMap({ [unowned self] (session) -> EventLoopFuture<[String]?> in
					do {
						let request = try self.makeRequest(fromUrl: url, withMethod: .GET)
						return httpClient.execute(request: request).flatMap { (response) -> EventLoopFuture<[String]?> in
							guard let bytes = response.body else {
								return worker.next().makeSucceededFuture(nil)
							}
							
							let data = Data(buffer: bytes)
							let decoder = JSONDecoder()
							let databasesList = try? decoder.decode([String].self, from: data)
							
							return worker.next().makeSucceededFuture(databasesList)
						}
					} catch {
						return worker.next().makeFailedFuture(error)
					}
				})
		} catch {
			return worker.next().makeFailedFuture(error)
		}
	}

	/// Get data from DB
	///
	/// - Parameters:
	///   - dbName: DB name
	///   - uri: uri (view or document id)
	///   - query: requst query
	///   - worker: Worker (EventLoopGroup)
	/// - Returns: Future (EventLoopFuture) with response
	public func get(dbName: String, uri: String, query: [String: String]? = nil, worker: EventLoopGroup) -> EventLoopFuture<HTTPClient.Response>? {
		let httpClient = HTTPClient(eventLoopGroupProvider: .shared(worker))
		defer { try? httpClient.syncShutdown() }
		
		var queryItems: [URLQueryItem] = []
		if let queryArray = query {
			for item in queryArray {
				queryItems.append(
					URLQueryItem(name: item.key, value: item.value)
				)
			}
		}
		let url = buildUrl(path: "/" + dbName + "/" + uri, query: queryItems)
		
		return httpClient.get(url: url)
	}

	/// Update data in DB
	///
	/// - Parameters:
	///   - dbName: DB name
	///   - uri: uri (view or document id)
	///   - body: data which will be in request body
	///   - worker: Worker (EventLoopGroup)
	/// - Returns: Future (EventLoopFuture) with update response (CouchUpdateResponse)
	public func update(dbName: String, uri: String, body: HTTPClient.Body, worker: EventLoopGroup ) -> EventLoopFuture<CouchUpdateResponse>? {
		let httpClient = HTTPClient(eventLoopGroupProvider: .shared(worker))
		defer { try? httpClient.syncShutdown() }

		let url = buildUrl(path: "/" + dbName + "/" + uri)
		
		guard var request = try? HTTPClient.Request(url:url, method: .PUT) else {
			return worker.next().makeSucceededFuture(CouchUpdateResponse(ok: false, id: "", rev: ""))
		}
		request.headers.add(name: "Content-Type", value: "application/json")
		request.body = body
		
		return httpClient
			.execute(request: request, deadline: .now() + .seconds(30))
			.flatMap { (response) -> EventLoopFuture<CouchUpdateResponse> in
				guard let bytes = response.body else {
					return worker.next().makeSucceededFuture(CouchUpdateResponse(ok: false, id: "", rev: ""))
				}
				
				let data = Data(buffer: bytes)
				let decoder = JSONDecoder()
				decoder.dateDecodingStrategy = .secondsSince1970
				guard let updateResponse = try? decoder.decode(CouchUpdateResponse.self, from: data) else {
					return worker.next().makeSucceededFuture(CouchUpdateResponse(ok: false, id: "", rev: ""))
				}
				return worker.next().makeSucceededFuture(updateResponse)
		}
	}

	/// Insert document in DB
	///
	/// - Parameters:
	///   - dbName: DB name
	///   - body: data which will be in request body
	///   - worker: Worker (EventLoopGroup)
	/// - Returns: Future (EventLoopFuture) with insert response (CouchUpdateResponse)
	public func insert(dbName: String, body: HTTPClient.Body, worker: EventLoopGroup ) -> EventLoopFuture<CouchUpdateResponse>? {
		let httpClient = HTTPClient(eventLoopGroupProvider: .shared(worker))
		defer { try? httpClient.syncShutdown() }

		let url = buildUrl(path: "/\(dbName)")
		
		guard var request = try? HTTPClient.Request(url:url, method: .POST) else {
			return worker.next().makeSucceededFuture(CouchUpdateResponse(ok: false, id: "", rev: ""))
		}
		request.headers.add(name: "Content-Type", value: "application/json")
		request.body = body
		
		return httpClient
			.execute(request: request, deadline: .now() + .seconds(30))
			.flatMap { (response) -> EventLoopFuture<CouchUpdateResponse> in
				guard let bytes = response.body else {
					return worker.next().makeSucceededFuture(CouchUpdateResponse(ok: false, id: "", rev: ""))
				}
				
				let data = Data(buffer: bytes)
				let decoder = JSONDecoder()
				decoder.dateDecodingStrategy = .secondsSince1970
				guard let updateResponse = try? decoder.decode(CouchUpdateResponse.self, from: data) else {
					return worker.next().makeSucceededFuture(CouchUpdateResponse(ok: false, id: "", rev: ""))
				}
				return worker.next().makeSucceededFuture(updateResponse)
		}
	}

	/// Delete document from DB
	///
	/// - Parameters:
	///   - dbName: DB name
	///   - uri: document uri (usually _id)
	///   - rev: document revision (usually _rev)
	///   - worker: Worker (EventLoopGroup)
	/// - Returns: Future (EventLoopFuture) with delete response (CouchUpdateResponse)
	public func delete(fromDb dbName: String, uri: String, rev: String, worker: EventLoopGroup) -> EventLoopFuture<CouchUpdateResponse>? {
		let httpClient = HTTPClient(eventLoopGroupProvider: .shared(worker))
		defer { try? httpClient.syncShutdown() }

		let url = buildUrl(path: "/" + dbName + "/" + uri, query: [
			URLQueryItem(name: "rev", value: rev)
		])
		
		return httpClient.delete(url: url).flatMap { (response) -> EventLoopFuture<CouchUpdateResponse> in
			guard let bytes = response.body else {
				return worker.next().makeSucceededFuture(CouchUpdateResponse(ok: false, id: "", rev: ""))
			}
			
			let data = Data(buffer: bytes)
			let decoder = JSONDecoder()
			guard let deleteResponse = try? decoder.decode(CouchUpdateResponse.self, from: data) else {
				return worker.next().makeSucceededFuture(CouchUpdateResponse(ok: false, id: "", rev: ""))
			}
			
			return worker.next().makeSucceededFuture(deleteResponse)
		}
	}
}


// MARK: - Private methods
internal extension CouchDBClient {
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
	func authIfNeed(worker: EventLoopGroup) throws -> EventLoopFuture<CreateSessionResponse?> {
		// already authorized
		if let authData = authData {
			return worker.next().makeSucceededFuture(authData)
		}
		
		let httpClient = HTTPClient(eventLoopGroupProvider: .shared(worker))
		defer { try? httpClient.syncShutdown() }
		
		let url = buildUrl(path: "/_session")
		
		do {
			var request = try HTTPClient.Request(url:url, method: .POST)
			request.headers.add(name: "Content-Type", value: "application/x-www-form-urlencoded")
			let dataString = "name=\(userName)&password=\(userPassword)"
			request.body = HTTPClient.Body.string(dataString)
			
			return httpClient
				.execute(request: request, deadline: .now() + .seconds(30))
				.map({  [weak self] (response) -> CreateSessionResponse? in
					var cookie = ""
					response.headers.forEach { (header: (name: String, value: String)) in
						if header.name == "Set-Cookie" {
							cookie = header.value
						}
					}
					self?.sessionCookie = cookie
					
					guard let bytes = response.body else {
						return nil
					}
					
					let authData = try? JSONDecoder().decode(CreateSessionResponse.self, from: bytes)
					self?.authData = authData
					return authData
				})
		} catch {
			return worker.next().makeFailedFuture(error)
		}
	}
	
	/// Make HTTP request from url string
	/// - Parameters:
	///   - url: url string
	///   - method: HTTP method
	/// - Returns: request
	func makeRequest(fromUrl url: String, withMethod method: HTTPMethod) throws -> HTTPClient.Request  {
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
