//
//  couchdb_vapor.swift
//  couchdb-vapor
//
//  Created by Sergey Armodin on 06/03/2019.
//

import Foundation
import NIO
import NIOHTTP1
import NIOFoundationCompat
import AsyncHTTPClient

/// CouchDB client errors.
public enum CouchDBClientError: Error {
	/// **id** property is empty or missing in the provided document.
	case idMissing
	/// **\_rev** property is empty or missing in the provided document.
	case revMissing
	/// The Get request wasn't successful.
	case getError(error: CouchDBError)
	/// The Insert request wasn't successful.
	case insertError(error: CouchDBError)
	/// The Update request wasn't successful.
	case updateError(error: CouchDBError)
	/// The Find request wasn't successful.
	case findError(error: CouchDBError)
	/// Unknown response from CouchDB.
	case unknownResponse
	/// Wrong username or password.
	case unauthorized
	/// Missing data in the response body.
	case noData
}

extension CouchDBClientError: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .idMissing:
			return "id property is empty or missing in the provided document."
		case .revMissing:
			return "_rev property is empty or missing in the provided document."
		case .getError(let error):
			return "The Get request wasn't successful: \(error.localizedDescription)"
		case .insertError(let error):
			return "The Insert request wasn't successful: \(error.localizedDescription)"
		case .updateError(let error):
			return "The Update request wasn't successful: \(error.localizedDescription)"
		case .findError(let error):
			return "The Find request wasn't successful: \(error.localizedDescription)"
		case .unknownResponse:
			return "Unknown response from CouchDB."
		case .unauthorized:
			return "Wrong username or password."
		case .noData:
			return "Missing data in the response body."
		}
	}
}

/// A CouchDB client class with methods using Swift Concurrency.
public class CouchDBClient {
	/// An enumeration that defines the protocol types supported for connecting to a CouchDB server.
	///
	/// - Cases:
	///   - http: Represents the HTTP protocol for unencrypted network communication.
	///   - https: Represents the HTTPS protocol for secure, encrypted network communication.
	///
	/// - Note: Always prefer using `https` for secure communication, especially when transmitting sensitive data.
	public enum CouchDBProtocol: String {
		case http
		case https
	}
	
	// MARK: - Public properties
	
	/// Flag if authorized in CouchDB.
	public var isAuthorized: Bool { authData?.ok ?? false }

	/// You can set a timeout for requests in seconds. Default value is 30.
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
	/// Session cookie for requests that need authorization.
	internal var sessionCookie: String?
	/// Session cookie as Cookie struct.
	internal var sessionCookieExpires: Date?
	/// CouchDB user name.
	private var userName: String = ""
	/// CouchDB user password.
	private var userPassword: String = ""
	/// Authorization response from CouchDB.
	private var authData: CreateSessionResponse?


	// MARK: - Initializer

	/// Initializes a new instance of a CouchDB client.
	///
	/// This initializer sets up the client with default values for connecting to a CouchDB server. It allows for optional customization of the connection parameters such as protocol, host, port, and user credentials.
	///
	/// - Parameters:
	///   - couchProtocol: The protocol used for connecting to the CouchDB server. Defaults to `.http`.
	///   - couchHost: The hostname or IP address of the CouchDB server. Defaults to `"127.0.0.1"`.
	///   - couchPort: The port number on which the CouchDB server is listening. Defaults to `5984`.
	///   - userName: The username for authentication with the CouchDB server.
	///   - userPassword: The password for authentication with the CouchDB server. If left empty, the initializer attempts to read the password from the `COUCHDB_PASS` environment variable. If the environment variable is also not set, it defaults to an empty string.
	///
	///	Example usage:
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
	/// - Note: It's important to ensure that the CouchDB server is running and accessible at the specified `couchHost` and `couchPort` before attempting to connect.
	public init(couchProtocol: CouchDBProtocol = .http, couchHost: String = "127.0.0.1", couchPort: Int = 5984, userName: String, userPassword: String = "") {
		self.couchProtocol = couchProtocol
		self.couchHost = couchHost
		self.couchPort = couchPort
		self.userName = userName

		self.userPassword = userPassword.isEmpty
		? ProcessInfo.processInfo.environment["COUCHDB_PASS"] ?? userPassword
		: userPassword
	}
	
	
	// MARK: - Public methods

