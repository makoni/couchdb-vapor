// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "couchdb-vapor",
	products: [
		.library(name: "CouchDBClient",targets: ["CouchDBClient"]),
	],
	dependencies: [
		.package(url: "https://github.com/swift-server/async-http-client.git", from: "1.1.1")
	],
	targets: [
		.target(
			name: "CouchDBClient",
			dependencies: ["AsyncHTTPClient"]),
		.testTarget(
			name: "CouchDBClientTests",
			dependencies: ["CouchDBClient"]),
		]
)
