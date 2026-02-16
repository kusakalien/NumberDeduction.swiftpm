// swift-tools-version: 6.0

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "NumberDeduction",
    platforms: [
        .iOS("18.0")
    ],
    products: [
        .iOSApplication(
            name: "NumberDeduction",
            targets: ["AppModule"],
            bundleIdentifier: "com.example.NumberDeduction",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .heart),
            accentColor: .presetColor(.indigo),
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "Sources"
        )
    ]
)
