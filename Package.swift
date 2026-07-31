// swift-tools-version: 6.3

import PackageDescription

let package = Package(
	name: "Astral",
	platforms: [
		.macOS(.v14),
		.iOS(.v17)
	],
	products: [
		.library(
			name: "Astral",
			targets: ["Astral"]
		)
	],
	targets: [
		.target(
			name: "Astral",
			dependencies: []
		),
		.testTarget(
			name: "AstralTests",
			dependencies: ["Astral"]
		)
	],
	swiftLanguageModes: [.v6]
)
