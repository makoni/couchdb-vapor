import Foundation
import CouchDBClient

let config = CouchDBClient.Config(
	couchProtocol: .http,
	couchHost: "127.0.0.1",
	couchPort: 5984,
	userName: "admin",
	userPassword: "yourPassword"
)
let couchDBClient = CouchDBClient(config: config)

let dbName = "fortests"

struct MyDoc: CouchDBRepresentable {
	var _id: String = NSUUID().uuidString
	var _rev: String?
	var title: String

	func updateRevision(_ newRevision: String) -> Self {
		return MyDoc(_id: _id, _rev: newRevision, title: title)
	}
}

RunLoop.main.run()
