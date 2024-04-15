import SwiftUI
import CouchDBClient

struct ContentView: View {
    @State var docsStore = DocsStore()
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
