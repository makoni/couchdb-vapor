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


/// A CouchDB client class with async/await methods.
public class CouchDBClient: NSObject {
	/// CouchDB client errors
	public enum CouchDBClientError: Error {
		/// **id** property is empty or missing in provided document
		case idMissing
		/// **\_rev** property is empty or missing in provided document
		case revMissing
	}

	/// Protocol (URL scheme) that should be used to perform requests to CouchDB
	public enum CouchDBProtocol: String {
		/// Use HTTP protocol
		case http
		/// Use HTTPS protocol
		case https
	}
	
	// MARK: - Public properties
	
	/// Flag if did authorize in CouchDB
	public var isAuthorized: Bool { authData?.ok ?? false }

	/// You can set timeout for requests in seconds. Default value is 30.
	public var requestsTimeout: Int64 = 30
	
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


	// MARK: - Initializer

	/// Initializer
	///
	///	Example:
	///  ```swift
	///  // use default params
	///  let myClient = CouchDBClient()
	///
	///  // provide your own params
	///  let couchDBClient = CouchDBClient(
	///      couchProtocol: .http,
	///      couchHost: "127.0.0.1",
	///      couchPort: 5984,
	///      userName: "admin",
	///      userPassword: "myPassword"
	///  )
	///  ```
	///  If you don't want to have your password in the code you can pass `COUCHDB_PASS` param in you command line.
	///  For example you can run your Server Side Swift project:
	///  ```bash
	///  COUCHDB_PASS=myPassword /path/.build/x86_64-unknown-linux-gnu/release/Run
	///  ```
	///  Just use initializer without `userPassword` param:
	///  ```swift
	///  CouchDBClient(
	///      couchProtocol: .http,
	///      couchHost: "127.0.0.1",
	///      couchPort: 5984,
	///      userName: "admin"
	///  )
	///  ```
	///
	/// - Parameters:
	///   - couchProtocol: protocol (check ``CouchDBProtocol`` enum for avaiable values )
	///   - couchHost: host of CouchDB instance
	///   - couchPort: port CouchDB works on
	///   - userName: username
	///   - userPassword: user password
	public init(couchProtocol: CouchDBProtocol = .http, couchHost: String = "127.0.0.1", couchPort: Int = 5984, userName: String = "", userPassword: String = "") {
		self.couchProtocol = couchProtocol
		self.couchHost = couchHost
		self.couchPort = couchPort
		self.userName = userName

		self.userPassword = userPassword.isEmpty
		? ProcessInfo.processInfo.environment["COUCHDB_PASS"] ?? userPassword
		: userPassword
		
		super.init()
	}
	
	
	// MARK: - Public methods

