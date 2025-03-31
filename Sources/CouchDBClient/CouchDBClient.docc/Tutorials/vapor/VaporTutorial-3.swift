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

struct MyApp: Content, CouchDBRepresentable {
	let _id: String
	var _rev: String?
	let title: String
	let url: String

	func updateRevision(_ newRevision: String) -> MyApp {
		return MyApp(_id: _id, _rev: newRevision, title: title, url: url)
	}
}

func routes(_ app: Application) throws {
	app.get(":appUrl") { req async throws -> View in
		return try await req.view.render("app-page")
	}
}
