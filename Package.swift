// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacDown",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MacDown",
            path: "Sources/MacDown",
            resources: [.copy("Resources")],
            linkerSettings: [
                .linkedFramework("CoreServices"),
                .linkedFramework("WebKit"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        ),
        .testTarget(
            name: "MacDownTests",
            dependencies: ["MacDown"],
            path: "Tests/MacDownTests"
        )
    ]
)
