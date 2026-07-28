// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VirtualPM5",
    platforms: [
        .iOS(.v17), .tvOS(.v17), .watchOS(.v10), .macOS(.v13),
    ],
    products: [
        .library(name: "VirtualPM5", targets: ["VirtualPM5"]),
    ],
    targets: [
        .target(name: "VirtualPM5"),
        .testTarget(
            name: "VirtualPM5Tests",
            dependencies: ["VirtualPM5"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
