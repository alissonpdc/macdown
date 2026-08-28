// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacDown",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.5.0"),
    ],
    targets: [
        .target(name: "MacDownCore", dependencies: [
            .product(name: "Markdown", package: "swift-markdown"),
        ]),
        .executableTarget(
            name: "MacDown",
            dependencies: ["MacDownCore"],
            path: "Sources/MacDown"
        ),
        .executableTarget(
            name: "plistgen",
            dependencies: ["MacDownCore"],
            path: "Sources/plistgen"
        ),
        .testTarget(name: "MacDownCoreTests", dependencies: ["MacDownCore"]),
    ]
)
