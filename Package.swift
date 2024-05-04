// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "fxdSDEngine",
	platforms: [
		.iOS(.v17),
	],
	products: [
		// Products define the executables and libraries a package produces, making them visible to other packages.
		.library(
			name: "fxdSDEngine",
			targets: ["fxdSDEngine"]),
		.library(
			name: "fxdSDEngineBasicUI",
			targets: ["fxdSDEngineBasicUI"]),
	],
	dependencies: [
		// Dependencies declare other packages that this package depends on.
		.package(url: "https://github.com/petershine/fXDKit", .upToNextMajor(from: "1.0.1")),
	],
	targets: [
		// Targets are the basic building blocks of a package, defining a module or a test suite.
		// Targets can depend on other targets in this package and products from dependencies.
		.target(
			name: "fxdSDEngine",
			dependencies: ["fXDKit"]
		),
		.target(
			name: "fxdSDEngineBasicUI",
			dependencies: ["fxdSDEngine", "fXDKit"]
		),
		.testTarget(
			name: "fxdSDEngineTests",
			dependencies: ["fxdSDEngine", "fXDKit"]),
	]
)
