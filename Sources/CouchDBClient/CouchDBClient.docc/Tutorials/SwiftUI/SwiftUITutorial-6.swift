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

@MainActor
@Observable final class DocsStore {
	var docs = [MyDoc]()

	func getDocs() async throws {
		let response = try await couchDBClient.get(
			fromDB: dbName,
			uri: "_design/all/_view/list"
		)

		let expectedBytes =
			response.headers
			.first(name: "content-length")
			.flatMap(Int.init) ?? 1024 * 1024 * 10
		var bytes = try await response.body.collect(upTo: expectedBytes)

		guard let data = bytes.readData(length: bytes.readableBytes) else { return }

		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .secondsSince1970

		let decodeResponse = try decoder.decode(RowsResponse<MyDoc>.self, from: data)

		docs = decodeResponse.rows.map({ $0.value })
	}
}

struct ContentView: View {
	@State var docsStore = DocsStore()
	var body: some View {
		VStack {
			Image(systemName: "globe")
				.imageScale(.large)
				.foregroundStyle(.tint)
			Text("Hello, world!")

			List(docsStore.docs) { doc in
				Text(doc.title)
			}
		}
		.padding()
		.task {
			do {
				try await docsStore.getDocs()
			} catch {
				print(error.localizedDescription)
			}
		}
	}
}
