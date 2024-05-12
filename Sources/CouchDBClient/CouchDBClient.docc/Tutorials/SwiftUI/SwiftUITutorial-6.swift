import SwiftUI
import CouchDBClient

let couchDBClient = CouchDBClient(
    couchProtocol: .http,
    couchHost: "127.0.0.1",
    couchPort: 5984,
    userName: "admin",
    userPassword: "yourPassword"
)

let dbName = "fortests"

class MyDoc: Identifiable, CouchDBRepresentable {
    var _id: String?
    var _rev: String?
    var title: String
}

@Observable class DocsStore {
    var docs = [MyDoc]()

    func getDocs() async throws {
        let response = try await couchDBClient.get(
            fromDB: dbName,
            uri: "_design/all/_view/list"
        )

        let expectedBytes = response.headers
            .first(name: "content-length")
            .flatMap(Int.init) ?? 1024 * 1024 * 10
        var bytes = try await response.body.collect(upTo: expectedBytes)

        guard let data = bytes.readData(length: bytes.readableBytes) else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let decodeResponse = try decoder.decode(RowsResponse<MyDoc>.self, from: data)

        await MainActor.run { [self] in
            docs = decodeResponse.rows.map({ $0.value })
        }
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