	/// Get DBs list
	///
	/// Example:
	/// ```swift
	/// let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)
	/// let dbs = try await couchDBClient.getAllDBs(worker: worker)
	/// ```
	///
	/// - Parameter worker: Worker (EventLoopGroup)
	/// - Returns: Array of strings containing DBs names
	public func getAllDBs(worker: EventLoopGroup) async throws -> [String]? {
		try await authIfNeed(worker: worker)

		let httpClient = HTTPClient(eventLoopGroupProvider: .shared(worker))
		defer {
			DispatchQueue.main.async {
				try? httpClient.syncShutdown()
			}
		}
		
		let url = buildUrl(path: "/_all_dbs")

		let request = try buildRequest(fromUrl: url, withMethod: .GET)
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
	///   - query: request query
	///   - worker: Worker (EventLoopGroup)
	/// - Returns: Request response
	@available(*, deprecated, message: "Use the same method with queryItems param passing [URLQueryItem]")
	public func get(dbName: String, uri: String, query: [String: String]?, worker: EventLoopGroup) async throws -> HTTPClient.Response {
		var queryItems: [URLQueryItem] = []
		if let queryArray = query {
			for item in queryArray {
				queryItems.append(
					URLQueryItem(name: item.key, value: item.value)
				)
			}
		}
		return try await get(dbName: dbName, uri: uri, queryItems: queryItems, worker: worker)
	}

	/// Get data from DB
	///
	/// Examples:
	///
	/// Define your document model:
	/// ```swift
	/// // Example struct
	/// struct ExpectedDoc: CouchDBRepresentable, Codable {
	///   var name: String
	///   var _id: String?
	///   var _rev: String?
	/// }
	/// ```
	///
	/// Get document by ID:
	/// ```swift
	/// // get data from DB by document ID
	/// let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)
	/// var response = try await couchDBClient.get(dbName: "databaseName", uri: "documentId", worker: worker)
	///
	/// // parse JSON
	/// let bytes = response.body!.readBytes(length: response.body!.readableBytes)!
	/// let doc = try JSONDecoder().decode(ExpectedDoc.self, from: Data(bytes))
	/// ```
	///
	/// You can also provide CouchDB view document as uri and key in query.
	/// Define Row and RowsResponse models:
	/// ```swift
	/// struct Row: Codable {
	///   let value: ExpectedDoc
	/// }
	///
	/// struct RowsResponse: Codable {
	///   let total_rows: Int
	///   let offset: Int
	///   let rows: [Row]
	/// }
	/// ```
	///
	/// Get data and parse RowsResponse:
	/// ```swift
	/// let response = try await couchDBClient.get(
	///   dbName: "databaseName",
	///   uri: "_design/all/_view/by_url",
	///   query: ["key": "\"\(url)\""],
	///   worker: worker
	/// )
	/// let bytes = response.body!.readBytes(length: response.body!.readableBytes)!
	/// let decodedResponse = try JSONDecoder().decode(RowsResponse.self, from: data)
	/// print(decodedResponse.rows)
	/// print(decodedResponse.rows.first?.value)
	/// ```
	///
	/// - Parameters:
	///   - dbName: DB name
	///   - uri: uri (view or document id)
	///   - query: request query items
	///   - worker: Worker (EventLoopGroup)
	/// - Returns: Request response
	public func get(dbName: String, uri: String, queryItems: [URLQueryItem]? = nil, worker: EventLoopGroup) async throws -> HTTPClient.Response {
		try await authIfNeed(worker: worker)

		let httpClient = HTTPClient(eventLoopGroupProvider: .shared(worker))

		defer {
			DispatchQueue.main.async {
				try? httpClient.syncShutdown()
			}
		}

		let url = buildUrl(path: "/" + dbName + "/" + uri, query: queryItems ?? [])
		let request = try buildRequest(fromUrl: url, withMethod: .GET)

		return try await httpClient
			.execute(request: request, deadline: .now() + .seconds(requestsTimeout))
			.get()
	}

	/// Update data in DB
	///
	/// Examples:
	///
	/// Define your document model:
	/// ```swift
	/// // Example struct
	/// struct ExpectedDoc: CouchDBRepresentable, Codable {
	///   var name: String
	///   var _id: String?
	///   var _rev: String?
	/// }
	/// ```
	/// Get document by ID and update it:
	/// ```swift
	/// // get data from DB by document ID
	/// let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)
	/// var response = try await couchDBClient.get(dbName: "databaseName", uri: "documentId", worker: worker)
	///
	/// // parse JSON
	/// let bytes = response.body!.readBytes(length: response.body!.readableBytes)!
	/// var doc = try JSONDecoder().decode(ExpectedDoc.self, from: Data(bytes))
	///
	/// // Update value
	/// doc.name = "Updated name"
	///
	/// // encode document into JSON string
	/// let data = try encoder.encode(updatedData)
	/// 
	/// let response = try await couchDBClient.update(
	///   dbName: testsDB,
	///   uri: doc._id!,
	///   body: .data(data),
	///   worker: worker
	/// )
	///
	/// print(response)
	/// ```
	///
	///
	/// - Parameters:
	///   - dbName: DB name
	///   - uri: uri (view or document id)
	///   - body: data which will be in request body
	///   - worker: Worker (EventLoopGroup)
	/// - Returns: Update response
	public func update(dbName: String, uri: String, body: HTTPClient.Body, worker: EventLoopGroup ) async throws -> CouchUpdateResponse {
		try await authIfNeed(worker: worker)

		let httpClient = HTTPClient(eventLoopGroupProvider: .shared(worker))
		
		defer {
			DispatchQueue.main.async {
				try? httpClient.syncShutdown()
			}
		}

		let url = buildUrl(path: "/" + dbName + "/" + uri)
		var request = try buildRequest(fromUrl: url, withMethod: .PUT)
		request.body = body

		let response = try await httpClient
			.execute(request: request, deadline: .now() + .seconds(requestsTimeout))
			.get()
		
		guard var body = response.body, let bytes = body.readBytes(length: body.readableBytes) else {
			return CouchUpdateResponse(ok: false, id: "", rev: "")
		}

		let data = Data(bytes)
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .secondsSince1970
		return try decoder.decode(CouchUpdateResponse.self, from: data)
	}

	/// Upate document in DB
	///
	/// Examples:
	///
	/// Define your document model:
	/// ```swift
	/// // Example struct
	/// struct ExpectedDoc: CouchDBRepresentable, Codable {
	///   var name: String
	///   var _id: String?
	///   var _rev: String?
	/// }
	/// ```
	/// Get document by ID and update it:
	/// ```swift
	/// // get data from DB by document ID
	/// let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)
	/// var response = try await couchDBClient.get(dbName: "databaseName", uri: "documentId", worker: worker)
	///
	/// // parse JSON
	/// let bytes = response.body!.readBytes(length: response.body!.readableBytes)!
	/// var doc = try JSONDecoder().decode(ExpectedDoc.self, from: Data(bytes))
	///
	/// // Update value
	/// doc.name = "Updated name"
	///
	/// let response = try await couchDBClient.update(
	///   dbName: testsDB,
	///   doc: doc,
	///   worker: worker
	/// )
	///
	/// print(response)
	/// ```
	///
	/// - Parameters:
	///   - dbName: DB name
	///   - doc: Document object/struct. Should confirm to ``CouchDBRepresentable`` and Codable protocols
	///   - worker: Worker (EventLoopGroup)
	/// - Returns: Update response
	public func update <T: Codable & CouchDBRepresentable>(dbName: String, doc: T, worker: EventLoopGroup ) async throws -> CouchUpdateResponse {
		guard let id = doc._id else { throw CouchDBClientError.idMissing }
		guard doc._rev?.isEmpty == false else { throw CouchDBClientError.revMissing }

		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .secondsSince1970
		let encodedData = try JSONEncoder().encode(doc)

		return try await update(
			dbName: dbName,
			uri: id,
			body: .data(encodedData),
			worker: worker
		)
	}

	/// Insert document in DB
	///
	/// Examples:
	///
	/// Define your document model:
	/// ```swift
	/// // Example struct
	/// struct ExpectedDoc: CouchDBRepresentable, Codable {
	///   var name: String
	///   var _id: String?
	///   var _rev: String?
	/// }
	/// ```
	///
	///	Create a new document and insert:
	/// ```swift
	/// let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)
	///
	/// let testDoc = ExpectedDoc(name: "My name")
	/// let data = try JSONEncoder().encode(testData)
	///
	/// let response = try await couchDBClient.insert(
	///   dbName: "databaseName",
	///   body: .data(data),
	///   worker: worker
	/// )
	///
	/// print(response)
	/// ```
	///
	/// - Parameters:
	///   - dbName: DB name
	///   - body: data which will be in request body
	///   - worker: Worker (EventLoopGroup)
	/// - Returns: Insert request response
	public func insert(dbName: String, body: HTTPClient.Body, worker: EventLoopGroup) async throws -> CouchUpdateResponse {
		try await authIfNeed(worker: worker)

		let httpClient = HTTPClient(eventLoopGroupProvider: .shared(worker))
		
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
		
		guard var body = response.body, let bytes = body.readBytes(length: body.readableBytes) else {
			return CouchUpdateResponse(ok: false, id: "", rev: "")
		}

		let data = Data(bytes)
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .secondsSince1970
		return try decoder.decode(CouchUpdateResponse.self, from: data)
	}

	/// Delete document from DB by uri
	///
	/// Examples:
	///
	/// ```swift
	/// let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)
	/// let response = try await couchDBClient.delete(
	///   fromDb: "databaseName",
	///   uri: doc._id,
	///   rev: doc._rev,
	///   worker: worker
	/// )
	///
	/// print(response)
	/// ```
	/// 
	/// - Parameters:
	///   - dbName: DB name
	///   - uri: document uri (usually _id)
	///   - rev: document revision (usually _rev)
	///   - worker: Worker (EventLoopGroup)
	/// - Returns: Delete request response
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
		let request = try self.buildRequest(fromUrl: url, withMethod: .DELETE)

		let response = try await httpClient
			.execute(request: request, deadline: .now() + .seconds(requestsTimeout))
			.get()

		guard var body = response.body, let bytes = body.readBytes(length: body.readableBytes) else {
			return CouchUpdateResponse(ok: false, id: "", rev: "")
		}

		let data = Data(bytes)
		return try JSONDecoder().decode(CouchUpdateResponse.self, from: data)
	}

	/// Delete document from DB
	///
	/// Examples:
	///
	/// ```swift
	/// let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)
	/// let response = try await couchDBClient.delete(
	///   fromDb: "databaseName",
	///   doc: doc,
	///   worker: worker
	/// )
	///
	/// print(response)
	/// ```
	///
	/// - Parameters:
	///   - dbName: DB name
	///   - doc: Document object/struct. Should confirm to ``CouchDBRepresentable`` protocol
	///   - worker: Worker (EventLoopGroup)
	/// - Returns: Delete request response
	public func delete(fromDb dbName: String, doc: CouchDBRepresentable, worker: EventLoopGroup) async throws -> CouchUpdateResponse {
		guard let id = doc._id else { throw CouchDBClientError.idMissing }
		guard let rev = doc._rev else { throw CouchDBClientError.revMissing }

		return try await delete(fromDb: dbName, uri: id, rev: rev, worker: worker)
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
			.execute(request: request, deadline: .now() + .seconds(requestsTimeout))
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
}
