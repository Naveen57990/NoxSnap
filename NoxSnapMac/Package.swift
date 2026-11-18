// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NoxSnap",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NoxSnap", targets: ["NoxSnap"])
    ],
    targets: [
        .executableTarget(
            name: "NoxSnap",
            path: "Sources/NoxSnap",
            swiftSettings: [
                .unsafeFlags(["-suppress-warnings"])
            ]
        )
    ]
)
