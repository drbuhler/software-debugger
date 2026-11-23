// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "HamsterInfestation",
    products: [
        .executable(name: "HamsterInfestation", targets: ["HamsterInfestation"]),
        .library(name: "HamsterCore", targets: ["HamsterCore"]),
    ],
    targets: [
        .target(name: "HamsterCore"),
        .executableTarget(
            name: "HamsterInfestation",
            dependencies: ["HamsterCore"],
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "HamsterCoreTests",
            dependencies: ["HamsterCore"]
        ),
    ]
)
