// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SugarImage",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SugarImage", targets: ["SugarImage"])
    ],
    targets: [
        .target(name: "SugarImage")
    ]
)
