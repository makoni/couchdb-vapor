import Foundation
import CouchDBClient
import NIO

let couchDBClient = CouchDBClient(
	couchProtocol: .http,
	couchHost: "127.0.0.1",
	couchPort: 5984,
	userName: "admin",
	userPassword: "yourPassword"
)

let dbName = "fortests"
let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)

struct MyDoc: CouchDBRepresentable, Codable {
	var _id: String?
	var _rev: String?
	var title: String
}

RunLoop.main.run()
