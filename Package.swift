// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TimeTrack",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TimeTrack", targets: ["TimeTrack"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0")
    ],
    targets: [
        .executableTarget(
            name: "TimeTrack",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "TimeTrack"
        )
    ]
)
