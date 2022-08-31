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

Task {
	var doc = MyDoc(title: "My Document")
	try await couchDBClient.insert(dbName: dbName, doc: &doc, worker: worker)
	print(doc)

	doc.title = "Updated title"
	try await couchDBClient.update(dbName: dbName, doc: &doc, worker: worker)
	print(doc)

	let docFromDB: MyDoc = try await couchDBClient.get(dbName: dbName, uri: doc._id!, worker: worker)
	print(docFromDB)
}

RunLoop.main.run()