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
        let url = req.parameters.get("appUrl")!
        let response = try await couchDBClient.get(
            fromDB: "myDB",
            uri: "_design/all/_view/by_url",
            queryItems: [
                URLQueryItem(name: "key", value: "\"\(url)\"")
            ],
            eventLoopGroup: req.eventLoop
        )
        
        guard let bytes = response.body else { throw Abort(.notFound) }
        
        let data = Data(buffer: bytes)
        let decodeResponse = try JSONDecoder().decode(RowsResponse<MyApp>.self, from: data)
        
        guard let myApp = decodeResponse.rows.first?.value else {
            throw Abort(.notFound)
        }
        
        return try await req.view.render("app-page", ["app": myApp])
    }
}
