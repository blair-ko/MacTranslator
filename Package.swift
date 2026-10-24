// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacTranslator",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacTranslator", targets: ["MacTranslator"])
    ],
    targets: [
        .executableTarget(
            name: "MacTranslator",
            path: "Sources/MacTranslator",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("Vision"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit")
            ]
        )
    ]
)
