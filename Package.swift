// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PRNeko",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "PRNeko",
            path: "Sources/PRNeko",
            exclude: ["Resources", "Assets"],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        )
    ]
)
