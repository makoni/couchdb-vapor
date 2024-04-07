import Vapor
import CouchDBClient

let couchDBClient = CouchDBClient()

struct MyApp: Content, CouchDBRepresentable {
    let title: String
    let url: String
    let _id: String
    var _rev: String
}

func routes(_ app: Application) throws {
    app.get(":appUrl") { req async throws -> View in
        return try await req.view.render("app-page")
    }
}
