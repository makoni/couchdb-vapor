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
        let url = req.parameters.get("appUrl")!
        let response = try await couchDBClient.get(
            dbName: "myDB",
            uri: "_design/all/_view/by_url",
            queryItems: [
                URLQueryItem(name: "key", value: "\"\(url)\"")
            ],
            eventLoopGroup: req.eventLoop
        )
        
        return try await req.view.render("app-page")
    }
}
