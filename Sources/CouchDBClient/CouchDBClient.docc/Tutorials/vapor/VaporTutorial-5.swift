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
		let url = req.parameters.get("appUrl")!
		let response = try await couchDBClient.get(
			fromDB: "myDB",
			uri: "_design/all/_view/by_url",
			queryItems: [
				URLQueryItem(name: "key", value: "\"\(url)\"")
			],
			eventLoopGroup: req.eventLoop
		)

		let expectedBytes =
			response.headers
			.first(name: "content-length")
			.flatMap(Int.init) ?? 1024 * 1024 * 10
		var bytes = try await response.body.collect(upTo: expectedBytes)

		guard let data = bytes.readData(length: bytes.readableBytes) else { throw Abort(.notFound) }

		let decodeResponse = try JSONDecoder().decode(RowsResponse<MyApp>.self, from: data)

		guard let myApp = decodeResponse.rows.first?.value else {
			throw Abort(.notFound)
		}

		return try await req.view.render("app-page")
	}
}
