// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Kiesel",
    defaultLocalization: "de",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KieselCore", targets: ["KieselCore"]),
        .executable(name: "Kiesel", targets: ["KieselApp"]),
    ],
    targets: [
        .target(name: "KieselCore"),
        .executableTarget(name: "KieselApp", dependencies: ["KieselCore"],
                          resources: [.copy("Resources/AppIcon.png")]),
        .testTarget(name: "KieselCoreTests", dependencies: ["KieselCore"]),
    ]
)
