// swift-tools-version:5.10
import PackageDescription

let package = Package(
	name: "spaceinbox.me",
	platforms: [
	   .macOS(.v13)
	],
	dependencies: [
		// 💧 A server-side Swift web framework.
		.package(url: "https://github.com/vapor/vapor", from: "4.0.0"),
		.package(url: "https://github.com/vapor/leaf", from: "4.0.0"),
	],
	targets: [
		.target(
			name: "App",
			dependencies: [
				.product(name: "Leaf", package: "leaf"),
				.product(name: "Vapor", package: "vapor"),
			]
		),
		.executableTarget(name: "Run", dependencies: [.target(name: "App")]),
		.testTarget(name: "AppTests", dependencies: [
			.target(name: "App"),
			.product(name: "XCTVapor", package: "vapor"),
		])
	]
)
