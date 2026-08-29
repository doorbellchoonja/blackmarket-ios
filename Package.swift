// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BlackMarket",
    platforms: [.iOS(.v15)],
    products: [
        .executable(name: "BlackMarket", targets: ["BlackMarket"])
    ],
    targets: [
        .executableTarget(
            name: "BlackMarket",
            path: "Sources"
        )
    ]
)
