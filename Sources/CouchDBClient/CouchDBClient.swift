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

/// CouchDB client errors.
public enum CouchDBClientError: Error {
	/// **id** property is empty or missing in provided document.
	case idMissing
	/// **\_rev** property is empty or missing in provided document.
	case revMissing
	/// Get request wasn't successful.
	case getError(error: CouchDBError)
	/// Insert request wasn't successful.
	case insertError(error: CouchDBError)
	/// Update request wasn't successful.
	case updateError(error: CouchDBError)
	/// Uknown response from CouchDB.
	case unknownResponse
}

/// A CouchDB client class with methods using Swift Concurrency.
public class CouchDBClient {
	/// Protocol (URL scheme) that should be used to perform requests to CouchDB.
	public enum CouchDBProtocol: String {
		/// Use HTTP protocol.
		case http
		/// Use HTTPS protocol.
		case https
	}
	
	// MARK: - Public properties
	
	/// Flag if did authorize in CouchDB.
	public var isAuthorized: Bool { authData?.ok ?? false }

	/// You can set timeout for requests in seconds. Default value is 30.
	public var requestsTimeout: Int64 = 30
	
	// MARK: - Private properties
	/// Requests protocol.
	private var couchProtocol: CouchDBProtocol = .http
	/// Host.
	private var couchHost: String = "127.0.0.1"
	/// Port.
	private var couchPort: Int = 5984
	/// Base URL.
	private var couchBaseURL: String = ""
	/// Session cookie for requests that needs authorization.
	private var sessionCookie: String?
	/// CouchDB user name.
	private var userName: String = ""
	/// CouchDB user password.
	private var userPassword: String = ""
	/// Authorization response from CouchDB.
	private var authData: CreateSessionResponse?


	// MARK: - Initializer

	/// Initialize CouchDB with connection params and credentials.
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
	///   - couchProtocol: Protocol for requests (check ``CouchDBProtocol`` enum for avaiable values).
	///   - couchHost: Host of CouchDB instance.
	///   - couchPort: Port CouchDB works on.
	///   - userName: Username.
	///   - userPassword: User password.
	public init(couchProtocol: CouchDBProtocol = .http, couchHost: String = "127.0.0.1", couchPort: Int = 5984, userName: String = "", userPassword: String = "") {
		self.couchProtocol = couchProtocol
		self.couchHost = couchHost
		self.couchPort = couchPort
		self.userName = userName

		self.userPassword = userPassword.isEmpty
		? ProcessInfo.processInfo.environment["COUCHDB_PASS"] ?? userPassword
		: userPassword
	}
	
	
	// MARK: - Public methods

