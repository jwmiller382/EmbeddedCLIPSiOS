// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EmbeddedCLIPSiOS",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "EmbeddedCLIPSiOS",
            targets: ["CLIPSEngine"]
        ),
    ],
    targets: [
        // C target: the raw CLIPS engine + C bridge functions
        .target(
            name: "CEmbeddedCLIPS",
            path: "Sources/EmbeddedCLIPSiOS",
            exclude: [],
            sources: ["src"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .define("BUILD_FOR_IOS", to: "1"),
            ]
        ),
        // Swift target: the public API consumers use
        .target(
            name: "CLIPSEngine",
            dependencies: ["CEmbeddedCLIPS"],
            path: "Sources/CLIPSEngine"
        ),
        .testTarget(
            name: "EmbeddedCLIPSiOSTests",
            dependencies: ["CEmbeddedCLIPS"],
            path: "Tests/EmbeddedCLIPSiOSTests"
        ),
        .testTarget(
            name: "CLIPSEngineTests",
            dependencies: ["CLIPSEngine"],
            path: "Tests/CLIPSEngineTests"
        ),
    ],
    cLanguageStandard: .c99
)
