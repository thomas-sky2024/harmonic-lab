// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HarmonicLab",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "HarmonicLab", targets: ["HarmonicLab"])],
    targets: [
        .target(name: "HarmonicCore"),
        .executableTarget(name: "HarmonicLab", dependencies: ["HarmonicCore"]),
        .testTarget(name: "HarmonicCoreTests", dependencies: ["HarmonicCore"])
    ]
)
