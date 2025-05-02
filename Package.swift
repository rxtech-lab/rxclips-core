// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "RxClipsCore",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "RxClipsCore",
            targets: ["RxClipsCore"]),
        .library(
            name: "JSEngine",
            targets: ["JSEngine", "JSEngineMacro"]
        ),
        .library(
            name: "JSEngineMacro",
            targets: ["JSEngineMacro"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0-latest"),
        .package(url: "https://github.com/sirily11/swift-json-schema", from: "1.0.2"),
        .package(url: "https://github.com/jpsim/Yams", from: "5.3.1"),
        .package(url: "https://github.com/stencilproject/Stencil", from: "0.15.1"),
        .package(url: "https://github.com/SwiftGen/StencilSwiftKit", from: "2.10.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.92.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "RxClipsCore",
            dependencies: [
                .product(name: "JSONSchema", package: "swift-json-schema"),
                .product(name: "Stencil", package: "Stencil"),
                .product(name: "StencilSwiftKit", package: "StencilSwiftKit"),
            ]
        ),
        .testTarget(
            name: "RxClipsCoreTests",
            dependencies: [
                "RxClipsCore",
                .product(name: "Yams", package: "Yams"),
                .product(name: "Vapor", package: "vapor"),
            ]
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
            dependencies: []
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
