// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Maestro",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "maestro-cli", targets: ["MaestroCLI", "Maestro"]),
        .library(name: "Maestro", targets: ["Maestro"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        .package(url: "https://github.com/rdingman/swift-subprocess.git", branch: "rdingman/issue-39"),
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0"),
//        .package(url: "https://github.com/apple/swift-log", from: "1.6.0"),
//        .package(url: "https://github.com/swiftlang/swift-subprocess.git", branch: "main")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Maestro",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Subprocess", package: "swift-subprocess"),
            ],
            path: "Sources/Maestro"
        ),
        .executableTarget(
            name: "MaestroCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "Maestro"
            ],
            path: "Sources/MaestroCLI"
        ),
        .executableTarget(
            name: "ChromeTest",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "Maestro"
            ],
            path: "Sources/ChromeTest",
//            swiftSettings: [
//              .enableUpcomingFeature("TupleConformances"),
//              .enableExperimentalFeature("TupleConformances")
//            ],
        ),
    ]
)
