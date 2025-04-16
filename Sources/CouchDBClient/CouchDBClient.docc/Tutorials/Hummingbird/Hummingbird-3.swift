import Hummingbird
import Logging
import ServiceLifecycle
import CouchDBClient

/// Application arguments protocol. We use a protocol so we can call
/// `buildApplication` inside Tests as well as in the App executable.
/// Any variables added here also have to be added to `App` in App.swift and
/// `TestArguments` in AppTest.swift
public protocol AppArguments {
	var hostname: String { get }
	var port: Int { get }
	var logLevel: Logger.Level? { get }
}

public struct CouchDBService: Service {
	let client: CouchDBClient

	public init(client: CouchDBClient) {
		self.client = client
	}

	public func run() async throws {
		_ = try await client.dbExists("_users")
		try? await gracefulShutdown()
		try await client.shutdown()
	}
}

///  Build application
/// - Parameter arguments: application arguments
public func buildApplication(_ arguments: some AppArguments) async throws -> some ApplicationProtocol {
	let environment = Environment()
	let logger = {
		var logger = Logger(label: "HBTest")
		logger.logLevel =
			arguments.logLevel ?? environment.get("LOG_LEVEL").flatMap { Logger.Level(rawValue: $0) } ?? .info
		return logger
	}()
	let router = buildRouter()

	let app = Application(
		router: router,
		configuration: .init(
			address: .hostname(arguments.hostname, port: arguments.port),
			serverName: "HBTest"
		),
		services: [],
		logger: logger
	)
	return app
}

// Request context used by application
typealias AppRequestContext = BasicRequestContext

/// Build router
func buildRouter() -> Router<AppRequestContext> {
	let router = Router(context: AppRequestContext.self)
	// Add middleware
	router.addMiddleware {
		// logging middleware
		LogRequestsMiddleware(.info)
	}
	// Add default endpoint
	router.get("/") { _, _ in
		return "Hello!"
	}
	return router
}
