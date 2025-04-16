# CouchDB Client for Swift

<p align="center">
	<a href="https://github.com/makoni/couchdb-swift">
        <img src="https://spaceinbox.me/images/appicons/5cff134d1bb4a2e90faea5cf4e0002a2.svg?31-a992eba6ad7e189f4b3e0988936056ca" height="200">
    </a>
</p>

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmakoni%2Fcouchdb-swift%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/makoni/couchdb-swift)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmakoni%2Fcouchdb-swift%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/makoni/couchdb-swift)
[![Vapor 4](https://img.shields.io/badge/vapor-4-blue.svg?style=flat)](https://vapor.codes)

[![Build on macOS](https://github.com/makoni/couchdb-swift/actions/workflows/build-macos.yml/badge.svg?branch=master)](https://github.com/makoni/couchdb-swift/actions/workflows/build-macos.yml)
[![Build on Ubuntu](https://github.com/makoni/couchdb-swift/actions/workflows/build-ubuntu.yml/badge.svg?branch=master)](https://github.com/makoni/couchdb-swift/actions/workflows/build-ubuntu.yml)
[![Test on Ubuntu](https://github.com/makoni/couchdb-swift/actions/workflows/test-ubuntu.yml/badge.svg?branch=master)](https://github.com/makoni/couchdb-swift/actions/workflows/test-ubuntu.yml)



This is a simple library to work with CouchDB in Swift.

- The latest version supports strict concurrency: `CouchDBClient` is an actor and requires Swift 6.0 or newer. For Swift 5, you can still use version `1.7.0`.
- Compatible with Vapor 4.
- Version `1.0.0` can be used with Vapor 4 without `async/await`; Swift 5.3 is required.
- You can use the old version for Vapor 3 by checking out the `vapor3` branch or using versions earlier than `1.0.0`.

The only dependency for this library is [`async-http-client`](https://github.com/swift-server/async-http-client).

---

## Documentation

Find documentation, examples, and tutorials [here](https://spaceinbox.me/docs/couchdbclient/documentation/couchdbclient).

---

## Installation

### Swift Package Manager

Add the following to the `dependencies` section of your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/makoni/couchdb-swift.git", from: "2.1.0"),
]
```

---

## Initialization

```swift
let config = CouchDBClient.Config(
    couchProtocol: .http,
    couchHost: "127.0.0.1",
    couchPort: 5984,
    userName: "admin",
    userPassword: "",
    requestsTimeout: 30
)
let couchDBClient = CouchDBClient(config: config)
```

To avoid hardcoding your password, you can pass the COUCHDB_PASS parameter via the command line. For example, you can run your server-side Swift project as follows:
```bash
COUCHDB_PASS=myPassword /path/.build/x86_64-unknown-linux-gnu/release/Run
```
In this case, use the initializer without the userPassword parameter:

```swift
let config = CouchDBClient.Config(
    couchProtocol: .http,
    couchHost: "127.0.0.1",
    couchPort: 5984,
    userName: "admin",
    requestsTimeout: 30
)
let couchDBClient = CouchDBClient(config: config)
```

## Usage examples

### Define Your Document Model

```swift
// Example struct
struct ExpectedDoc: CouchDBRepresentable {
    var name: String
    var _id: String = NSUUID().uuidString
    var _rev: String?

    func updateRevision(_ newRevision: String) -> Self {
        return ExpectedDoc(name: name, _id: _id, _rev: newRevision)
    }
}
```

### Insert Data

```swift
var testDoc = ExpectedDoc(name: "My name")

testDoc = try await couchDBClient.insert(
    dbName: "databaseName",
    doc: testDoc
)

print(testDoc) // testDoc has _id and _rev values now
```

### Update Data

```swift
// get data from a database by document ID
var doc: ExpectedDoc = try await couchDBClient.get(fromDB: "databaseName", uri: "documentId")
print(doc)

// Update value
doc.name = "Updated name"

doc = try await couchDBClient.update(
    dbName: testsDB,
    doc: doc
)

print(doc) // doc will have updated name and _rev values now
```

### Delete Data

```swift
let response = try await couchDBClient.delete(fromDb: "databaseName", doc: doc)
// or by uri
let response = try await couchDBClient.delete(fromDb: "databaseName", uri: doc._id,rev: doc._rev)
```

### Get All Databases

```swift
let dbs = try await couchDBClient.getAllDBs()
print(dbs)
// prints: ["_global_changes", "_replicator", "_users", "yourDBname"]
```

### Find Documents in a Database by Selector
```swift
let selector = ["selector": ["name": "Sam"]]
let docs: [ExpectedDoc] = try await couchDBClient.find(in: "databaseName", selector: selector)
print(docs)
```

### Using with Vapor
Here's a simple [tutorial](https://spaceinbox.me/docs/couchdbclient/tutorials/couchdbclient/vaportutorial) for Vapor.

