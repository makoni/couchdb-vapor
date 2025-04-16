// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "HummingbirdTest",
	platforms: [
		.macOS(.v14)
	],
	products: [
		// Products define the executables and libraries a package produces, making them visible to other packages.
		.executable(
			name: "HummingbirdTest",
			targets: ["HummingbirdTest"])
	],
	dependencies: [
		.package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
		.package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
		.package(url: "https://github.com/makoni/couchdb-swift", from: "2.0.0")
	],
	targets: [
		// Targets are the basic building blocks of a package, defining a module or a test suite.
		// Targets can depend on other targets in this package and products from dependencies.
		.executableTarget(
			name: "HummingbirdTest",
			dependencies: [
				.product(name: "ArgumentParser", package: "swift-argument-parser"),
				.product(name: "Hummingbird", package: "hummingbird"), .product(name: "Hummingbird", package: "hummingbird"),
				.product(name: "CouchDBClient", package: "couchdb-swift")
			]),
		.testTarget(
			name: "HummingbirdTestTests",
			dependencies: ["HummingbirdTest"]
		)
	]
)
