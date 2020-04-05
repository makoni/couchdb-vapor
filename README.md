# CouchDB Client for Vapor

<p align="center">
	<a href="https://github.com/makoni/couchdb-vapor">
        <img src="https://arm1.ru/img/uploaded/images/CouchDBVapor.png" height="200">
    </a>
</p>

[![Platforms](https://img.shields.io/badge/platforms-macOS%2010.13%20|%20Ubuntu%2016.04%20LTS-ff0000.svg?style=flat)](https://github.com/makoni/couchdb-vapor)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-4BC51D.svg?style=flat)](https://swift.org/package-manager/)
[![Swift 5](https://img.shields.io/badge/swift-5.0-orange.svg?style=flat)](http://swift.org)
[![Vapor 3](https://img.shields.io/badge/vapor-3.0-blue.svg?style=flat)](https://vapor.codes)



This is simple lib to work with CouchDB with Vapor Framework. This branch contains version that supports Vapor 3 version only.

## Installation

### Swift Package Manager

Add to the `dependencies` value of your `Package.swift`.

#### Swift 5

```swift
dependencies: [
	.package(url: "https://github.com/makoni/couchdb-vapor.git", branch: "vapor3"),
]
```

## Usage

Get data In Vapor routes:

```swift
let couchDBClient = CouchDBClient()

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

/// Register your application's routes here.
public func routes(_ router: Router) throws {
	router.get(String.parameter) { req -> Future<View> in
		let docId = req.parameters.next(String.self)
		
		let couchResponse = try couchDBClient.get(dbName: "yourDBname", uri: docId, worker: req)
		guard couchResponse != nil else {
			throw Abort(.notFound)
		}
		
		return couchResponse!.flatMap({ (response) -> EventLoopFuture<View> in
			guard let data = response.body.data else { throw Abort(.notFound) }
		
			let decoder = JSONDecoder()
			let doc = try decoder.decode(ExpectedDoc.self, from: data)
		
			let pageData = PageData(
				title: doc.name
			)
		
			return try req.view().render("view-name", pageData)
		})
	}
}
```

Insert data example:

```swift
let testData = [name: "some name"]

let encoder = JSONEncoder()
let data = try encoder.encode(testData)

let response = try couchDBClient.insert(dbName: "yourDBname", body: HTTPBody(data: data), worker: req)?.wait()
print(response)
// prints: CouchDBClient.CouchUpdateResponse(ok: true, id: "0a1eea865fdec7a00afb96685001c7be", rev: "1-e6bde9e60844ba5648cc61b446f9f4b3"))
```

Update data example:

```swift
let updatedData = ExpectedDoc(name: "some new name", _id: "0a1eea865fdec7a00afb96685001c7be", _rev: "1-e6bde9e60844ba5648cc61b446f9f4b3")

let encoder = JSONEncoder()
let data = try encoder.encode(testData)

let response = try couchDBClient.update(dbName: "yourDBname", uri: updatedData._id, body: HTTPBody(data: data), worker: req)?.wait()
print(response)
// prints: CouchDBClient.CouchUpdateResponse(ok: true, id: "0a1eea865fdec7a00afb96685001c7be", rev: "1-e6bde9e60844ba5648cc61b446f9f4b4"))
```

Delete data example:

```swift
let updatedData = ExpectedDoc(name: "some new name", _id: "0a1eea865fdec7a00afb96685001c7be", _rev: "1-e6bde9e60844ba5648cc61b446f9f4b4")

let encoder = JSONEncoder()
let data = try encoder.encode(testData)

let response = try couchDBClient.delete(fromDb: "yourDBname", uri: updatedData._id, rev: updatedData._rev, worker: req)?.wait()
print(response)
// prints: CouchDBClient.CouchUpdateResponse(ok: true, id: "0a1eea865fdec7a00afb96685001c7be", rev: "1-e6bde9e60844ba5648cc61b446f9f4b5"))
```

Get all DBs example:

```swift

let response = try couchDBClient.getAllDBs(worker: req).wait()
guard let dbs = response else {
	throw Abort(.notFound)
}

print(dbs)
// prints: ["_global_changes", "_replicator", "_users", "yourDBname"]
```