	/// Get DBs list.
	///
	/// Example:
	/// ```swift
	/// let dbs = try await couchDBClient.getAllDBs()
	/// ```
	///
	/// - Parameter eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
	/// - Returns: Array of strings containing DBs names.
	public func getAllDBs(eventLoopGroup: EventLoopGroup? = nil) async throws -> [String] {
		try await authIfNeed(eventLoopGroup: eventLoopGroup)

        let httpClient: HTTPClient
        if let eventLoopGroup = eventLoopGroup {
            httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
        } else {
            httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
        }

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

		guard var body = response.body, let bytes = body.readBytes(length: body.readableBytes) else {
			throw CouchDBClientError.unknownResponse
		}

		let data = Data(bytes)
		return try JSONDecoder().decode([String].self, from: data)
	}

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
	/// Define Row and RowsResponse models:
	/// ```swift
	/// struct Row: Codable {
	///     let value: ExpectedDoc
	/// }
	///
	/// struct RowsResponse: Codable {
	///     let total_rows: Int
	///     let offset: Int
	///     let rows: [Row]
	/// }
	/// ```
	///
	/// Get data and parse RowsResponse:
	/// ```swift
	/// let response = try await couchDBClient.get(
	///     dbName: "databaseName",
	///     uri: "_design/all/_view/by_url",
	///     query: ["key": "\"\(url)\""]
	/// )
	/// let bytes = response.body!.readBytes(length: response.body!.readableBytes)!
	/// let decodedResponse = try JSONDecoder().decode(RowsResponse.self, from: data)
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
	public func get(dbName: String, uri: String, queryItems: [URLQueryItem]? = nil, eventLoopGroup: EventLoopGroup? = nil) async throws -> HTTPClient.Response {
		try await authIfNeed(eventLoopGroup: eventLoopGroup)

		let httpClient: HTTPClient
		if let eventLoopGroup = eventLoopGroup {
			httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
		} else {
			httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
		}

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


	/// Get a document from DB. It will parse JSON using provided generic type. Check an example in Discussion.
	///
	/// Example:
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
	/// let doc: ExpectedDoc = try await couchDBClient.get(dbName: "databaseName", uri: "documentId")
	/// ```
	///
	/// - Parameters:
	///   - dbName: DB name.
	///   - uri: URI (view or document id).
	///   - queryItems: Request query items.
	///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
	/// - Returns: An object or a struct (of generic type) parsed from JSON.
	public func get <T: Codable & CouchDBRepresentable>(dbName: String, uri: String, queryItems: [URLQueryItem]? = nil, eventLoopGroup: EventLoopGroup? = nil) async throws -> T {
		let response = try await get(dbName: dbName, uri: uri, queryItems: queryItems, eventLoopGroup: eventLoopGroup)

		guard var body = response.body, let bytes = body.readBytes(length: body.readableBytes) else {
			throw CouchDBClientError.unknownResponse
		}

		let data = Data(bytes)
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .secondsSince1970

		do {
			let doc = try decoder.decode(T.self, from: data)
			return doc
		} catch let parsingError {
			if let couchdbError = try? decoder.decode(CouchDBError.self, from: data) {
				throw CouchDBClientError.getError(error: couchdbError)
			}
			throw parsingError
		}
	}

	/// Update data in DB.
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
	/// Get document by ID and update it:
	/// ```swift
	/// // get data from DB by document ID
	/// var response = try await couchDBClient.get(dbName: "databaseName", uri: "documentId")
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
	///     dbName: testsDB,
	///     uri: doc._id!,
	///     body: .data(data)
	/// )
	///
	/// print(response)
	/// ```
	///
	///
	/// - Parameters:
	///   - dbName: DB name.
	///   - uri: URI (view or document id).
	///   - body: Request body data. New will be created if nil value provided.
	///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
	/// - Returns: Update response.
	public func update(dbName: String, uri: String, body: HTTPClient.Body, eventLoopGroup: EventLoopGroup? = nil) async throws -> CouchUpdateResponse {
		try await authIfNeed(eventLoopGroup: eventLoopGroup)

		let httpClient: HTTPClient
		if let eventLoopGroup = eventLoopGroup {
			httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
		} else {
			httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
		}
		
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
			throw CouchDBClientError.unknownResponse
		}

		let data = Data(bytes)
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .secondsSince1970

		do {
			let decodedResponse = try decoder.decode(CouchUpdateResponse.self, from: data)
			return decodedResponse
		} catch let parsingError {
			if let couchdbError = try? decoder.decode(CouchDBError.self, from: data) {
				throw CouchDBClientError.updateError(error: couchdbError)
			}
			throw parsingError
		}
	}

	/// Update document in DB. That method will mutate `doc` to update it's `_rev` with the value from CouchDB response.
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
	/// Get document by ID and update it:
	/// ```swift
	/// // get data from DB by document ID
	/// var doc: ExpectedDoc = try await couchDBClient.get(dbName: "databaseName", uri: "documentId")
	/// print(doc)
	///
	/// // Update value
	/// doc.name = "Updated name"
	///
	/// try await couchDBClient.update(
	///     dbName: testsDB,
	///     doc: &doc
	/// )
	///
	/// print(doc) // doc will have updated name and _rev values now
	/// ```
	///
	/// - Parameters:
	///   - dbName: DB name. That method will mutate `doc` to update it's `_id` and `_rev` properties from insert request.
	///   - doc: Document object/struct. Should confirm to ``CouchDBRepresentable`` and Codable protocols.
	///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
	/// - Returns: Update response.
	public func update <T: Codable & CouchDBRepresentable>(dbName: String, doc: inout T, eventLoopGroup: EventLoopGroup? = nil ) async throws {
		guard let id = doc._id else { throw CouchDBClientError.idMissing }
		guard doc._rev?.isEmpty == false else { throw CouchDBClientError.revMissing }

		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .secondsSince1970
		let encodedData = try JSONEncoder().encode(doc)

		let updateResponse = try await update(
			dbName: dbName,
			uri: id,
			body: .data(encodedData),
			eventLoopGroup: eventLoopGroup
		)

		guard updateResponse.ok == true else {
			throw CouchDBClientError.unknownResponse
		}

		doc._rev = updateResponse.rev
		doc._id = updateResponse.id
	}

