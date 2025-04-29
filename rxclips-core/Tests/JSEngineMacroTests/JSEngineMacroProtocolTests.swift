//
//  JSEngineMicroProtocolTests.swift
//  JSEngine
//
//  Created by Qiwei Li on 2/17/25.
//

import JSEngineMacros
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

private let testMacros: [String: Macro.Type] = [
    "JSBridgeProtocol": JSBridgeProtocolMacro.self
]

final class JSEngineMacroProtocolTests: XCTestCase {
    func testMacroWithoutParameters() throws {
        assertMacroExpansion(
            """
            @JSBridgeProtocol
            @objc public protocol TestApiProtocol: JSExport, APIProtocol {
                func openFolder() async throws -> String
            }
            """,
            expandedSource: """
                @objc public protocol TestApiProtocol: JSExport, APIProtocol {
                    func openFolder() async throws -> String

                    func openFolder() -> JSValue
                }
                """,
            macros: testMacros
        )
    }

    func testMacroWithParameters() throws {
        assertMacroExpansion(
            """
            @JSBridgeProtocol
            @objc public protocol TestApiProtocol: JSExport, APIProtocol {
                func openFolder(name: String) async throws -> String
            }
            """,
            expandedSource: """
                @objc public protocol TestApiProtocol: JSExport, APIProtocol {
                    func openFolder(name: String) async throws -> String

                    func openFolder(_: String) -> JSValue
                }
                """,
            macros: testMacros
        )
    }

    func testMacroWithoutAsync() throws {
        assertMacroExpansion(
            """
            @JSBridgeProtocol
            @objc public protocol TestApiProtocol: JSExport, APIProtocol {
                func openFolder(name: String) -> String
            }
            """,
            expandedSource: """
                @objc public protocol TestApiProtocol: JSExport, APIProtocol {
                    func openFolder(name: String) -> String

                    func openFolder(_: String) -> String
                }
                """,
            macros: testMacros
        )
    }

    func testMacroWithoutAsyncAndWithAsync() throws {
        assertMacroExpansion(
            """
            @JSBridgeProtocol
            @objc public protocol TestApiProtocol: JSExport, APIProtocol {
                func openFolder() -> String
                func openFolder2() async throws -> String
            }
            """,
            expandedSource: """
                @objc public protocol TestApiProtocol: JSExport, APIProtocol {
                    func openFolder() -> String
                    func openFolder2() async throws -> String

                    func openFolder2() -> JSValue
                }
                """,
            macros: testMacros
        )
    }

    func testMacroOnClass() throws {
        assertMacroExpansion(
            """
            @JSBridgeProtocol
            class TestApiClass: NSObject {

            }
            """,
            expandedSource: """
                class TestApiClass: NSObject {

                }
                """,
            diagnostics: [
                .init(
                    message: "JSEngineProtocolMacro must be applied to a protocol", line: 1,
                    column: 1
                )
            ],
            macros: testMacros
        )
    }

    func testMacroWithNamedParameters() throws {
        assertMacroExpansion(
            """
            @JSBridgeProtocol
            @objc public protocol TestApiProtocol: JSExport, APIProtocol {
                func openFolder(fileName: String, path: String) async throws -> String
            }
            """,
            expandedSource: """
                @objc public protocol TestApiProtocol: JSExport, APIProtocol {
                    func openFolder(fileName: String, path: String) async throws -> String

                    func openFolder(_: String, _: String) -> JSValue
                }
                """,
            macros: testMacros
        )
    }

    func testMacroWithoutAsyncNoParameters() throws {
        assertMacroExpansion(
            """
            @JSBridgeProtocol
            @objc public protocol TestApiProtocol: JSExport, APIProtocol {
                func openFolder() -> String
            }
            """,
            expandedSource: """
                @objc public protocol TestApiProtocol: JSExport, APIProtocol {
                    func openFolder() -> String
                }
                """,
            macros: testMacros
        )
    }

    func testMacroWithAsyncNoParameters() throws {
        assertMacroExpansion(
            """
            @JSBridgeProtocol
            @objc public protocol TestApiProtocol: JSExport, APIProtocol {
                func openFolder() async throws -> String
            }
            """,
            expandedSource: """
                @objc public protocol TestApiProtocol: JSExport, APIProtocol {
                    func openFolder() async throws -> String

                    func openFolder() -> JSValue
                }
                """,
            macros: testMacros
        )
    }

    func testMacroWithNamedParameter() throws {
        assertMacroExpansion(
            """
            @JSBridgeProtocol
            @objc public protocol TestApiProtocol: JSExport, APIProtocol {
                func openFolder() async throws -> String
                func getName(name: String) -> String
            }
            """,
            expandedSource: """
                @objc public protocol TestApiProtocol: JSExport, APIProtocol {
                    func openFolder() async throws -> String
                    func getName(name: String) -> String

                    func openFolder() -> JSValue

                    func getName(_: String) -> String
                }
                """,
            macros: testMacros
        )
    }

    func testMacroWithExternalNamedParameter() throws {
        assertMacroExpansion(
            """
            @JSBridgeProtocol
            @objc public protocol TestApiProtocol: JSExport, APIProtocol {
                func getName(with name: String) -> String
            }
            """,
            expandedSource: """
                @objc public protocol TestApiProtocol: JSExport, APIProtocol {
                    func getName(with name: String) -> String

                    func getName(_ name: String) -> String
                }
                """,
            macros: testMacros
        )
    }

    func testMacroWithExternalWithAllUnNamedParameter() throws {
        assertMacroExpansion(
            """
            @JSBridgeProtocol
            @objc public protocol TestApiProtocol: JSExport, APIProtocol {
                func getName(_: String) -> String
            }
            """,
            expandedSource: """
                @objc public protocol TestApiProtocol: JSExport, APIProtocol {
                    func getName(_: String) -> String
                }
                """,
            macros: testMacros
        )
    }

    func testMacroOnFunctionWithoutReturnType() throws {
        assertMacroExpansion(
            """
            @JSBridgeProtocol
            @objc public protocol TestApiProtocol: JSExport, APIProtocol {
                func voidFunction()
            }
            """,
            expandedSource: """
                @objc public protocol TestApiProtocol: JSExport, APIProtocol {
                    func voidFunction()
                }
                """,
            macros: testMacros
        )
    }
}
