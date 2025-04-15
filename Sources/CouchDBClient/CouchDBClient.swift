//
//  couchdb_vapor.swift
//  couchdb-swift
//
//  Created by Sergey Armodin on 06/03/2019.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
import Dispatch
#else
import Foundation
#endif

import NIO
import NIOHTTP1
import NIOFoundationCompat
import AsyncHTTPClient

/// A CouchDB client actor with methods using Swift Concurrency.
public actor CouchDBClient {
	/// A configuration model for CouchDB client setup.
	/// This structure is used to define the necessary parameters for connecting to a CouchDB database.
	/// It conforms to the `Sendable` protocol for thread safety during concurrent operations.
	public struct Config: Sendable {
		/// The protocol used for CouchDB communication (e.g., HTTP or HTTPS).
		let couchProtocol: CouchDBProtocol

		/// The hostname or IP address of the CouchDB server.
		let couchHost: String

		/// The port number used for CouchDB communication.
		let couchPort: Int

		/// The username for CouchDB authentication.
		let userName: String

		/// The password for CouchDB authentication.
		let userPassword: String

		/// The timeout duration for CouchDB requests, specified in seconds.
		let requestsTimeout: Int64

		/// Initializes a new `Config` instance with default values for certain parameters.
		/// - Parameters:
		///   - couchProtocol: The communication protocol, defaulting to `.http`.
		///   - couchHost: The hostname or IP address, defaulting to `"127.0.0.1"`.
		///   - couchPort: The port number, defaulting to `5984`.
		///   - userName: The username for authentication (required).
		///   - userPassword: The password for authentication (required).
		///   - requestsTimeout: The timeout duration in seconds, defaulting to `30`.
		public init(
			couchProtocol: CouchDBClient.CouchDBProtocol = .http,
			couchHost: String = "127.0.0.1",
			couchPort: Int = 5984,
			userName: String,
			userPassword: String = ProcessInfo.processInfo.environment["COUCHDB_PASS"] ?? "",
			requestsTimeout: Int64 = 30
		) {
			self.couchProtocol = couchProtocol
			self.couchHost = couchHost
			self.couchPort = couchPort
			self.userName = userName
			self.userPassword = userPassword
			self.requestsTimeout = requestsTimeout
		}
	}

	/// An enumeration representing the available communication protocols for CouchDB.
	/// This enum conforms to `String` for raw value representation and `Sendable` for thread safety.
	public enum CouchDBProtocol: String, Sendable {
		/// HTTP protocol for CouchDB communication.
		case http

		/// HTTPS protocol for CouchDB communication, providing secure communication.
		case https
	}

	// MARK: - Public properties

	/// Flag if authorized in CouchDB.
	public var isAuthorized: Bool { authData?.ok ?? false }

	// MARK: - Private properties
	/// Requests protocol.
	private let couchProtocol: CouchDBProtocol
	/// Host.
	private let couchHost: String
	/// Port.
	private let couchPort: Int
	/// Session cookie for requests that need authorization.
	internal var sessionCookie: String?
	/// Session cookie as Cookie struct.
	internal var sessionCookieExpires: Date?
	/// CouchDB user name.
	private let userName: String
	/// You can set a timeout for requests in seconds. Default value is 30.
	private var requestsTimeout: Int64 = 30
	/// CouchDB user password.
	private let userPassword: String
	/// Authorization response from CouchDB.
	private var authData: CreateSessionResponse?
	/// HTTP client
	internal let httpClient: HTTPClient?

	// MARK: - Initializer

	/// Initializes a new instance of the CouchDB client using the provided configuration.
	///
	/// This initializer sets up the client with connection parameters and securely handles the user password,
	/// supporting environment variable fallback for sensitive data. It allows for optional customization of the
	/// connection parameters such as protocol, host, and port.
	///
	/// - Parameters:
	///   - config: A `CouchDBClient.Config` instance containing the configuration details, including protocol, host, port, username, and password.
	///   - httpClient: An optional `HTTPClient` instance. If not provided, a shared instance will be used.
	///
	/// ### Example Usage:
	/// ```swift
	/// // Create a configuration:
	/// let config = CouchDBClient.Config(
	///     couchProtocol: .http,
	///     couchHost: "127.0.0.1",
	///     couchPort: 5984,
	///     userName: "user",
	///     userPassword: "myPassword",
	///     requestsTimeout: 30
	/// )
	///
	/// // Create a client instance:
	/// let couchDBClient = CouchDBClient(config: config)
	/// ```
	///
	/// If you prefer not to include your password in the code, you can pass the `COUCHDB_PASS` environment variable
	/// in your command line. For example:
	/// ```bash
	/// COUCHDB_PASS=myPassword /path/.build/x86_64-unknown-linux-gnu/release/Run
	/// ```
	/// In this case, you can omit the `userPassword` parameter in the configuration:
	/// ```swift
	/// let config = CouchDBClient.Config(
	///     userName: "user"
	/// )
	/// let couchDBClient = CouchDBClient(config: config)
	/// ```
	///
	/// - Note: Ensure that the CouchDB server is running and accessible at the specified `couchHost` and `couchPort`
	/// before attempting to connect.
	public init(config: CouchDBClient.Config, httpClient: HTTPClient? = nil) {
		self.couchProtocol = config.couchProtocol
		self.couchHost = config.couchHost
		self.couchPort = config.couchPort
		self.userName = config.userName
		self.userPassword = config.userPassword
		self.requestsTimeout = config.requestsTimeout
		self.httpClient = httpClient
	}

	/// Shuts down the HTTP client used by the CouchDB client.
	///
	/// This asynchronous function ensures that the `HTTPClient` instance is properly shut down,
	/// releasing any resources it holds. It is important to call this method when the `CouchDBClient`
	/// is no longer needed to avoid resource leaks.
	///
	/// - Throws: An error if the shutdown process fails.
	public func shutdown() async throws {
		try await httpClient?.shutdown()
	}

	// MARK: - Public methods

	/// Retrieves a list of all database names from the CouchDB server.
	///
	/// This asynchronous function sends a `GET` request to the CouchDB server to fetch the names of all databases.
	/// It supports using a custom NIO's `EventLoopGroup` for network operations, providing flexibility for managing event loops.
	///
	/// - Parameter eventLoopGroup: An optional `EventLoopGroup` for executing network operations.
	///   If not provided, the function uses a shared instance of `HTTPClient`.
	/// - Returns: An array of `String` containing the names of all databases available on the server.
	/// - Throws: A `CouchDBClientError` if the request fails or if the response lacks required data.
	///
	/// ### Function Workflow:
	/// 1. The function authenticates with the CouchDB server if authentication is required.
	/// 2. An `HTTPClient` instance is created—either shared or scoped to the provided `EventLoopGroup`.
	/// 3. The request URL is built using the server's `/all_dbs` endpoint.
	/// 4. The function sends the `GET` request to CouchDB and processes the response.
	/// 5. If the response status is `.unauthorized`, a `CouchDBClientError.unauthorized` is thrown.
	/// 6. The response body is collected, with size limits based on `content-length` or a default maximum.
	/// 7. The collected data is decoded into an array of database names.
	///
	/// ### Example Usage:
	/// ```swift
	/// let dbNames = try await couchDBClient.getAllDBs()
	/// print("Available databases: \(dbNames)")
	/// ```
	///
	/// - Note: Ensure that the CouchDB server is running and accessible before calling this function.
	///   Handle any thrown errors appropriately, particularly authentication-related issues.

	public func getAllDBs(eventLoopGroup: EventLoopGroup? = nil) async throws -> [String] {
		try await authIfNeed(eventLoopGroup: eventLoopGroup)

		let httpClient = createHTTPClientIfNeed(eventLoopGroup: eventLoopGroup)

		defer {
			if eventLoopGroup != nil {
				DispatchQueue.main.async {
					try? httpClient.syncShutdown()
				}
			}
		}

		let url = buildUrl(path: "/_all_dbs")

		let request = try buildRequest(fromUrl: url, withMethod: .GET)
		let response =
			try await httpClient
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
	/// This asynchronous function sends a `HEAD` request to the CouchDB server to verify the existence of a specified database.
	/// It supports using a custom NIO's `EventLoopGroup` for managing network operations.
	///
	/// - Parameters:
	///   - dbName: The name of the database to check for existence.
	///   - eventLoopGroup: An optional `EventLoopGroup` used for executing network requests.
	///     If not provided, the function defaults to using a shared instance of `HTTPClient`.
	/// - Returns: A `Bool` indicating whether the database exists (`true`) or not (`false`).
	/// - Throws: A `CouchDBClientError` if the operation fails, including: `.unauthorized` if authentication fails, `.noData` if the response lacks required data.
	///
	/// ### Function Workflow:
	/// 1. Authenticates with the CouchDB server if authentication is required.
	/// 2. Creates an `HTTPClient` instance—either scoped to the provided `EventLoopGroup` or using the shared instance.
	/// 3. Constructs the request URL using the provided database name.
	/// 4. Sends a `HEAD` request to the CouchDB server to check the database existence.
	/// 5. Processes the server's response and checks its HTTP status code.
	/// 6. Returns `true` for a `.ok` response status and `false` otherwise.
	///
	/// ### Example Usage:
	/// ```swift
	/// let doesExist = try await couchDBClient.dbExists("myDatabase")
	/// print("Database exists: \(doesExist)")
	/// ```
	///
	/// - Note: Ensure that the CouchDB server is running and accessible before calling this function.
	///   Handle thrown errors appropriately, especially authentication-related issues.

	public func dbExists(_ dbName: String, eventLoopGroup: EventLoopGroup? = nil) async throws -> Bool {
		try await authIfNeed(eventLoopGroup: eventLoopGroup)

		let httpClient = createHTTPClientIfNeed(eventLoopGroup: eventLoopGroup)

		defer {
			if eventLoopGroup != nil {
				DispatchQueue.main.async {
					try? httpClient.syncShutdown()
				}
			}
		}

		let url = buildUrl(path: "/" + dbName)
		let request = try buildRequest(fromUrl: url, withMethod: .HEAD)
		let response =
			try await httpClient
			.execute(request, timeout: .seconds(requestsTimeout))

		if response.status == .unauthorized {
			throw CouchDBClientError.unauthorized
		}

		return response.status == .ok
	}

	/// Creates a new database on the CouchDB server.
	///
	/// This asynchronous function sends a `PUT` request to the CouchDB server to create a new database with the specified name.
	/// It supports using a custom `EventLoopGroup` for network operations, providing flexibility for managing event loops.
	///
	/// - Parameters:
	///   - dbName: The name of the database to be created.
	///   - eventLoopGroup: An optional `EventLoopGroup` for executing network requests.
	///     If not provided, the function defaults to using a shared instance of `HTTPClient`.
	/// - Returns: An `UpdateDBResponse` object that contains the result of the database creation operation.
	/// - Throws: A `CouchDBClientError` if the operation fails, including: `.unauthorized` if authentication fails, `.noData` if the response lacks required data, `.insertError` if the database creation fails and CouchDB returns an error.
	///
	/// ### Function Workflow:
	/// 1. Authenticates with the CouchDB server if required.
	/// 2. Creates an `HTTPClient` instance—either scoped to the provided `EventLoopGroup` or using the shared instance.
	/// 3. Constructs the request URL using the specified database name.
	/// 4. Sends a `PUT` request to the CouchDB server to create the database.
	/// 5. Processes the server's response, throwing errors for unauthorized access or missing data.
	/// 6. Decodes the response body into an `UpdateDBResponse` object if successful.
	/// 7. If decoding fails, attempts to decode the response into a `CouchDBError` object and throws it as an `.insertError`.
	///
	/// ### Example Usage:
	/// ```swift
	/// let creationResult = try await couchDBClient.createDB("newDatabase")
	/// print("Database creation successful: \(creationResult.ok)")
	/// ```
	///
	/// - Note: Ensure that the CouchDB server is running and accessible before calling this function.
	///   Handle any thrown errors appropriately, including authentication issues and potential conflicts if the database already exists.
	@discardableResult public func createDB(_ dbName: String, eventLoopGroup: EventLoopGroup? = nil) async throws -> UpdateDBResponse {
		try await authIfNeed(eventLoopGroup: eventLoopGroup)

		let httpClient = createHTTPClientIfNeed(eventLoopGroup: eventLoopGroup)

		defer {
			if eventLoopGroup != nil {
				DispatchQueue.main.async {
					try? httpClient.syncShutdown()
				}
			}
		}

		let url = buildUrl(path: "/\(dbName)")

		let request = try self.buildRequest(fromUrl: url, withMethod: .PUT)

		let response =
			try await httpClient
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
	/// This asynchronous function sends a `DELETE` request to the CouchDB server to remove a database with the specified name.
	/// It supports using a custom `EventLoopGroup` for managing network operations.
	///
	/// - Parameters:
	///   - dbName: The name of the database to delete.
	///   - eventLoopGroup: An optional `EventLoopGroup` used for executing network operations.
	///     If not provided, the function defaults to using a shared instance of `HTTPClient`.
	/// - Returns: An `UpdateDBResponse` object that contains the result of the database deletion operation.
	/// - Throws: A `CouchDBClientError` if the operation fails, including: `.unauthorized` if authentication fails, `.noData` if the response lacks required data, `.insertError` if the deletion fails and CouchDB returns an error.
	///
	/// ### Function Workflow:
	/// 1. Authenticates with the CouchDB server if required.
	/// 2. Creates an `HTTPClient` instance—either scoped to the provided `EventLoopGroup` or using the shared instance.
	/// 3. Constructs the request URL using the specified database name.
	/// 4. Sends a `DELETE` request to the CouchDB server to delete the database.
	/// 5. Processes the server's response, throwing errors for unauthorized access or missing data.
	/// 6. Decodes the response body into an `UpdateDBResponse` object if successful.
	/// 7. If decoding fails, attempts to decode the response into a `CouchDBError` object and throws it as `.deleteError`.
	///
	/// ### Example Usage:
	/// ```swift
	/// let deletionResult = try await couchDBClient.deleteDB("obsoleteDatabase")
	/// print("Database deletion successful: \(deletionResult.ok)")
	/// ```
	///
	/// - Note: Ensure that the CouchDB server is running and accessible before calling this function.
	///   Handle thrown errors appropriately, especially authentication issues and conflicts if the database does not exist.
	@discardableResult public func deleteDB(_ dbName: String, eventLoopGroup: EventLoopGroup? = nil) async throws -> UpdateDBResponse {
		try await authIfNeed(eventLoopGroup: eventLoopGroup)

		let httpClient = createHTTPClientIfNeed(eventLoopGroup: eventLoopGroup)

		defer {
			if eventLoopGroup != nil {
				DispatchQueue.main.async {
					try? httpClient.syncShutdown()
				}
			}
		}

		let url = buildUrl(path: "/\(dbName)")

		let request = try self.buildRequest(fromUrl: url, withMethod: .DELETE)

		let response =
			try await httpClient
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
				throw CouchDBClientError.deleteError(error: couchdbError)
			}
			throw parsingError
		}
	}

	/// Fetches data from a specified database and URI on the CouchDB server.
	///
	/// This asynchronous function sends a `GET` request to the CouchDB server to retrieve data from a specific database and resource URI.
	/// It supports using a custom `EventLoopGroup` for network operations and allows the inclusion of query parameters.
	///
	/// - Parameters:
	///   - dbName: The name of the database from which to fetch data.
	///   - uri: The URI path of the specific resource or endpoint within the database (e.g., document ID or view path).
	///   - queryItems: An optional array of `URLQueryItem` to specify query parameters for the request.
	///   - eventLoopGroup: An optional `EventLoopGroup` for executing network operations.
	///     If not provided, the function defaults to using a shared instance of `HTTPClient`.
	/// - Returns: An `HTTPClientResponse` object containing the server's response to the request.
	/// - Throws: A `CouchDBClientError` if the operation fails, including: `.unauthorized` if authentication fails, `.noData` if the response lacks required data.
	///
	/// ### Function Workflow:
	/// 1. Authenticates with the CouchDB server if required.
	/// 2. Creates an `HTTPClient` instance, either scoped to the provided `EventLoopGroup` or using the shared instance.
	/// 3. Builds the request URL using the database name, resource URI, and optional query items.
	/// 4. Sends a `GET` request to the CouchDB server and processes the server's response.
	/// 5. If the response status is `.unauthorized`, throws a `CouchDBClientError.unauthorized` error.
	/// 6. Updates the response body with the collected data bytes before returning.
	///
	/// ### Example Usage:
	/// #### Define Your Document Data Model
	/// ```swift
	/// struct ExpectedDoc: CouchDBRepresentable {
	///     var name: String
	///     var _id: String = NSUUID().uuidString
	///     var _rev: String?
	///
	///     func updateRevision(_ newRevision: String) -> Self {
	///         return ExpectedDoc(name: name, _id: _id, _rev: newRevision)
	///     }
	/// }
	/// ```
	///
	/// #### Fetch Document by ID:
	/// ```swift
	/// let response = try await couchDBClient.get(
	///     fromDB: "myDatabase",
	///     uri: "documentID"
	/// )
	///
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
	/// print(doc)
	/// ```
	///
	/// #### Fetch Data from a CouchDB View:
	/// ```swift
	/// let response = try await couchDBClient.get(
	///     fromDB: "myDatabase",
	///     uri: "_design/all/_view/by_url",
	///     queryItems: [
	///         URLQueryItem(name: "key", value: "\"\(url)\"")
	///     ]
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
	/// print(decodedResponse.rows)
	/// ```
	///
	/// - Note: Ensure that the CouchDB server is running and accessible. Handle thrown errors appropriately, especially for authentication issues.
	public func get(fromDB dbName: String, uri: String, queryItems: [URLQueryItem]? = nil, eventLoopGroup: EventLoopGroup? = nil) async throws -> HTTPClientResponse {
		try await authIfNeed(eventLoopGroup: eventLoopGroup)

		let httpClient = createHTTPClientIfNeed(eventLoopGroup: eventLoopGroup)

		defer {
			if eventLoopGroup != nil {
				DispatchQueue.main.async {
					try? httpClient.syncShutdown()
				}
			}
		}

		let url = buildUrl(path: "/" + dbName + "/" + uri, query: queryItems ?? [])
		let request = try buildRequest(fromUrl: url, withMethod: .GET)
		var response =
			try await httpClient
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

	/// Retrieves a document of a specified type from a database on the CouchDB server.
	///
	/// This asynchronous generic function sends a `GET` request to the CouchDB server to retrieve a document
	/// from a specific database and resource URI. The retrieved data is decoded into the specified `CouchDBRepresentable` type.
	/// It supports using a custom `EventLoopGroup`, query parameters, and a configurable date decoding strategy.
	///
	/// - Parameters:
	///   - dbName: The name of the database from which to fetch the document.
	///   - uri: The URI path of the specific document within the database (e.g., a document ID).
	///   - queryItems: An optional array of `URLQueryItem` to specify query parameters for the request.
	///   - dateDecodingStrategy: The date decoding strategy to use when decoding dates. Defaults to `.secondsSince1970`.
	///   - eventLoopGroup: An optional `EventLoopGroup` for executing network operations.
	///     If not provided, the function uses a shared `HTTPClient`.
	/// - Returns: A document of type `T`, where `T` conforms to `CouchDBRepresentable`.
	/// - Throws: A `CouchDBClientError` if the operation fails, including: `.unauthorized` if authentication fails, `.noData` if the response lacks required data, `.getError` if the document decoding fails, with the underlying `CouchDBError`.
	///
	/// ### Function Workflow:
	/// 1. Authenticates with the CouchDB server if required.
	/// 2. Sends a `GET` request to the specified database and URI, optionally including query parameters.
	/// 3. Processes the server's response, throwing errors for unauthorized access or missing data.
	/// 4. Decodes the response body into the specified type `T` using a `JSONDecoder` configured with the provided date decoding strategy.
	/// 5. If decoding fails, attempts to decode the response as a `CouchDBError` and throws it as a `.getError`.
	///
	/// ### Example Usage:
	/// #### Define Your Document Model:
	/// ```swift
	/// struct MyDocumentType: CouchDBRepresentable {
	///     var name: String
	///     var _id: String = UUID().uuidString
	///     var _rev: String?
	///
	///     func updateRevision(_ newRevision: String) -> Self {
	///         return MyDocumentType(name: name, _id: _id, _rev: newRevision)
	///     }
	/// }
	/// ```
	///
	/// #### Retrieve a Document by ID:
	/// ```swift
	/// let doc: MyDocumentType = try await couchDBClient.get(
	///     fromDB: "myDatabase",
	///     uri: "documentID"
	/// )
	/// print(doc)
	/// ```
	///
	/// - Note: Ensure that the CouchDB server is running and accessible before calling this function.
	///   Handle thrown errors appropriately, especially for authentication failures and data decoding issues.
	public func get<T: CouchDBRepresentable>(fromDB dbName: String, uri: String, queryItems: [URLQueryItem]? = nil, dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .secondsSince1970, eventLoopGroup: EventLoopGroup? = nil) async throws -> T {
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

	/// Performs a query to find documents in a database on the CouchDB server that match the given selector.
	///
	/// This asynchronous generic function sends a query to the CouchDB server to search for documents in a specific database
	/// based on the criteria defined by the selector. The resulting documents are decoded into an array of the specified
	/// `CouchDBRepresentable` type. It supports using a custom `EventLoopGroup` for network operations and allows the specification
	/// of a custom date decoding strategy.
	///
	/// - Parameters:
	///   - dbName: The name of the database in which to perform the query.
	///   - selector: A `Codable` object that defines the criteria for selecting documents.
	///   - dateDecodingStrategy: The date decoding strategy to use for decoding dates within the documents. Defaults to `.secondsSince1970`.
	///   - eventLoopGroup: An optional `EventLoopGroup` for executing network operations.
	///     If not provided, the function defaults to using a shared instance of `HTTPClient`.
	/// - Returns: An array of documents of type `T`, where `T` conforms to `CouchDBRepresentable`.
	/// - Throws: A `CouchDBClientError` if the operation fails, including: `.noData` if the response lacks required data, `.findError` if decoding fails, with the underlying `CouchDBError`.
	///
	/// ### Function Workflow:
	/// 1. Encodes the selector criteria into JSON format and includes it as the request body.
	/// 2. Sends the query request to the specified database on the CouchDB server.
	/// 3. Collects the response body up to a size limit defined by `content-length` or a default maximum.
	/// 4. Uses a `JSONDecoder` configured with the specified date decoding strategy to decode the response data
	///    into a `CouchDBFindResponse<T>` object.
	/// 5. Extracts and returns the documents from the `CouchDBFindResponse` object.
	/// 6. Handles decoding errors by attempting to decode a `CouchDBError` object and throwing it as `.findError`.
	///
	/// ### Example Usage:
	/// ```swift
	/// let selector = ["selector": ["name": "Sam"]]
	/// let documents: [MyDocumentType] = try await couchDBClient.find(
	///     inDB: "myDatabase",
	///     selector: selector
	/// )
	/// print(documents)
	/// ```
	///
	/// - Note: Ensure that the CouchDB server is running and accessible before calling this function.
	///   Handle thrown errors appropriately, especially for data decoding issues or query mismatches.
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

	/// Executes a find query on a specified database on the CouchDB server.
	///
	/// This asynchronous function sends a `POST` request with a custom body to the CouchDB server's `_find` endpoint to perform a query
	/// in the specified database. It allows the use of a custom `EventLoopGroup` for network operations.
	///
	/// - Parameters:
	///   - dbName: The name of the database in which to execute the query.
	///   - body: The `HTTPClientRequest.Body` containing the encoded query to be sent to the server.
	///   - eventLoopGroup: An optional `EventLoopGroup` for executing network requests.
	///     If not provided, the function uses a shared instance of `HTTPClient`.
	/// - Returns: An `HTTPClientResponse` object containing the server's response to the find query.
	/// - Throws: A `CouchDBClientError` if the operation fails, including: `.unauthorized`: If authentication fails.
	///
	/// ### Function Workflow:
	/// 1. Authenticates with the CouchDB server if required.
	/// 2. Creates an `HTTPClient` instance—either scoped to the provided `EventLoopGroup` or using the shared instance.
	/// 3. Constructs the request URL for the `_find` endpoint using the database name.
	/// 4. Sets the request body with the encoded query and sends a `POST` request to the CouchDB server.
	/// 5. Processes the server's response, throwing errors for unauthorized access.
	/// 6. Updates the response body with the collected bytes before returning the response object.
	///
	/// ### Example Usage:
	/// #### Perform a Find Query:
	/// ```swift
	/// let selector = ["selector": ["name": "Greg"]]
	/// let bodyData = try JSONEncoder().encode(selector)
	/// let findResponse = try await couchDBClient.find(
	///     inDB: "myDatabase",
	///     body: .data(bodyData)
	/// )
	///
	/// let bytes = findResponse.body!.readBytes(length: findResponse.body!.readableBytes)!
	/// let docs = try JSONDecoder().decode(
	///     CouchDBFindResponse<ExpectedDoc>.self,
	///     from: Data(bytes)
	/// ).docs
	/// print(docs)
	/// ```
	///
	/// - Note: Ensure that the CouchDB server is running and accessible before calling this function.
	///   Handle thrown errors appropriately, especially authentication-related issues.

	public func find(inDB dbName: String, body: HTTPClientRequest.Body, eventLoopGroup: EventLoopGroup? = nil) async throws -> HTTPClientResponse {
		try await authIfNeed(eventLoopGroup: eventLoopGroup)

		let httpClient = createHTTPClientIfNeed(eventLoopGroup: eventLoopGroup)

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
		var response =
			try await httpClient
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

	/// Updates a document in a specified database on the CouchDB server.
	///
	/// This asynchronous function sends a `PUT` request to the CouchDB server to update a document at a given URI within a specified database.
	/// It allows the use of a custom `EventLoopGroup` for network operations.
	///
	/// - Parameters:
	///   - dbName: The name of the database containing the document to be updated.
	///   - uri: The URI path of the specific document within the database.
	///   - body: The `HTTPClientRequest.Body` containing the updated content of the document.
	///   - eventLoopGroup: An optional `EventLoopGroup` for executing network operations.
	///     If not provided, the function uses a shared instance of `HTTPClient`.
	/// - Returns: A `CouchUpdateResponse` object containing the result of the update operation.
	/// - Throws: A `CouchDBClientError` if the operation fails, including: `.unauthorized` if authentication fails, `.noData` if the response lacks required data, `.updateError` if decoding the response fails, with the underlying `CouchDBError`.
	///
	/// ### Function Workflow:
	/// 1. Authenticates with the CouchDB server if required.
	/// 2. Creates an `HTTPClient` instance—either scoped to the provided `EventLoopGroup` or using the shared instance.
	/// 3. Constructs the request URL for the document using the database name and URI.
	/// 4. Sets the request body with the updated document content and sends a `PUT` request to the server.
	/// 5. Processes the server's response, throwing errors for unauthorized access or missing data.
	/// 6. Decodes the response body into a `CouchUpdateResponse` object and returns it.
	/// 7. If decoding fails, attempts to decode the response as a `CouchDBError` and throws it as `.updateError`.
	///
	/// ### Example Usage:
	/// #### Define Your Document Model:
	/// ```swift
	/// struct ExpectedDoc: CouchDBRepresentable {
	///     var name: String
	///     var _id: String = UUID().uuidString
	///     var _rev: String?
	///
	///     func updateRevision(_ newRevision: String) -> Self {
	///         return ExpectedDoc(name: name, _id: _id, _rev: newRevision)
	///     }
	/// }
	/// ```
	///
	/// #### Update a Document:
	/// ```swift
	/// // Fetch the document by ID
	/// var response = try await couchDBClient.get(
	///     fromDB: "myDatabase",
	///     uri: "documentID"
	/// )
	///
	/// // Parse the document
	/// let bytes = response.body!.readBytes(length: response.body!.readableBytes)!
	/// var doc = try JSONDecoder().decode(
	///     ExpectedDoc.self,
	///     from: Data(bytes)
	/// )
	///
	/// // Modify the document
	/// doc.name = "Updated name"
	///
	/// // Encode the updated document into JSON
	/// let data = try JSONEncoder().encode(doc)
	/// let body: HTTPClientRequest.Body = .bytes(ByteBuffer(data: data))
	///
	/// // Send the update request
	/// let updateResponse = try await couchDBClient.update(
	///     dbName: "myDatabase",
	///     uri: doc._id,
	///     body: body
	/// )
	///
	/// print(updateResponse)
	/// ```
	///
	/// - Note: Ensure that the CouchDB server is running and accessible before calling this function.
	///   Handle thrown errors appropriately, especially for authentication or data-related issues.
	public func update(dbName: String, uri: String, body: HTTPClientRequest.Body, eventLoopGroup: EventLoopGroup? = nil) async throws -> CouchUpdateResponse {
		try await authIfNeed(eventLoopGroup: eventLoopGroup)

		let httpClient = createHTTPClientIfNeed(eventLoopGroup: eventLoopGroup)

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

		let response =
			try await httpClient
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

	/// Updates a document conforming to `CouchDBRepresentable` in a specified database on the CouchDB server.
	///
	/// This asynchronous generic function updates a document in the specified database. The document must conform to the
	/// `CouchDBRepresentable` protocol, which requires `_id` and `_rev` properties. The function supports using a custom
	/// `EventLoopGroup` for network operations and allows a configurable date encoding strategy.
	///
	/// - Parameters:
	///   - dbName: The name of the database containing the document to be updated.
	///   - doc: A reference to the document of type `T` that will be updated. The document must have valid `_id` and `_rev` properties.
	///   - dateEncodingStrategy: The date encoding strategy to use when encoding dates in the document. Defaults to `.secondsSince1970`.
	///   - eventLoopGroup: An optional `EventLoopGroup` for executing network operations.
	///     If not provided, the function uses a shared instance of `HTTPClient`.
	/// - Returns: The updated document of type `T`, with its `_rev` property reflecting the new revision token.
	/// - Throws: A `CouchDBClientError` if the operation fails, including: `.revMissing` if the document's `_rev` is missing or empty, `.unknownResponse` if the server's response is not successful or unexpected.
	///
	/// ### Function Workflow:
	/// 1. Verifies that the document has a valid `_rev` property.
	/// 2. Encodes the document using a `JSONEncoder` configured with the specified date encoding strategy.
	/// 3. Constructs the request body using the encoded document data.
	/// 4. Sends a `PUT` request to update the document in the specified database.
	/// 5. Processes the server's response and throws an error if the operation fails.
	/// 6. Updates the document's `_rev` (and `_id` if necessary) based on the server's response.
	///
	/// ### Example Usage:
	/// #### Define Your Document Model:
	/// ```swift
	/// struct ExpectedDoc: CouchDBRepresentable {
	///     var name: String
	///     var _id: String = UUID().uuidString
	///     var _rev: String?
	///
	///     func updateRevision(_ newRevision: String) -> Self {
	///         return ExpectedDoc(name: name, _id: _id, _rev: newRevision)
	///     }
	/// }
	/// ```
	///
	/// #### Retrieve and Update a Document:
	/// ```swift
	/// var doc: ExpectedDoc = try await couchDBClient.get(
	///     fromDB: "myDatabase",
	///     uri: "documentID"
	/// )
	///
	/// // Modify the document
	/// doc.name = "Updated name"
	///
	/// // Update the document in the database
	/// doc = try await couchDBClient.update(
	///     dbName: "myDatabase",
	///     doc: doc
	/// )
	///
	/// print(doc) // Document now includes the updated name and a new `_rev` value
	/// ```
	///
	/// - Note: Ensure that the CouchDB server is running and accessible before calling this function.
	///   Handle thrown errors appropriately, especially for document updates and server responses.
	public func update<T: CouchDBRepresentable>(dbName: String, doc: T, dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .secondsSince1970, eventLoopGroup: EventLoopGroup? = nil) async throws -> T {
		guard doc._rev?.isEmpty == false else { throw CouchDBClientError.revMissing }

		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = dateEncodingStrategy
		let encodedData = try encoder.encode(doc)

		let body: HTTPClientRequest.Body = .bytes(ByteBuffer(data: encodedData))

		let updateResponse = try await update(
			dbName: dbName,
			uri: doc._id,
			body: body,
			eventLoopGroup: eventLoopGroup
		)

		guard updateResponse.ok == true else {
			throw CouchDBClientError.unknownResponse
		}

		return doc.updateRevision(updateResponse.rev)
	}

	/// Inserts a new document into a specified database on the CouchDB server.
	///
	/// This asynchronous function sends a `POST` request to the CouchDB server to insert a new document into the given database.
	/// It allows the use of a custom `EventLoopGroup` for managing network operations.
	///
	/// - Parameters:
	///   - dbName: The name of the database into which the new document will be inserted.
	///   - body: The `HTTPClientRequest.Body` containing the JSON-encoded content of the new document.
	///   - eventLoopGroup: An optional `EventLoopGroup` for executing network requests.
	///     If not provided, the function uses a shared instance of `HTTPClient`.
	/// - Returns: A `CouchUpdateResponse` object containing the result of the insertion operation.
	/// - Throws: A `CouchDBClientError` if the operation fails, including: `.unauthorized` if authentication fails, `.noData` if the response lacks required data, `.insertError` if decoding the response fails, with the underlying `CouchDBError`.
	///
	/// ### Function Workflow:
	/// 1. Authenticates with the CouchDB server if required.
	/// 2. Creates an `HTTPClient` instance—either scoped to the provided `EventLoopGroup` or using the shared instance.
	/// 3. Constructs the request URL using the database name.
	/// 4. Sets the request body with the JSON-encoded content of the new document and sends a `POST` request to the server.
	/// 5. Processes the server's response, throwing errors for unauthorized access or missing data.
	/// 6. Decodes the response body into a `CouchUpdateResponse` object and returns it.
	/// 7. Handles decoding errors by attempting to decode the response as a `CouchDBError` and throws it as `.insertError`.
	///
	/// ### Example Usage:
	/// #### Define Your Document Model:
	/// ```swift
	/// struct ExpectedDoc: CouchDBRepresentable {
	///     var name: String
	///     var _id: String = UUID().uuidString
	///     var _rev: String?
	///
	///     func updateRevision(_ newRevision: String) -> Self {
	///         return ExpectedDoc(name: name, _id: _id, _rev: newRevision)
	///     }
	/// }
	/// ```
	///
	/// #### Create and Insert a Document:
	/// ```swift
	/// let testDoc = ExpectedDoc(name: "My name")
	/// let encodedData = try JSONEncoder().encode(testDoc)
	///
	/// let body: HTTPClientRequest.Body = .bytes(ByteBuffer(data: encodedData))
	///
	/// let response = try await couchDBClient.insert(
	///     dbName: "myDatabase",
	///     body: body
	/// )
	///
	/// print(response) // Response includes operation status and revision token
	/// ```
	///
	/// - Note: Ensure that the CouchDB server is running and accessible before calling this function.
	///   Handle thrown errors appropriately, especially for authentication issues or unexpected server responses.
	public func insert(dbName: String, body: HTTPClientRequest.Body, eventLoopGroup: EventLoopGroup? = nil) async throws -> CouchUpdateResponse {
		try await authIfNeed(eventLoopGroup: eventLoopGroup)

		let httpClient = createHTTPClientIfNeed(eventLoopGroup: eventLoopGroup)

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

		let response =
			try await httpClient
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

	/// Inserts a new document conforming to `CouchDBRepresentable` into a specified database on the CouchDB server.
	///
	/// This asynchronous generic function inserts a new document into the specified database. The document must conform to the
	/// `CouchDBRepresentable` protocol, which requires `_id` and `_rev` properties. It supports using a custom `EventLoopGroup` for
	/// network operations and allows a configurable date encoding strategy.
	///
	/// - Parameters:
	///   - dbName: The name of the database where the new document will be inserted.
	///   - doc: The document of type `T` to be inserted. The type `T` must conform to `CouchDBRepresentable`.
	///   - dateEncodingStrategy: The strategy used for encoding dates within the document. Defaults to `.secondsSince1970`.
	///   - eventLoopGroup: An optional `EventLoopGroup` for managing network operations. If not provided, a shared instance of `HTTPClient` is used.
	/// - Returns: The newly inserted document of type `T`, updated with its `_id` and `_rev` properties.
	/// - Throws: A `CouchDBClientError` if the operation fails, including: `.unknownResponse` if the server's response is unexpected or unsuccessful.
	///
	/// ### Function Workflow:
	/// 1. Encodes the document using a `JSONEncoder` configured with the specified date encoding strategy.
	/// 2. Prepares a `POST` request with the encoded document as the request body.
	/// 3. Sends the request to the CouchDB server and processes the response.
	/// 4. Updates the document's `_id` and `_rev` based on the server's response.
	/// 5. Throws an error if the server's response is unexpected or unsuccessful.
	///
	/// ### Example Usage:
	/// #### Define Your Document Model:
	/// ```swift
	/// struct ExpectedDoc: CouchDBRepresentable {
	///     var name: String
	///     var _id: String = UUID().uuidString
	///     var _rev: String?
	///
	///     func updateRevision(_ newRevision: String) -> Self {
	///         return ExpectedDoc(name: name, _id: _id, _rev: newRevision)
	///     }
	/// }
	/// ```
	///
	/// #### Insert a New Document:
	/// ```swift
	/// var testDoc = ExpectedDoc(name: "My name")
	///
	/// testDoc = try await couchDBClient.insert(
	///     dbName: "myDatabase",
	///     doc: testDoc
	/// )
	///
	/// print(testDoc) // Document now contains its assigned `_id` and `_rev`.
	/// ```
	///
	/// - Note: Ensure that the CouchDB server is operational and accessible before using this function.
	///   Handle thrown errors appropriately, especially for unexpected server responses.
	public func insert<T: CouchDBRepresentable>(dbName: String, doc: T, dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .secondsSince1970, eventLoopGroup: EventLoopGroup? = nil) async throws -> T {
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

		return doc.updateRevision(insertResponse.rev)
	}

	/// Deletes a document from a specified database on the CouchDB server.
	///
	/// This asynchronous function sends a `DELETE` request to the CouchDB server to remove a document identified by its URI and revision number.
	/// It supports using a custom `EventLoopGroup` for managing network operations.
	///
	/// - Parameters:
	///   - dbName: The name of the database from which the document will be deleted.
	///   - uri: The URI path of the specific document within the database.
	///   - rev: The revision number of the document to be deleted.
	///   - eventLoopGroup: An optional `EventLoopGroup` for executing network requests.
	///     If not provided, the function uses a shared instance of `HTTPClient`.
	/// - Returns: A `CouchUpdateResponse` object containing the result of the delete operation.
	/// - Throws: A `CouchDBClientError` if the operation fails, including: `.unauthorized` if authentication fails, `.noData`: if the response lacks required data.
	///
	/// ### Function Workflow:
	/// 1. Creates an `HTTPClient` instance—either scoped to the provided `EventLoopGroup` or using the shared instance.
	/// 2. Constructs the request URL using the database name, document URI, and revision query parameter.
	/// 3. Sends a `DELETE` request to remove the document from the CouchDB server.
	/// 4. Processes the server's response, throwing errors for unauthorized access or missing data.
	/// 5. Decodes the response body into a `CouchUpdateResponse` object if the deletion is successful.
	/// 6. Returns a `CouchUpdateResponse` with `ok` set to `false` if there is no response data.
	///
	/// ### Example Usage:
	/// ```swift
	/// let response = try await couchDBClient.delete(
	///     fromDb: "myDatabase",
	///     uri: "documentID",
	///     rev: "documentRevision"
	/// )
	/// print(response) // Response includes operation status and revision token
	/// ```
	///
	/// - Note: Ensure that the CouchDB server is running and accessible before calling this function.
	///   Handle thrown errors appropriately, especially for authentication issues or unexpected server responses.
	public func delete(fromDb dbName: String, uri: String, rev: String, eventLoopGroup: EventLoopGroup? = nil) async throws -> CouchUpdateResponse {
		let httpClient = createHTTPClientIfNeed(eventLoopGroup: eventLoopGroup)

		defer {
			if eventLoopGroup != nil {
				DispatchQueue.main.async {
					try? httpClient.syncShutdown()
				}
			}
		}

		let url = buildUrl(
			path: "/" + dbName + "/" + uri,
			query: [
				URLQueryItem(name: "rev", value: rev)
			]
		)
		let request = try self.buildRequest(fromUrl: url, withMethod: .DELETE)

		let response =
			try await httpClient
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

	/// Deletes a document conforming to `CouchDBRepresentable` from a specified database on the CouchDB server.
	///
	/// This asynchronous function removes a document from the specified database. The document must conform to the
	/// `CouchDBRepresentable` protocol, which includes the `_id` and `_rev` properties required for the deletion process.
	/// It supports using a custom `EventLoopGroup` for network operations.
	///
	/// - Parameters:
	///   - dbName: The name of the database from which the document will be deleted.
	///   - doc: The document of type `CouchDBRepresentable` to be deleted.
	///   - eventLoopGroup: An optional `EventLoopGroup` for executing network requests.
	///     If not provided, a shared instance of `HTTPClient` is used.
	/// - Returns: A `CouchUpdateResponse` object containing the result of the delete operation.
	/// - Throws: A `CouchDBClientError` if the operation fails, including: `.revMissing` if the document's `_rev` property is missing.
	///
	/// ### Function Workflow:
	/// 1. Validates the presence of the document's `_rev` property.
	/// 2. Calls `delete(fromDb:uri:rev:eventLoopGroup:)` with the document's `_id` and `_rev` to execute the deletion.
	/// 3. Processes and returns the server's response as a `CouchUpdateResponse` object.
	///
	/// ### Example Usage:
	/// ```swift
	/// let deleteResult = try await couchDBClient.delete(
	///     fromDb: "myDatabase",
	///     doc: myDocument
	/// )
	/// print(deleteResult) // Response includes operation status and revision token
	/// ```
	///
	/// - Note: Ensure that the CouchDB server is operational and accessible before using this function.
	///   Handle thrown errors appropriately, especially for missing document properties or unexpected server responses.

	public func delete(fromDb dbName: String, doc: CouchDBRepresentable, eventLoopGroup: EventLoopGroup? = nil) async throws -> CouchUpdateResponse {
		guard let rev = doc._rev else { throw CouchDBClientError.revMissing }

		return try await delete(fromDb: dbName, uri: doc._id, rev: rev, eventLoopGroup: eventLoopGroup)
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

	/// Create an HTTPClient instance if not provided during init method.
	/// - Parameter eventLoopGroup: NIO's EventLoopGroup object. NIO's shared will be used if nil value provided.
	/// - Returns: HTTP client.
	func createHTTPClientIfNeed(eventLoopGroup: EventLoopGroup? = nil) -> HTTPClient {
		if let httpClient {
			return httpClient
		}

		if let eventLoopGroup = eventLoopGroup {
			return HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
		} else {
			return HTTPClient.shared
		}
	}

	/// Get authorization cookie in didn't yet. This cookie will be added automatically to requests that require authorization.
	/// API reference: https://docs.couchdb.org/en/stable/api/server/authn.html#session
	/// - Parameter eventLoopGroup: NIO's EventLoopGroup object. NIO's shared will be used if nil value provided.
	/// - Returns: Authorization response.
	@discardableResult
	func authIfNeed(eventLoopGroup: EventLoopGroup? = nil) async throws -> CreateSessionResponse? {
		// already authorized
		if let authData = authData, let sessionCookieExpires = sessionCookieExpires, sessionCookieExpires > Date() {
			return authData
		}

		let httpClient = createHTTPClientIfNeed(eventLoopGroup: eventLoopGroup)

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

		let response =
			try await httpClient
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

	func buildRequest(fromUrl url: String, withMethod method: HTTPMethod) throws -> HTTPClientRequest {
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