	/// Insert data in DB.
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
	public func insert(dbName: String, body: HTTPClient.Body, eventLoopGroup: EventLoopGroup? = nil) async throws -> CouchUpdateResponse {
		try await authIfNeed(eventLoopGroup: eventLoopGroup)

		let httpClient: HTTPClient
		if let eventLoopGroup = eventLoopGroup {
			httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
		} else {
			httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
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
		
		guard var body = response.body, let bytes = body.readBytes(length: body.readableBytes) else {
			throw CouchDBClientError.unknownResponse
		}

		let data = Data(bytes)
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .secondsSince1970

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

	/// Insert document in DB. That method will mutate `doc` to update it's `_id` and `_rev` with the values from CouchDB response.
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
	/// var testDoc = ExpectedDoc(name: "My name")
	///
	/// try await couchDBClient.insert(
	///     dbName: "databaseName",
	///     doc: &testDoc
	/// )
	///
	/// print(testDoc) // testDoc has _id and _rev values now
	/// ```
	///
	/// - Parameters:
	///   - dbName: DB name.
	///   - doc: Document object/struct. Should confirm to ``CouchDBRepresentable`` protocol.
	///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
	public func insert <T: Codable & CouchDBRepresentable>(dbName: String, doc: inout T, eventLoopGroup: EventLoopGroup? = nil ) async throws {
		let insertEncodeData = try JSONEncoder().encode(doc)
		let insertResponse = try await insert(
			dbName: dbName,
			body: .data(insertEncodeData),
			eventLoopGroup: eventLoopGroup
		)

		guard insertResponse.ok == true else {
			throw CouchDBClientError.unknownResponse
		}

		doc._rev = insertResponse.rev
		doc._id = insertResponse.id
	}

	/// Delete document from DB by URI.
	///
	/// Examples:
	///
	/// ```swift
	/// let response = try await couchDBClient.delete(fromDb: "databaseName", uri: doc._id,rev: doc._rev)
	/// ```
	/// 
	/// - Parameters:
	///   - dbName: DB name.
	///   - uri: document uri (usually _id).
	///   - rev: document revision.
	///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
	/// - Returns: Delete request response.
	public func delete(fromDb dbName: String, uri: String, rev: String, eventLoopGroup: EventLoopGroup? = nil) async throws -> CouchUpdateResponse {
		let httpClient: HTTPClient
		if let eventLoopGroup = eventLoopGroup {
			httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
		} else {
			httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
		}

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

	/// Delete document from DB.
	///
	/// Examples:
	///
	/// ```swift
	/// let response = try await couchDBClient.delete(fromDb: "databaseName",doc: doc)
	/// ```
	///
	/// - Parameters:
	///   - dbName: DB name.
	///   - doc: Document object/struct. Should confirm to ``CouchDBRepresentable`` protocol.
	///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
	/// - Returns: Delete request response.
	public func delete(fromDb dbName: String, doc: CouchDBRepresentable, eventLoopGroup: EventLoopGroup? = nil) async throws -> CouchUpdateResponse {
		guard let id = doc._id else { throw CouchDBClientError.idMissing }
		guard let rev = doc._rev else { throw CouchDBClientError.revMissing }

		return try await delete(fromDb: dbName, uri: id, rev: rev, eventLoopGroup: eventLoopGroup)
	}
}


// MARK: - Private methods
internal extension CouchDBClient {
	/// Build URL string.
	/// - Parameters:
	///   - path: Path.
	///   - query: URL query.
	/// - Returns: URL string.
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

	/// Get authorization cookie in didn't yet. This cookie will be added automatically to requests that require authorization.
	/// API reference: https://docs.couchdb.org/en/stable/api/server/authn.html#session
	/// - Parameter eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
	/// - Returns: Authorization response.
	@discardableResult
	func authIfNeed(eventLoopGroup: EventLoopGroup? = nil) async throws -> CreateSessionResponse? {
		// already authorized
		if let authData = authData {
			return authData
		}
		
        let httpClient: HTTPClient
        if let eventLoopGroup = eventLoopGroup {
            httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
        } else {
            httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
        }
		
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
	
	/// Build HTTP request from url string.
	/// - Parameters:
	///   - url: URL string.
	///   - method: HTTP method.
	/// - Returns: HTTP Request.
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
