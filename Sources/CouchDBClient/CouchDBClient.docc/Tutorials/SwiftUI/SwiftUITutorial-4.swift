import SwiftUI
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

final class MyDoc: Identifiable, CouchDBRepresentable {
	internal init(_id: String = NSUUID().uuidString, _rev: String? = nil, title: String) {
		self._id = _id
		self._rev = _rev
		self.title = title
	}

	let _id: String
	let _rev: String?
	let title: String

	func updateRevision(_ newValue: String) -> MyDoc {
		return MyDoc(_id: _id, _rev: newValue, title: title)
	}

	func updateTitle(_ newValue: String) -> MyDoc {
		return MyDoc(_id: _id, _rev: _rev, title: newValue)
	}
}

struct ContentView: View {
	var body: some View {
		VStack {
			Image(systemName: "globe")
				.imageScale(.large)
				.foregroundStyle(.tint)
			Text("Hello, world!")
		}
		.padding()
	}
}
