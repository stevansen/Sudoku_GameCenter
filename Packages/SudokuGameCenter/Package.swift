// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SudokuGameCenter",
    platforms: [
        .iOS(.v18), .macOS(.v15), .tvOS(.v18), .watchOS(.v11),
    ],
    products: [
        .library(name: "SudokuGameCenter", targets: ["SudokuGameCenter"]),
    ],
    dependencies: [
        .package(path: "../SudokuKit"),
    ],
    targets: [
        .target(
            name: "SudokuGameCenter",
            dependencies: ["SudokuKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SudokuGameCenterTests",
            dependencies: ["SudokuGameCenter"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
