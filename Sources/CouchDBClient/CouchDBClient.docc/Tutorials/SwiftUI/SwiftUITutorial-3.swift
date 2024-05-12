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
