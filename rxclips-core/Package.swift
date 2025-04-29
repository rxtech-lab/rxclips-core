// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "rxclips-core",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "rxclips-core",
            targets: ["rxclips-core"]),
        .library(
            name: "JSEngine",
            targets: ["JSEngine", "JSEngineMacro"]
        ),
        .library(
            name: "JSEngineMacro",
            targets: ["JSEngineMacro"]
        ),
        .library(name: "Common", targets: ["Common"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0-latest")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "rxclips-core"),
        .testTarget(
            name: "rxclips-coreTests",
            dependencies: ["rxclips-core"]
        ),
        .target(
            name: "Common"
        ),
        .macro(
            name: "JSEngineMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(name: "JSEngineMacro", dependencies: ["JSEngineMacros"]),
        .target(
            name: "JSEngine",
            dependencies: ["Common"]
        ),
        .testTarget(
            name: "JSEngineTests",
            dependencies: ["JSEngine", "JSEngineMacro"]
        ),
        .testTarget(
            name: "JSEngineMacroTests",
            dependencies: [
                "JSEngineMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
