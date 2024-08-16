// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "ZTNav",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "ZTNav",
            targets: ["ZTNav"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "ZTNav",
            dependencies: []),
    ],
    swiftLanguageVersions: [.v5]
)