	/// Retrieves a list of all database names from the CouchDB server.
	///
	/// This asynchronous function sends a GET request to the CouchDB server to fetch the names of all databases. It can optionally use a custom NIO's `EventLoopGroup` for the network request.
	///
	/// - Parameter eventLoopGroup: An optional `EventLoopGroup` that the function will use for its network operations. If not provided, the function uses a shared `HTTPClient`.
	/// - Returns: An array of `String` containing the names of all databases on the server.
	/// - Throws: An error of type `CouchDBClientError` if the request fails or if there is no data returned.
	///
	/// The function first authenticates with the server if needed. It then creates an `HTTPClient` instance, either shared or using the provided `EventLoopGroup`. After building the URL and request, it executes the request and processes the response.
	///
	/// If the response status is `.unauthorized`, it throws an `unauthorized` error. It collects the response body up to a specified byte limit or the `content-length` header's value. Finally, it decodes the response data into an array of strings representing the database names.
	///
	/// Example usage:
	/// ```
	/// let dbNames = try await couchDBClient.getAllDBs()
	/// ```
	///
	/// - Note: Ensure that the CouchDB server is running and accessible. Handle any thrown errors appropriately, especially when dealing with authentication issues.
	public func getAllDBs(eventLoopGroup: EventLoopGroup? = nil) async throws -> [String] {
		try await authIfNeed(eventLoopGroup: eventLoopGroup)

		let httpClient: HTTPClient
		if let eventLoopGroup = eventLoopGroup {
			httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
		} else {
			httpClient = HTTPClient.shared
		}

		defer {
			if eventLoopGroup != nil {
				DispatchQueue.main.async {
					try? httpClient.syncShutdown()
				}
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

	/// Checks if a database exists on the CouchDB server.
	///
	/// This asynchronous function sends a HEAD request to the CouchDB server to determine the existence of a specified database. It can optionally use a custom NIO's `EventLoopGroup` for the network request.
	///
	/// - Parameters:
	///   - dbName: The name of the database to check for existence.
	///   - eventLoopGroup: An optional `EventLoopGroup` that the function will use for its network operations. If not provided, the function uses a shared `HTTPClient`.
	/// - Returns: A `Bool` indicating whether the database exists (`true`) or not (`false`).
	/// - Throws: An error of type `CouchDBClientError` if the request fails, specifically an `unauthorized` error if the response status is `.unauthorized`.
	///
	/// The function first authenticates with the server if needed. It then creates an `HTTPClient` instance, either shared or using the provided `EventLoopGroup`. After building the URL and request for the database, it executes the request and checks the response status.
	///
	/// Example usage:
	/// ```
	/// let doesExist = try await couchDBClient.dbExists("myDatabase")
	/// ```
	///
	/// - Note: Ensure that the CouchDB server is running and accessible. Handle any thrown errors appropriately, especially when dealing with authentication issues.
	public func dbExists(_ dbName: String, eventLoopGroup: EventLoopGroup? = nil) async throws -> Bool {
		try await authIfNeed(eventLoopGroup: eventLoopGroup)

		let httpClient: HTTPClient
		if let eventLoopGroup = eventLoopGroup {
			httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
		} else {
			httpClient = HTTPClient.shared
		}

		defer {
			if eventLoopGroup != nil {
				DispatchQueue.main.async {
					try? httpClient.syncShutdown()
				}
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

	/// Creates a new database on the CouchDB server.
	///
	/// This asynchronous function sends a PUT request to the CouchDB server to create a new database with the specified name. It can optionally use a custom `EventLoopGroup` for the network request.
	///
	/// - Parameters:
	///   - dbName: The name of the database to be created.
	///   - eventLoopGroup: An optional `EventLoopGroup` that the function will use for its network operations. If not provided, the function uses a shared `HTTPClient`.
	/// - Returns: An `UpdateDBResponse` object containing the result of the database creation operation.
	/// - Throws: An error of type `CouchDBClientError` if the request fails, specifically an `unauthorized` error if the response status is `.unauthorized`, or a `noData` error if there is no response data.
	///
	/// The function first authenticates with the server if needed. It then creates an `HTTPClient` instance, either shared or using the provided `EventLoopGroup`. After building the URL and request for the database, it executes the request and processes the response.
	///
	/// If the response status is `.unauthorized`, it throws an `unauthorized` error. It collects the response body up to a specified byte limit or the `content-length` header's value. It then decodes the response data into an `UpdateDBResponse` object.
	///
	/// If the decoding fails, it attempts to decode a `CouchDBError` object and throws an `insertError` with the decoded error. If this also fails, it throws the original parsing error.
	///
	/// Example usage:
	/// ```
	/// let creationResult = try await couchDBClient.createDB("newDatabase")
	/// ```
	///
	/// - Note: Ensure that the CouchDB server is running and accessible. Handle any thrown errors appropriately, especially when dealing with authentication issues and potential conflicts if the database already exists.
    @discardableResult public func createDB(_ dbName: String, eventLoopGroup: EventLoopGroup? = nil) async throws -> UpdateDBResponse {
		try await authIfNeed(eventLoopGroup: eventLoopGroup)

		let httpClient: HTTPClient
		if let eventLoopGroup = eventLoopGroup {
			httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
		} else {
			httpClient = HTTPClient.shared
		}

		defer {
			if eventLoopGroup != nil {
				DispatchQueue.main.async {
					try? httpClient.syncShutdown()
				}
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

	/// Deletes a database from the CouchDB server.
	///
	/// This asynchronous function sends a DELETE request to the CouchDB server to remove a database with the specified name. It can optionally use a custom `EventLoopGroup` for the network request.
	///
	/// - Parameters:
	///   - dbName: The name of the database to be deleted.
	///   - eventLoopGroup: An optional `EventLoopGroup` that the function will use for its network operations. If not provided, the function uses a shared `HTTPClient`.
	/// - Returns: An `UpdateDBResponse` object containing the result of the database deletion operation.
	/// - Throws: An error of type `CouchDBClientError` if the request fails, specifically an `unauthorized` error if the response status is `.unauthorized`, or a `noData` error if there is no response data.
	///
	/// The function first authenticates with the server if needed. It then creates an `HTTPClient` instance, either shared or using the provided `EventLoopGroup`. After building the URL and request for the database, it executes the request and processes the response.
	///
	/// If the response status is `.unauthorized`, it throws an `unauthorized` error. It collects the response body up to a specified byte limit or the `content-length` header's value. It then decodes the response data into an `UpdateDBResponse` object.
	///
	/// If the decoding fails, it attempts to decode a `CouchDBError` object and throws an `insertError` with the decoded error. If this also fails, it throws the original parsing error.
	///
	/// Example usage:
	/// ```
	/// let deletionResult = try await couchDBClient.deleteDB("obsoleteDatabase")
	/// ```
	///
	/// - Note: Ensure that the CouchDB server is running and accessible. Handle any thrown errors appropriately, especially when dealing with authentication issues and potential conflicts if the database does not exist.
	@discardableResult public func deleteDB(_ dbName: String, eventLoopGroup: EventLoopGroup? = nil) async throws -> UpdateDBResponse {
		try await authIfNeed(eventLoopGroup: eventLoopGroup)

		let httpClient: HTTPClient
		if let eventLoopGroup = eventLoopGroup {
			httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
		} else {
			httpClient = HTTPClient.shared
		}

		defer {
			if eventLoopGroup != nil {
				DispatchQueue.main.async {
					try? httpClient.syncShutdown()
				}
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

	/// Get data from a database.
	///
	/// Examples:
	///
	/// Define your document data model:
	/// ```swift
	/// // Example struct
	/// struct ExpectedDoc: CouchDBRepresentable {
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
	///     fromDB: "databaseName",
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
	/// You can also provide a CouchDB view document as uri and key in the query.
	///
	/// Get data and parse `RowsResponse`:
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
	///   - dbName: Database name.
	///   - uri: URI (view or document id).
	///   - query: Request query items.
	///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
	/// - Returns: Response.
	public func get(fromDB dbName: String, uri: String, queryItems: [URLQueryItem]? = nil, eventLoopGroup: EventLoopGroup? = nil) async throws -> HTTPClientResponse {
		try await authIfNeed(eventLoopGroup: eventLoopGroup)

		let httpClient: HTTPClient
		if let eventLoopGroup = eventLoopGroup {
			httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
		} else {
			httpClient = HTTPClient.shared
		}

		defer {
			if eventLoopGroup != nil {
				DispatchQueue.main.async {
					try? httpClient.syncShutdown()
				}
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

	/// Get a document from a database. It will parse JSON using the provided generic type. Check an example in Discussion.
	///
	/// Example:
	///
	/// Define your document model:
	/// ```swift
	/// // Example struct
	/// struct ExpectedDoc: CouchDBRepresentable {
	///     var name: String
	///     var _id: String?
	///     var _rev: String?
	/// }
	/// ```
	///
	/// Get document by ID:
	/// ```swift
	/// // get data from the database by document ID
	/// let doc: ExpectedDoc = try await couchDBClient.get(fromDB: "databaseName", uri: "documentId")
	/// ```
	///
	/// - Parameters:
	///   - dbName: Database name.
	///   - uri: URI (view or document id).
	///   - queryItems: Request query items.
	///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
	/// - Returns: An object or a struct (of generic type) parsed from JSON.
	public func get <T: CouchDBRepresentable>(fromDB dbName: String, uri: String, queryItems: [URLQueryItem]? = nil, dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .secondsSince1970, eventLoopGroup: EventLoopGroup? = nil) async throws -> T {
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

    /// Find data in a database by selector.
    ///
    /// Example:
    ///
    /// ```swift
    /// // find documents in the database by selector
	/// let selector = ["selector": ["name": "Sam"]]
    /// let docs: [ExpectedDoc] = try await couchDBClient.find(inDB: testsDB, selector: selector)
    /// ```
    ///
    /// - Parameters:
    ///   - in dbName: Database name.
    ///   - selector: Codable representation of the JSON selector query.
    ///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
    /// - Returns: Array of `[T]` documents.
	public func find<T: CouchDBRepresentable>(inDB dbName: String, selector: Codable, dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .secondsSince1970, eventLoopGroup: EventLoopGroup? = nil) async throws -> [T] {
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
	
	/// Find data in a database by selector.
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
	///   - dbName: Database name.
	///   - body: Request body data.
	///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
	/// - Returns: Response.
	public func find(inDB dbName: String, body: HTTPClientRequest.Body, eventLoopGroup: EventLoopGroup? = nil) async throws -> HTTPClientResponse {
		try await authIfNeed(eventLoopGroup: eventLoopGroup)

		let httpClient: HTTPClient
		if let eventLoopGroup = eventLoopGroup {
			httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
		} else {
			httpClient = HTTPClient.shared
		}

		defer {
			if eventLoopGroup != nil {
				DispatchQueue.main.async {
					try? httpClient.syncShutdown()
				}
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

	/// Update data in a database.
	///
	/// Examples:
	///
	/// Define your document model:
	/// ```swift
	/// // Example struct
	/// struct ExpectedDoc: CouchDBRepresentable {
	///     var name: String
	///     var _id: String?
	///     var _rev: String?
	/// }
	/// ```
	/// Get document by ID and update it:
	/// ```swift
	/// // get data from the database by document ID
	/// var response = try await couchDBClient.get(fromDB: "databaseName", uri: "documentId")
	///
	/// // parse JSON
	/// let bytes = response.body!.readBytes(length: response.body!.readableBytes)!
	/// var doc = try JSONDecoder().decode(ExpectedDoc.self, from: Data(bytes))
	///
	/// // update some value
	/// doc.name = "Updated name"
	///
	/// // encode document into a JSON string
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
	///   - dbName: Database name.
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
			httpClient = HTTPClient.shared
		}
		
		defer {
			if eventLoopGroup != nil {
				DispatchQueue.main.async {
					try? httpClient.syncShutdown()
				}
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

	/// Update document in a database. That method will mutate `doc` to update its `_rev` with the value from CouchDB response.
	///
	/// Examples:
	///
	/// Define your document model:
	/// ```swift
	/// // Example struct
	/// struct ExpectedDoc: CouchDBRepresentable {
	///     var name: String
	///     var _id: String?
	///     var _rev: String?
	/// }
	/// ```
	/// Get a document by ID and update it:
	/// ```swift
	/// // get data from the database by document ID
	/// var doc: ExpectedDoc = try await couchDBClient.get(fromDB: "databaseName", uri: "documentId")
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
	///   - dbName: Database name. That method will mutate `doc` to update its `_id` and `_rev` properties from insert request.
	///   - doc: Document object/struct. Should conform to the ``CouchDBRepresentable`` protocol.
	///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
	/// - Returns: Update response.
	public func update <T: CouchDBRepresentable>(dbName: String, doc: inout T, dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .secondsSince1970, eventLoopGroup: EventLoopGroup? = nil ) async throws {
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

	/// Insert data in a database. Accepts `HTTPClientRequest.Body` as body parameter.
	///
	/// Examples:
	///
	/// Define your document model:
	/// ```swift
	/// // Example struct
	/// struct ExpectedDoc: CouchDBRepresentable {
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
	///   - dbName: Database name.
	///   - body: Request body data.
	///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
	/// - Returns: Insertion response.
	public func insert(dbName: String, body: HTTPClientRequest.Body, eventLoopGroup: EventLoopGroup? = nil) async throws -> CouchUpdateResponse {
		try await authIfNeed(eventLoopGroup: eventLoopGroup)

		let httpClient: HTTPClient
		if let eventLoopGroup = eventLoopGroup {
			httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
		} else {
			httpClient = HTTPClient.shared
		}

		defer {
			if eventLoopGroup != nil {
				DispatchQueue.main.async {
					try? httpClient.syncShutdown()
				}
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

	/// Insert document in a database. That method will mutate `doc` to update its `_id` and `_rev` with the values from CouchDB response.
	///
	/// Examples:
	///
	/// Define your document model:
	/// ```swift
	/// // Example struct
	/// struct ExpectedDoc: CouchDBRepresentable {
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
	///   - dbName: Database name.
	///   - doc: Document object/struct. Should conform to the ``CouchDBRepresentable`` protocol.
	///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
	public func insert <T: CouchDBRepresentable>(dbName: String, doc: inout T, dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .secondsSince1970, eventLoopGroup: EventLoopGroup? = nil ) async throws {
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

	/// Delete a document from a database by URI.
	///
	/// Examples:
	///
	/// ```swift
	/// let response = try await couchDBClient.delete(fromDb: "databaseName", uri: doc._id, rev: doc._rev)
	/// ```
	///
	/// - Parameters:
	///   - dbName: Database name.
	///   - uri: document uri (usually _id).
	///   - rev: document revision.
	///   - eventLoopGroup: NIO's EventLoopGroup object. New will be created if nil value provided.
	/// - Returns: Delete request response.
	public func delete(fromDb dbName: String, uri: String, rev: String, eventLoopGroup: EventLoopGroup? = nil) async throws -> CouchUpdateResponse {
		let httpClient: HTTPClient
		if let eventLoopGroup = eventLoopGroup {
			httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
		} else {
			httpClient = HTTPClient.shared
		}

		defer {
			if eventLoopGroup != nil {
				DispatchQueue.main.async {
					try? httpClient.syncShutdown()
				}
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

	/// Delete a document from a database.
	///
	/// Examples:
	///
	/// ```swift
	/// let response = try await couchDBClient.delete(fromDb: "databaseName", doc: doc)
	/// ```
	///
	/// - Parameters:
	///   - dbName: Database name.
	///   - doc: Document object/struct. Should conform to the ``CouchDBRepresentable`` protocol.
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
			httpClient = HTTPClient.shared
		}

		defer {
			if eventLoopGroup != nil {
				DispatchQueue.main.async {
					try? httpClient.syncShutdown()
				}
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
