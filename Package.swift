// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "Tentacles",
    platforms: [
        .iOS(.v10)
    ],
    products: [
        .library(name: "Tentacles", targets: ["Tentacles"])
    ],
    targets: [
        .target(name: "Tentacles", path: "Tentacles"),
        .testTarget(name: "TentaclesTests", dependencies: ["Tentacles"], path: "TentaclesTests")
    ]
)
