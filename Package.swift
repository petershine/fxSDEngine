// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "fxdSDAPIclient",
	platforms: [
		.iOS(.v17),
	],
	products: [
		// Products define the executables and libraries a package produces, making them visible to other packages.
		.library(
			name: "fXDKit",
			targets: ["fXDKit"]),
		.library(
			name: "fxdSDAPIclient",
			targets: ["fxdSDAPIclient"]),
		.library(
			name: "fxdSDAPIclientBasicUI",
			targets: ["fxdSDAPIclientBasicUI"]),
	],
	targets: [
		// Targets are the basic building blocks of a package, defining a module or a test suite.
		// Targets can depend on other targets in this package and products from dependencies.
		.target(
			name: "fXDKit"
		),
		.target(
			name: "fxdSDAPIclient",
			dependencies: ["fXDKit"]
		),
		.target(
			name: "fxdSDAPIclientBasicUI",
			dependencies: ["fXDKit", "fxdSDAPIclient"]
		),
		.testTarget(
			name: "fxdSDAPIclientTests",
			dependencies: ["fxdSDAPIclient"]),
	]
)
