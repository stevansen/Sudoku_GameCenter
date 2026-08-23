// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SudokuKit",
    platforms: [
        .iOS(.v18), .macOS(.v15), .tvOS(.v18), .watchOS(.v11),
    ],
    products: [
        .library(name: "SudokuKit", targets: ["SudokuKit"]),
    ],
    targets: [
        .target(
            name: "SudokuKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SudokuKitTests",
            dependencies: ["SudokuKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
