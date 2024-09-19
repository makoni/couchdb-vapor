// swift-tools-version:5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "couchdb-vapor",
	platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
	products: [
		// Products define the executables and libraries a package produces, and make them visible to other packages.
		.library(name: "CouchDBClient", targets: ["CouchDBClient"]),
	],
	dependencies: [
		.package(url: "https://github.com/swift-server/async-http-client.git", from: "1.21.0"),
		.package(url: "https://github.com/swiftlang/swift-docc-plugin.git", from: "1.3.0")
	],
	targets: [
		// Targets are the basic building blocks of a package. A target can define a module or a test suite.
		// Targets can depend on other targets in this package, and on products in packages this package depends on.
		.target(
			name: "CouchDBClient",
			dependencies: [
				.product(name: "AsyncHTTPClient", package: "async-http-client")
			]),
		.testTarget(
			name: "CouchDBClientTests",
			dependencies: ["CouchDBClient"]),
	]
)
