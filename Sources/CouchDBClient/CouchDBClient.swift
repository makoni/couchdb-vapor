//
//  couchdb_vapor.swift
//  couchdb-vapor
//
//  Created by Sergey Armodin on 06/03/2019.
//

import Foundation
import NIO
import AsyncHTTPClient


public class CouchDBClient: NSObject {
	// MARK: - Private properties
	
	/// Protocol
	private var couchProtocol: String = "http://"
	/// Host
	private var couchHost: String = "127.0.0.1"
	/// Port
	private var couchPort: Int = 5984
	/// Base URL
	private var couchBaseURL: String = ""


	// MARK: - Init
	public override init() {
		super.init()
		self.couchBaseURL = self.buildBaseUrl()
	}
	
	public init(couchProtocol: String = "http://", couchHost: String = "127.0.0.1", couchPort: Int = 5984) {
		self.couchProtocol = couchProtocol
		self.couchHost = couchHost
		self.couchPort = couchPort
		
		super.init()
		self.couchBaseURL = self.buildBaseUrl()
	}
	
	
	// MARK: - Public methods
	
	/// Get DBs list
	///
	/// - Parameter worker: Worker (EventLoopGroup)
	/// - Returns: Future (EventLoopFuture) with array of strings containing DBs names
	public func getAllDBs(worker: EventLoopGroup) -> EventLoopFuture<[String]?> {
		let httpClient = HTTPClient(eventLoopGroupProvider: .shared(worker))
		defer {
			try? httpClient.syncShutdown()
		}
		
		let url = self.couchBaseURL + "/_all_dbs"
		return httpClient.get(url: url).flatMap { (response) -> EventLoopFuture<[String]?> in
			guard let bytes = response.body else {
				return worker.next().makeSucceededFuture(nil)
			}
			
			let data = Data(buffer: bytes)
			let decoder = JSONDecoder()
			let response = try? decoder.decode([String].self, from: data)
			
			return worker.next().makeSucceededFuture(response)
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
	public func get(dbName: String, uri: String, query: [String: Any]? = nil, worker: EventLoopGroup) -> EventLoopFuture<HTTPClient.Response>? {
		let httpClient = HTTPClient(eventLoopGroupProvider: .shared(worker))
		defer {
			try? httpClient.syncShutdown()
		}

		let queryString = buildQuery(fromQuery: query)
		let url = self.couchBaseURL + "/" + dbName + "/" + uri + queryString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
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
		defer {
			try? httpClient.syncShutdown()
		}

		let url = self.couchBaseURL + "/" + dbName + "/" + uri
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
		defer {
			try? httpClient.syncShutdown()
		}

		let url = self.couchBaseURL + "/" + dbName
		
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
		defer {
			try? httpClient.syncShutdown()
		}

		let queryString = buildQuery(fromQuery: ["rev": rev])
		let url = self.couchBaseURL + "/" + dbName + "/" + uri + queryString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!

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
	/// Build Base URL
	///
	/// - Returns: Base URL string
	func buildBaseUrl() -> String {
		return "\(self.couchProtocol)\(self.couchHost):\(self.couchPort)"
	}
	
	/// Build query string
	///
	/// - Parameter query: params dictionary
	/// - Returns: query string
	func buildQuery(fromQuery query: [String: Any]?) -> String {
		var queryString = ""
		
		if query != nil {
			var strings = [String]()
			for (key, value) in query! {
				strings.append("\(key)=\(value)")
			}
			queryString = "?\(strings.joined(separator: "&"))"
		}
		return queryString
	}
}
