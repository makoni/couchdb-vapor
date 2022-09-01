import Vapor
import CouchDBClient

let couchDBClient = CouchDBClient()

struct MyApp: Content, CouchDBRepresentable {
    let title: String
    let url: String
    let _id: String
    var _rev: String
    
    /// Row model for CouchDB
    struct Row: Content {
        let value: MyApp
    }
    
    /// Rows response
    struct RowsResponse: Content {
        let total_rows: Int
        let offset: Int
        let rows: [Row]
    }
}

func routes(_ app: Application) throws {
    app.get(":appUrl") { req async throws -> View in
        return try await req.view.render("app-page")
    }
}
