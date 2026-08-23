// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SudokuSync",
    platforms: [
        .iOS(.v18), .macOS(.v15), .tvOS(.v18), .watchOS(.v11),
    ],
    products: [
        .library(name: "SudokuSync", targets: ["SudokuSync"]),
    ],
    dependencies: [
        .package(path: "../SudokuKit"),
    ],
    targets: [
        .target(
            name: "SudokuSync",
            dependencies: ["SudokuKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SudokuSyncTests",
            dependencies: ["SudokuSync"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
