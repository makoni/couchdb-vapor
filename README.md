# CouchDB Client for Vapor

<p align="center">
	<a href="https://github.com/makoni/couchdb-vapor">
        <img src="https://arm1.ru/img/uploaded/images/CouchDBVapor.png" height="200">
    </a>
</p>

[![Platforms](https://img.shields.io/badge/platforms-macOS%2012%20|%20Ubuntu%20|%20iOS%2015-ff0000.svg?style=flat)](https://github.com/makoni/couchdb-vapor)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-4BC51D.svg?style=flat)](https://swift.org/package-manager/)
[![Swift 5](https://img.shields.io/badge/swift-5.5-orange.svg?style=flat)](http://swift.org)
[![Vapor 3](https://img.shields.io/badge/vapor-4.50.0-blue.svg?style=flat)](https://vapor.codes)



This is simple lib to work with CouchDB in Swift.
- Latest version is based on async/await and requires Swift 5.5 and newer.
- Version 1.0.0 can be used with Vapor 4 without async/await. Swift 5.3 is required
- You can use old version for Vapor 3 from vapor3 branch or using version < 1.0.0. 

The only depndency for this lib is <a href="https://github.com/swift-server/async-http-client">async-http-client</a>

## Installation

### Swift Package Manager

Add to the `dependencies` value of your `Package.swift`.

#### Swift 5

```swift
dependencies: [
    .package(url: "https://github.com/makoni/couchdb-vapor.git", from: "1.1.0"),
]
```

## Usage

Get data In Vapor 4 routes:

```swift
// using default settings
let couchDBClient = CouchDBClient()
// providing settings
let couchDBClient2 = CouchDBClient(couchProtocol: .http, couchHost: "127.0.0.1", couchPort: 5984, userName: "username", userPassword: "userpass")

// Sample document model
struct ExpectedDoc: Codable {
    var name: String
    var _id: String
    var _rev: String
}

// Sample view data
struct PageData: Content {
    let title: String
}

func routes(_ app: Application) throws {
    app.get(":docId") { req async throws -> View in
        let docId = req.parameters.get("docId")!

        let couchResponse = try await couchDBClient.get(dbName: "yourDBname", uri: docId, worker: req.eventLoop)

        guard let body = response.body, let bytes = body.readBytes(length: body.readableBytes) else { throw Abort(.notFound) }

        let data = Data(bytes)		
        let doc = try JSONDecoder().decode(ExpectedDoc.self, from: data)

        let pageData = PageData(
            title: doc.name
        )
	
        return try await req.view().render("view-name", pageData)
    }
}
```

Insert data example:

```swift
let testData = [name: "some name"]

let data = try JSONEncoder().encode(testData)

let response = try await couchDBClient.insert(dbName: "yourDBname", body: HTTPBody(data: data), worker: req.eventLoop)
print(response)
// prints: CouchDBClient.CouchUpdateResponse(ok: true, id: "0a1eea865fdec7a00afb96685001c7be", rev: "1-e6bde9e60844ba5648cc61b446f9f4b3"))
```

Update data example:

```swift
let updatedData = ExpectedDoc(name: "some new name", _id: "0a1eea865fdec7a00afb96685001c7be", _rev: "1-e6bde9e60844ba5648cc61b446f9f4b3")

let data = try JSONEncoder().encode(testData)

let response = try await couchDBClient.update(dbName: "yourDBname", uri: updatedData._id, body: HTTPBody(data: data), worker: req.eventLoop)
print(response)
// prints: CouchDBClient.CouchUpdateResponse(ok: true, id: "0a1eea865fdec7a00afb96685001c7be", rev: "1-e6bde9e60844ba5648cc61b446f9f4b4"))
```

Delete data example:

```swift
let updatedData = ExpectedDoc(name: "some new name", _id: "0a1eea865fdec7a00afb96685001c7be", _rev: "1-e6bde9e60844ba5648cc61b446f9f4b4")

let data = try JSONEncoder().encode(testData)

let response = try await couchDBClient.delete(fromDb: "yourDBname", uri: updatedData._id, rev: updatedData._rev, worker: req.eventLoop)
print(response)
// prints: CouchDBClient.CouchUpdateResponse(ok: true, id: "0a1eea865fdec7a00afb96685001c7be", rev: "1-e6bde9e60844ba5648cc61b446f9f4b5"))
```

Get all DBs example:

```swift

let dbs = try await couchDBClient.getAllDBs(worker: req.eventLoop)

print(dbs)
// prints: ["_global_changes", "_replicator", "_users", "yourDBname"]
```
