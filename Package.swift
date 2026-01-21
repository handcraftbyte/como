// swift-tools-version: 5.10

import PackageDescription

let package = Package(
	name: "Como",
	platforms: [
		.macOS(.v14),
	],
	products: [
		.executable(name: "Como", targets: ["ComoApp"]),
	],
	dependencies: [
		// ChimeHQ core libraries
		.package(url: "https://github.com/ChimeHQ/Neon", branch: "main"),
		.package(url: "https://github.com/ChimeHQ/IBeam", branch: "main"),
		.package(url: "https://github.com/ChimeHQ/TextFormation", branch: "main"),
		.package(url: "https://github.com/ChimeHQ/Ligature", branch: "main"),
		.package(url: "https://github.com/ChimeHQ/ThemePark", branch: "main"),
		// Tree-sitter parsers for syntax highlighting (SPM-compatible)
		// Note: Using TypeScript parser for both JS and TS (tree-sitter-javascript has broken SPM package)
		.package(url: "https://github.com/tree-sitter/tree-sitter-typescript", branch: "master"),
		.package(url: "https://github.com/alex-pinkus/tree-sitter-swift", branch: "with-generated-files"),
		.package(url: "https://github.com/tree-sitter/tree-sitter-json", branch: "master"),
	],
	targets: [
		.executableTarget(
			name: "ComoApp",
			dependencies: [
				"Neon",
				"IBeam",
				"TextFormation",
				"Ligature",
				"ThemePark",
				.product(name: "TreeSitterTypeScript", package: "tree-sitter-typescript"),
				.product(name: "TreeSitterSwift", package: "tree-sitter-swift"),
				.product(name: "TreeSitterJSON", package: "tree-sitter-json"),
			],
			path: "Sources"
		),
		.testTarget(
			name: "ComoTests",
			dependencies: ["ComoApp"],
			path: "Tests"
		),
	]
)
