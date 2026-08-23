// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SudokuUI",
    defaultLocalization: "de",
    platforms: [
        .iOS(.v18), .macOS(.v15), .tvOS(.v18), .watchOS(.v11), .visionOS(.v2),
    ],
    products: [
        .library(name: "SudokuUI", targets: ["SudokuUI"]),
    ],
    dependencies: [
        .package(path: "../SudokuKit"),
    ],
    targets: [
        .target(
            name: "SudokuUI",
            dependencies: ["SudokuKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SudokuUITests",
            dependencies: ["SudokuUI"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
