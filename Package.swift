// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "couchdb-vapor",
	products: [
		// Products define the executables and libraries produced by a package, and make them visible to other packages.
		.library(
			name: "couchdb-vapor",
			targets: ["couchdb-vapor"]),
		],
	dependencies: [
		// 🚀 Non-blocking, event-driven HTTP for Swift built on Swift NIO.
		.package(url: "https://github.com/vapor/http.git", from: "3.0.0"),
	],
	targets: [
		// Targets are the basic building blocks of a package. A target can define a module or a test suite.
		// Targets can depend on other targets in this package, and on products in packages which this package depends on.
		.target(
			name: "couchdb-vapor",
			dependencies: ["HTTP"]),
		.testTarget(
			name: "couchdb-vaporTests",
			dependencies: ["couchdb-vapor"]),
		]
)
