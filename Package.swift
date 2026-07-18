// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacClipboard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacClipboard", targets: ["MacClipboard"]),
        .executable(name: "MacClipboardSelfTests", targets: ["MacClipboardSelfTests"])
    ],
    targets: [
        .target(name: "MacClipboardCore"),
        .executableTarget(
            name: "MacClipboard",
            dependencies: ["MacClipboardCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon")
            ]
        ),
        .executableTarget(
            name: "MacClipboardSelfTests",
            dependencies: ["MacClipboardCore"]
        )
    ],
    swiftLanguageModes: [.v5]
)
