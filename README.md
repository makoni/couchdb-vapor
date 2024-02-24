# CouchDB Client

<p align="center">
	<a href="https://github.com/makoni/couchdb-vapor">
        <img src="https://arm1.ru/img/uploaded/images/CouchDBVapor.png" height="200">
    </a>
</p>

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmakoni%2Fcouchdb-vapor%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/makoni/couchdb-vapor)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmakoni%2Fcouchdb-vapor%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/makoni/couchdb-vapor)
[![Vapor 4](https://img.shields.io/badge/vapor-4.50.0-blue.svg?style=flat)](https://vapor.codes)

[![Build on macOS](https://github.com/makoni/couchdb-vapor/actions/workflows/build-macos.yml/badge.svg?branch=master)](https://github.com/makoni/couchdb-vapor/actions/workflows/build-macos.yml)
[![Build on Ubuntu](https://github.com/makoni/couchdb-vapor/actions/workflows/build-ubuntu.yml/badge.svg?branch=master)](https://github.com/makoni/couchdb-vapor/actions/workflows/build-ubuntu.yml)
[![Test on Ubuntu](https://github.com/makoni/couchdb-vapor/actions/workflows/test-ubuntu.yml/badge.svg?branch=master)](https://github.com/makoni/couchdb-vapor/actions/workflows/test-ubuntu.yml)



This is a simple lib to work with CouchDB in Swift.
- Latest version is based on async/await and requires Swift 5.6 and newer. Works with Vapor 4.50 and newer.
- Version 1.0.0 can be used with Vapor 4 without async/await. Swift 5.3 is required
- You can use the old version for Vapor 3 from vapor3 branch or using version < 1.0.0.  

The only dependency for this lib is <a href="https://github.com/swift-server/async-http-client">async-http-client</a>

## Documentation

You can find docs, examples and even tutorials [here](https://spaceinbox.me/docs/couchdbclient/documentation/couchdbclient). 

## Installation

### Swift Package Manager

Add to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/makoni/couchdb-vapor.git", from: "1.2.0"),
]
```

## Initialization

```swift
// use default params
let myClient = CouchDBClient()

// provide your own params
let couchDBClient = CouchDBClient(
    couchProtocol: .http,
    couchHost: "127.0.0.1",
    couchPort: 5984,
    userName: "admin",
    userPassword: "myPassword"
)
```

If you don’t want to have your password in the code you can pass COUCHDB_PASS param in your command line. For example you can run your Server Side Swift project:
```bash
COUCHDB_PASS=myPassword /path/.build/x86_64-unknown-linux-gnu/release/Run
```
Just use initializer without userPassword param:

```swift
let couchDBClient = CouchDBClient(
    couchProtocol: .http,
    couchHost: "127.0.0.1",
    couchPort: 5984,
    userName: "admin"
)
```

## Usage examples

Define your document model:

```swift
// Example struct
struct ExpectedDoc: CouchDBRepresentable, Codable {
    var name: String
    var _id: String?
    var _rev: String?
}
```

### Insert data
```swift
var testDoc = ExpectedDoc(name: "My name")

try await couchDBClient.insert(
    dbName: "databaseName",
    doc: &testDoc
)

print(testDoc) // testDoc has _id and _rev values now
```

### Update data

```swift
// get data from DB by document ID
var doc: ExpectedDoc = try await couchDBClient.get(dbName: "databaseName", uri: "documentId")
print(doc)

// Update value
doc.name = "Updated name"

try await couchDBClient.update(
    dbName: testsDB,
    doc: &doc
)

print(doc) // doc will have updated name and _rev values now
```

Delete data:

```swift
let response = try await couchDBClient.delete(fromDb: "databaseName", doc: doc)
// or by uri
let response = try await couchDBClient.delete(fromDb: "databaseName", uri: doc._id,rev: doc._rev)
```

Get all DBs example:

```swift
let dbs = try await couchDBClient.getAllDBs()
print(dbs)
// prints: ["_global_changes", "_replicator", "_users", "yourDBname"]
```

Find documents in DB by selector:
```swift
let selector = ["selector": ["name": "Sam"]]
let docs: [ExpectedDoc] = try await couchDBClient.find(in: "databaseName", selector: selector)
print(docs)
```

### Using with Vapor
Here's a simple [tutorial](https://spaceinbox.me/docs/couchdbclient/tutorials/couchdbclient/vaportutorial) for Vapor.

