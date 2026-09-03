// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Monday",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Monday",
            targets: ["Monday"]
        ),
        .library(
            name: "MondayCore",
            targets: ["MondayCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MondayCore",
            dependencies: [],
            path: "Sources/MondayCore"
        ),
        .executableTarget(
            name: "Monday",
            dependencies: ["MondayCore"],
            path: "Sources/MondayApp"
        ),
        .executableTarget(
            name: "MondayTests",
            dependencies: ["MondayCore"],
            path: "Tests/MondayTests"
        )
    ]
)
