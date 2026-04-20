// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "Tempo",
    platforms: [.iOS(.v17)],
    products: [],
    dependencies: [
        .package(url: "https://github.com/google/google-signin-ios-spm", from: "7.0.0"),
        .package(url: "https://github.com/googleapis/google-apis-ios-sdk", from: "3.0.0"),
    ]
)
