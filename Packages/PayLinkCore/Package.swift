// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PayLinkCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PayLinkCore", targets: ["PayLinkCore"])
    ],
    targets: [
        .target(name: "PayLinkCore"),
        .testTarget(name: "PayLinkCoreTests", dependencies: ["PayLinkCore"])
    ]
)
