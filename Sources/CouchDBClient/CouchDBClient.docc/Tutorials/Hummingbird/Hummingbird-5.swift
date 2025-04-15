import Hummingbird
import CouchDBClient

/// Controller for database-related routes
struct DatabaseController {
	let couchDBClient: CouchDBClient

	/// Add routes to the router
	func addRoutes(to router: Router<AppRequestContext>) {
		router.get("databases") { request, context in
			do {
				let databases = try await couchDBClient.getAllDBs()
				return databases
			} catch {
				context.logger.error("Failed to fetch databases: \(error)")
				throw HTTPError(.internalServerError, message: "Failed to fetch databases")
			}
		}
	}
}
