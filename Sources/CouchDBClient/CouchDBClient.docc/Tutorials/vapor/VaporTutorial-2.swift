import Vapor
import CouchDBClient

let config = CouchDBClient.Config(
	couchProtocol: .http,
	couchHost: "127.0.0.1",
	couchPort: 5984,
	userName: "admin",
	userPassword: "yourPassword"
)
let couchDBClient = CouchDBClient(config: config)

func routes(_ app: Application) throws {
	app.get(":appUrl") { req async throws -> View in
		return try await req.view.render("app-page")
	}
}
