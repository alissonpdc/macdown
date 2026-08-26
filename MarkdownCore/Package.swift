// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MarkdownCore",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.5.0"),
    ],
    targets: [
        .target(name: "MarkdownCore", dependencies: [
            .product(name: "Markdown", package: "swift-markdown"),
        ]),
        .testTarget(name: "MarkdownCoreTests", dependencies: ["MarkdownCore"]),
    ]
)
