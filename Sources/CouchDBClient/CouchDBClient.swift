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
	/// Find request wasn't successful.
	case findError(error: CouchDBError)
	/// Uknown response from CouchDB.
	case unknownResponse
	/// Wrong username or password.
	case unauthorized
	/// Missing data in response body.
	case noData
}

extension CouchDBClientError: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .idMissing:
			return "id property is empty or missing in provided document."
		case .revMissing:
			return "_rev property is empty or missing in provided document."
		case .getError(let error):
			return "Get request wasn't successful: \(error.localizedDescription)"
		case .insertError(let error):
			return "Insert request wasn't successful: \(error.localizedDescription)"
		case .updateError(let error):
			return "Update request wasn't successful: \(error.localizedDescription)"
		case .findError(let error):
			return "Find request wasn't successful: \(error.localizedDescription)"
		case .unknownResponse:
			return "Uknown response from CouchDB."
		case .unauthorized:
			return "Wrong username or password."
		case .noData:
			return "Missing data in response body."
		}
	}
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
	internal var sessionCookie: String?
	/// Session cookie as Cookie struct
	internal var sessionCookieExpires: Date?
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
	///  If you don't want to have your password in the code you can pass `COUCHDB_PASS` param in your command line.
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
	///   - couchProtocol: Protocol for requests (check the ``CouchDBProtocol`` enum for available values).
	///   - couchHost: Host of the CouchDB instance.
	///   - couchPort: Port that CouchDB works on.
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
			httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
		}

		defer {
			DispatchQueue.main.async {
				try? httpClient.syncShutdown()
			}
		}

		let url = buildUrl(path: "/_all_dbs")

		let request = try buildRequest(fromUrl: url, withMethod: .GET)
		let response = try await httpClient
			.execute(request, timeout: .seconds(requestsTimeout))

		if response.status == .unauthorized {
			throw CouchDBClientError.unauthorized
		}

		let body = response.body
		let expectedBytes = response.headers.first(name: "content-length").flatMap(Int.init)
		var bytes = try await body.collect(upTo: expectedBytes ?? 1024 * 1024 * 10)

		guard let data = bytes.readData(length: bytes.readableBytes) else {
			throw CouchDBClientError.noData
		}
		return try JSONDecoder().decode([String].self, from: data)
	}

	/// Check if DB exists
	///
	/// Example:
	///
	/// ```swift
	/// let exists = try await couchDBClient.dbExists("myDBName")
	/// ```
	///
	/// - Parameters:
	///   - dbName: DB name.
	///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
	/// - Returns: True or false.
	public func dbExists(_ dbName: String, eventLoopGroup: EventLoopGroup? = nil) async throws -> Bool {
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

		let url = buildUrl(path: "/" + dbName)
		let request = try buildRequest(fromUrl: url, withMethod: .HEAD)
		let response = try await httpClient
			.execute(request, timeout: .seconds(requestsTimeout))

		if response.status == .unauthorized {
			throw CouchDBClientError.unauthorized
		}

		return response.status == .ok
	}

    /// Create DB.
    ///
    ///  Example:
    /// ```swift
    /// try await couchDBClient.deleteDB("myDBName")
    /// ```
    ///
    /// - Parameters:
    ///   - dbName: DB name.
    ///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
    /// - Returns: Request response.
    @discardableResult public func createDB(_ dbName: String, eventLoopGroup: EventLoopGroup? = nil) async throws -> UpdateDBResponse {
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

		let request = try self.buildRequest(fromUrl: url, withMethod: .PUT)

		let response = try await httpClient
			.execute(request, timeout: .seconds(requestsTimeout))

		if response.status == .unauthorized {
			throw CouchDBClientError.unauthorized
		}

		let body = response.body
		let expectedBytes = response.headers.first(name: "content-length").flatMap(Int.init)
		var bytes = try await body.collect(upTo: expectedBytes ?? 1024 * 1024 * 10)

		guard let data = bytes.readData(length: bytes.readableBytes) else {
			throw CouchDBClientError.noData
		}

		let decoder = JSONDecoder()

		do {
			let decodedResponse = try decoder.decode(UpdateDBResponse.self, from: data)
			return decodedResponse
		} catch let parsingError {
			if let couchdbError = try? decoder.decode(CouchDBError.self, from: data) {
				throw CouchDBClientError.insertError(error: couchdbError)
			}
			throw parsingError
		}
	}

	/// Delete DB.
	///
	/// Example:
	/// ```swift
	/// try await couchDBClient.deleteDB("myDBName")
	/// ```
	///
	/// - Parameters:
	///   - dbName: DB name.
	///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
	/// - Returns: Request response.
	@discardableResult public func deleteDB(_ dbName: String, eventLoopGroup: EventLoopGroup? = nil) async throws -> UpdateDBResponse {
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

		let request = try self.buildRequest(fromUrl: url, withMethod: .DELETE)

		let response = try await httpClient
			.execute(request, timeout: .seconds(requestsTimeout))

		if response.status == .unauthorized {
			throw CouchDBClientError.unauthorized
		}

		let body = response.body
		let expectedBytes = response.headers.first(name: "content-length").flatMap(Int.init)
		var bytes = try await body.collect(upTo: expectedBytes ?? 1024 * 1024 * 10)

		guard let data = bytes.readData(length: bytes.readableBytes) else {
			throw CouchDBClientError.noData
		}

		let decoder = JSONDecoder()

		do {
			let decodedResponse = try decoder.decode(UpdateDBResponse.self, from: data)
			return decodedResponse
		} catch let parsingError {
			if let couchdbError = try? decoder.decode(CouchDBError.self, from: data) {
				throw CouchDBClientError.insertError(error: couchdbError)
			}
			throw parsingError
		}
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
	/// var response = try await couchDBClient.get(
	///     dbName: "databaseName",
	///     uri: "documentId"
	/// )
	///
	/// // parse JSON
	/// let expectedBytes = response.headers
	///     .first(name: "content-length")
	///     .flatMap(Int.init) ?? 1024 * 1024 * 10
	/// var bytes = try await response.body.collect(upTo: expectedBytes)
	/// let data = bytes.readData(length: bytes.readableBytes)
	///
	/// let doc = try JSONDecoder().decode(
	///     ExpectedDoc.self,
	///     from: data!
	/// )
	/// ```
	///
	/// You can also provide CouchDB view document as uri and key in query.
	///
	/// Get data and parse RowsResponse:
	/// ```swift
	/// let response = try await couchDBClient.get(
	///     fromDB: "databaseName",
	///     uri: "_design/all/_view/by_url",
	///     query: ["key": "\"\(url)\""]
	/// )
	///
	/// let expectedBytes = response.headers
	///     .first(name: "content-length")
	///     .flatMap(Int.init) ?? 1024 * 1024 * 10
	/// var bytes = try await response.body.collect(upTo: expectedBytes)
	/// let data = bytes.readData(length: bytes.readableBytes)
	///
	/// let decodedResponse = try JSONDecoder().decode(
	///     RowsResponse<ExpectedDoc>.self,
	///     from: data!
	/// )
	///
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
	public func get(fromDB dbName: String, uri: String, queryItems: [URLQueryItem]? = nil, eventLoopGroup: EventLoopGroup? = nil) async throws -> HTTPClientResponse {
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
		let request = try buildRequest(fromUrl: url, withMethod: .GET)
		var response = try await httpClient
			.execute(request, timeout: .seconds(requestsTimeout))

		if response.status == .unauthorized {
			throw CouchDBClientError.unauthorized
		}

		let body = response.body
		let expectedBytes = response.headers.first(name: "content-length").flatMap(Int.init) ?? 1024 * 1024 * 10

		response.body = .bytes(
			try await body.collect(upTo: expectedBytes)
		)

		return response
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
	/// let doc: ExpectedDoc = try await couchDBClient.get(fromDB: "databaseName", uri: "documentId")
	/// ```
	///
	/// - Parameters:
	///   - dbName: DB name.
	///   - uri: URI (view or document id).
	///   - queryItems: Request query items.
	///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
	/// - Returns: An object or a struct (of generic type) parsed from JSON.
	public func get <T: Codable & CouchDBRepresentable>(fromDB dbName: String, uri: String, queryItems: [URLQueryItem]? = nil, dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .secondsSince1970, eventLoopGroup: EventLoopGroup? = nil) async throws -> T {
		let response: HTTPClientResponse = try await get(fromDB: dbName, uri: uri, queryItems: queryItems, eventLoopGroup: eventLoopGroup)

		if response.status == .unauthorized {
			throw CouchDBClientError.unauthorized
		}

		let body = response.body
		let expectedBytes = response.headers.first(name: "content-length").flatMap(Int.init)
		var bytes = try await body.collect(upTo: expectedBytes ?? 1024 * 1024 * 10)

		guard let data = bytes.readData(length: bytes.readableBytes) else {
			throw CouchDBClientError.noData
		}

		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = dateDecodingStrategy

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

    /// Find data in DB by selector.
    ///
    /// Example:
    ///
    /// ```swift
    /// // find documents in DB by selector
	/// let selector = ["selector": ["name": "Sam"]]
    /// let docs: [ExpectedDoc] = try await couchDBClient.find(inDB: testsDB, selector: selector)
    /// ```
    ///
    /// - Parameters:
    ///   - in dbName: DB name.
    ///   - selector: Codable representation of json selector query.
    ///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
    /// - Returns: Array of documents [T].
	public func find<T: Codable & CouchDBRepresentable>(inDB dbName: String, selector: Codable, dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .secondsSince1970, eventLoopGroup: EventLoopGroup? = nil) async throws -> [T] {
		let encoder = JSONEncoder()
		let selectorData = try encoder.encode(selector)
		let requestBody: HTTPClientRequest.Body = .bytes(ByteBuffer(data: selectorData))

		let findResponse = try await find(
			inDB: dbName,
			body: requestBody,
			eventLoopGroup: eventLoopGroup
		)

		let body = findResponse.body
		let expectedBytes = findResponse.headers.first(name: "content-length").flatMap(Int.init)
		var bytes = try await body.collect(upTo: expectedBytes ?? 1024 * 1024 * 10)

		guard let data = bytes.readData(length: bytes.readableBytes) else {
			throw CouchDBClientError.noData
		}

		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = dateDecodingStrategy

		do {
			let doc = try decoder.decode(CouchDBFindResponse<T>.self, from: data)
			return doc.docs
		} catch let parsingError {
			if let couchdbError = try? decoder.decode(CouchDBError.self, from: data) {
				throw CouchDBClientError.findError(error: couchdbError)
			}
			throw parsingError
		}
	}
	
	/// Find data in DB by selector.
	///
	/// Example:
	/// ```swift
	/// let selector = ["selector": ["name": "Greg"]]
	/// let bodyData = try JSONEncoder().encode(selector)
	/// var findResponse = try await couchDBClient.find(inDB: testsDB, body: .data(bodyData))
	///
	/// let bytes = findResponse.body!.readBytes(length: findResponse.body!.readableBytes)!
	/// let docs = try JSONDecoder().decode(CouchDBFindResponse<ExpectedDoc>.self, from: Data(bytes)).docs
	/// ```
	/// - Parameters:
	///   - dbName: DB name.
	///   - body: Request body data.
	///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
	/// - Returns: Request response.
	public func find(inDB dbName: String, body: HTTPClientRequest.Body, eventLoopGroup: EventLoopGroup? = nil) async throws -> HTTPClientResponse {
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
		var request = try buildRequest(fromUrl: url, withMethod: .POST)
		request.body = body
		var response = try await httpClient
			.execute(request, timeout: .seconds(requestsTimeout))

		if response.status == .unauthorized {
			throw CouchDBClientError.unauthorized
		}

		let body = response.body
		let expectedBytes = response.headers.first(name: "content-length").flatMap(Int.init) ?? 1024 * 1024 * 10

		response.body = .bytes(
			try await body.collect(upTo: expectedBytes)
		)

		return response
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
	/// let body: HTTPClientRequest.Body = .bytes(ByteBuffer(data: data))
	///
	/// let response = try await couchDBClient.update(
	///     dbName: testsDB,
	///     uri: doc._id!,
	///     body: body
	/// )
	///
	/// print(response)
	/// ```
	///
	///
	/// - Parameters:
	///   - dbName: DB name.
	///   - uri: URI (view or document id).
	///   - body: Request body data.
	///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
	/// - Returns: Update response.
	public func update(dbName: String, uri: String, body: HTTPClientRequest.Body, eventLoopGroup: EventLoopGroup? = nil) async throws -> CouchUpdateResponse {
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

		let url = buildUrl(path: "/" + dbName + "/" + uri)
		var request = try buildRequest(fromUrl: url, withMethod: .PUT)
		request.body = body

		let response = try await httpClient
			.execute(request, timeout: .seconds(requestsTimeout))

		if response.status == .unauthorized {
			throw CouchDBClientError.unauthorized
		}

		let body = response.body
		let expectedBytes = response.headers.first(name: "content-length").flatMap(Int.init)
		var bytes = try await body.collect(upTo: expectedBytes ?? 1024 * 1024 * 10)

		guard let data = bytes.readData(length: bytes.readableBytes) else {
			throw CouchDBClientError.noData
		}

		let decoder = JSONDecoder()

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
	public func update <T: Codable & CouchDBRepresentable>(dbName: String, doc: inout T, dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .secondsSince1970, eventLoopGroup: EventLoopGroup? = nil ) async throws {
		guard let id = doc._id else { throw CouchDBClientError.idMissing }
		guard doc._rev?.isEmpty == false else { throw CouchDBClientError.revMissing }

		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = dateEncodingStrategy
		let encodedData = try encoder.encode(doc)

		let body: HTTPClientRequest.Body = .bytes(ByteBuffer(data: encodedData))

		let updateResponse = try await update(
			dbName: dbName,
			uri: id,
			body: body,
			eventLoopGroup: eventLoopGroup
		)

		guard updateResponse.ok == true else {
			throw CouchDBClientError.unknownResponse
		}

		doc._rev = updateResponse.rev
		doc._id = updateResponse.id
	}

	/// Insert data in DB. Accepts HTTPClientRequest.Body as body parameter.
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
	/// let body: HTTPClientRequest.Body = .bytes(ByteBuffer(data: insertEncodeData))
	///
	/// let response = try await couchDBClient.insert(
	///     dbName: "databaseName",
	///     body: body
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
	public func insert(dbName: String, body: HTTPClientRequest.Body, eventLoopGroup: EventLoopGroup? = nil) async throws -> CouchUpdateResponse {
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
			.execute(request, timeout: .seconds(requestsTimeout))

		if response.status == .unauthorized {
			throw CouchDBClientError.unauthorized
		}

		let body = response.body
		let expectedBytes = response.headers.first(name: "content-length").flatMap(Int.init)
		var bytes = try await body.collect(upTo: expectedBytes ?? 1024 * 1024 * 10)

		guard let data = bytes.readData(length: bytes.readableBytes) else {
			throw CouchDBClientError.noData
		}

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
	public func insert <T: Codable & CouchDBRepresentable>(dbName: String, doc: inout T, dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .secondsSince1970, eventLoopGroup: EventLoopGroup? = nil ) async throws {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = dateEncodingStrategy
		let insertEncodeData = try encoder.encode(doc)

		let body: HTTPClientRequest.Body = .bytes(ByteBuffer(data: insertEncodeData))

		let insertResponse = try await insert(
			dbName: dbName,
			body: body,
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
	/// let response = try await couchDBClient.delete(fromDb: "databaseName", uri: doc._id, rev: doc._rev)
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
			httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
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
			.execute(request, timeout: .seconds(requestsTimeout))

		if response.status == .unauthorized {
			throw CouchDBClientError.unauthorized
		}

		let body = response.body
		let expectedBytes = response.headers.first(name: "content-length").flatMap(Int.init)
		var bytes = try await body.collect(upTo: expectedBytes ?? 1024 * 1024 * 10)

		guard let data = bytes.readData(length: bytes.readableBytes) else {
			return CouchUpdateResponse(ok: false, id: "", rev: "")
		}

		return try JSONDecoder().decode(CouchUpdateResponse.self, from: data)
	}

	/// Delete document from DB.
	///
	/// Examples:
	///
	/// ```swift
	/// let response = try await couchDBClient.delete(fromDb: "databaseName", doc: doc)
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
		if let authData = authData, let sessionCookieExpires = sessionCookieExpires, sessionCookieExpires > Date() {
			return authData
		}

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

		let url = buildUrl(path: "/_session")

		var request = HTTPClientRequest(url: url)
		request.method = .POST
		request.headers.add(name: "Content-Type", value: "application/x-www-form-urlencoded")
		let dataString = "name=\(userName)&password=\(userPassword)"
		request.body = .bytes(ByteBuffer(string: dataString))

		let response = try await httpClient
			.execute(request, timeout: .seconds(requestsTimeout))

		if response.status == .unauthorized {
			throw CouchDBClientError.unauthorized
		}

		var cookie = ""
		response.headers.forEach { (header: (name: String, value: String)) in
			if header.name.lowercased() == "set-cookie" {
				cookie = header.value
			}
		}

		if let httpCookie = HTTPClient.Cookie(header: cookie, defaultDomain: self.couchHost) {
			if httpCookie.expires == nil {
				let formatter = DateFormatter()
				formatter.dateFormat = "E, dd-MMM-yyy HH:mm:ss z"

				let expiresString = cookie.split(separator: ";")
					.map({ $0.trimmingCharacters(in: .whitespaces) })
					.first(where: { $0.hasPrefix("Expires=") })?
					.split(separator: "=").last

				if let expiresString = expiresString {
					let expires = formatter.date(from: String(expiresString))
					sessionCookieExpires = expires
				}
			} else {
				sessionCookieExpires = httpCookie.expires
			}
		}

		sessionCookie = cookie

		let body = response.body
		let expectedBytes = response.headers.first(name: "content-length").flatMap(Int.init)
		var bytes = try await body.collect(upTo: expectedBytes ?? 1024 * 1024 * 10)

		guard let data = bytes.readData(length: bytes.readableBytes) else {
			throw CouchDBClientError.noData
		}

		authData = try JSONDecoder().decode(CreateSessionResponse.self, from: data)
		return authData
	}

	func buildRequest(fromUrl url: String, withMethod method: HTTPMethod) throws -> HTTPClientRequest  {
		var headers = HTTPHeaders()
		headers.add(name: "Content-Type", value: "application/json")
		if let cookie = sessionCookie {
			headers.add(name: "Cookie", value: cookie)
		}

		var request = HTTPClientRequest(url: url)
		request.method = method
		request.headers = headers
		return request
	}
}
