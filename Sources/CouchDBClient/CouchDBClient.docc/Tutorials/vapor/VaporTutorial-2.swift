import Vapor
import CouchDBClient

let couchDBClient = CouchDBClient()

func routes(_ app: Application) throws {
    app.get(":appUrl") { req async throws -> View in
        return try await req.view.render("app-page")
    }
}
