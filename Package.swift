// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EstudioCamara",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "EstudioCamara", targets: ["EstudioCamara"])
    ],
    targets: [
        .executableTarget(
            name: "EstudioCamara",
            path: "Sources/EstudioCamara",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreImage"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Vision")
            ]
        )
    ]
)
