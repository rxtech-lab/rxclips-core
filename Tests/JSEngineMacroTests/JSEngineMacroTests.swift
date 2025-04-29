import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(JSEngineMacros)
    import JSEngineMacros

    private let testMacros: [String: Macro.Type] = [
        "JSBridgeMacro": JSBridgeMacro.self
    ]
#endif

final class JSEngineMacroTests: XCTestCase {
    func testAsyncMacroWithoutParameters() throws {
        assertMacroExpansion(
            """
            @JSBridgeMacro
            class TestApi: NSObject, TestApiProtocol {
                func openFolder() async throws -> String {
                    return "/path/to/folder"
                }
            }
            """,
            expandedSource: """
                class TestApi: NSObject, TestApiProtocol {
                    func openFolder() async throws -> String {
                        return "/path/to/folder"
                    }

                    private func resolveOpenfolder(with value: String) {
                        context.globalObject.setObject(value, forKeyedSubscript: "openFolderResult" as NSString)
                        context.evaluateScript("resolveOpenfolder(openFolderResult);")
                    }

                    private func rejectOpenfolder(with error: Error) {
                        context.globalObject.setObject(
                            error.localizedDescription, forKeyedSubscript: "errorMessage" as NSString)
                        context.evaluateScript("rejectOpenfolder(new Error(errorMessage));")
                    }

                    func openFolder() -> JSValue {
                        let promise = context.evaluateScript(
                            \"\"\"
                                new Promise((resolve, reject) => {
                                    globalThis.resolveOpenfolder = resolve;
                                    globalThis.rejectOpenfolder = reject;
                                });
                            \"\"\")!

                        Task {
                            do {
                                let result = try await openFolder()
                                resolveOpenfolder(with: result)
                            } catch {
                                rejectOpenfolder(with: error)
                            }
                        }

                        return promise
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testAsyncMacroWithParameters() throws {
        assertMacroExpansion(
            """
            @JSBridgeMacro
            class TestApi: NSObject, TestApiProtocol {
                func openFolder(name: String) async throws -> String {
                    return "/path/to/folder"
                }
            }
            """,
            expandedSource: """
                class TestApi: NSObject, TestApiProtocol {
                    func openFolder(name: String) async throws -> String {
                        return "/path/to/folder"
                    }

                    private func resolveOpenfolder(with value: String) {
                        context.globalObject.setObject(value, forKeyedSubscript: "openFolderResult" as NSString)
                        context.evaluateScript("resolveOpenfolder(openFolderResult);")
                    }

                    private func rejectOpenfolder(with error: Error) {
                        context.globalObject.setObject(
                            error.localizedDescription, forKeyedSubscript: "errorMessage" as NSString)
                        context.evaluateScript("rejectOpenfolder(new Error(errorMessage));")
                    }

                    func openFolder(_ name: String) -> JSValue {
                        let promise = context.evaluateScript(
                            \"\"\"
                                new Promise((resolve, reject) => {
                                    globalThis.resolveOpenfolder = resolve;
                                    globalThis.rejectOpenfolder = reject;
                                });
                            \"\"\")!

                        Task {
                            do {
                                let result = try await openFolder(name: name)
                                resolveOpenfolder(with: result)
                            } catch {
                                rejectOpenfolder(with: error)
                            }
                        }

                        return promise
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testMacroWithoutAsyncFunctionAndNamedParameter() throws {
        assertMacroExpansion(
            """
            @JSBridgeMacro
            class TestApi: NSObject, TestApiProtocol {
                func openFolder(name: String) -> String {
                    return "/path/to/folder"
                }
            }
            """,
            expandedSource: """
                class TestApi: NSObject, TestApiProtocol {
                    func openFolder(name: String) -> String {
                        return "/path/to/folder"
                    }

                    func openFolder(_ name: String) -> String {
                        return openFolder(name: name)
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testMacroWithoutAsyncFunctionAndAllUnnamedParameter() throws {
        assertMacroExpansion(
            """
            @JSBridgeMacro
            class TestApi: NSObject, TestApiProtocol {
                func openFolder(_ name: String) -> String {
                    return "/path/to/folder"
                }
            }
            """,
            expandedSource: """
                class TestApi: NSObject, TestApiProtocol {
                    func openFolder(_ name: String) -> String {
                        return "/path/to/folder"
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testMacroWithoutAsyncFunctionAndThrows() throws {
        assertMacroExpansion(
            """
            @JSBridgeMacro
            class TestApi: NSObject, TestApiProtocol {
                func openFolder(_ name: String) throws -> String {
                    return "/path/to/folder"
                }
            }
            """,
            expandedSource: """
                class TestApi: NSObject, TestApiProtocol {
                    func openFolder(_ name: String) throws -> String {
                        return "/path/to/folder"
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testMacroWithoutAsyncFunctionAndSomeUnnamedParameter() throws {
        assertMacroExpansion(
            """
            @JSBridgeMacro
            class TestApi: NSObject, TestApiProtocol {
                func openFolder(_ name: String, with name2: String) -> String {
                    return "/path/to/folder"
                }
            }
            """,
            expandedSource: """
                class TestApi: NSObject, TestApiProtocol {
                    func openFolder(_ name: String, with name2: String) -> String {
                        return "/path/to/folder"
                    }

                    func openFolder(_ name: String, _ name2: String) -> String {
                        return openFolder(name, with: name2)
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testMacroWithoutAsyncFunctionAndExternalNamedParameter() throws {
        assertMacroExpansion(
            """
            @JSBridgeMacro
            class TestApi: NSObject, TestApiProtocol {
                func openFolder(with name: String) -> String {
                    return "/path/to/folder"
                }
            }
            """,
            expandedSource: """
                class TestApi: NSObject, TestApiProtocol {
                    func openFolder(with name: String) -> String {
                        return "/path/to/folder"
                    }

                    func openFolder(_ name: String) -> String {
                        return openFolder(with: name)
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testMultipleAsyncFunctions() throws {
        assertMacroExpansion(
            """
            @JSBridgeMacro
            class TestApi: NSObject, TestApiProtocol {
                func openFolder() async throws -> String {
                    return "/path/to/folder"
                }

                func saveFile(content: String) async throws -> Bool {
                    return true
                }
            }
            """,
            expandedSource: """
                class TestApi: NSObject, TestApiProtocol {
                    func openFolder() async throws -> String {
                        return "/path/to/folder"
                    }

                    func saveFile(content: String) async throws -> Bool {
                        return true
                    }

                    private func resolveOpenfolder(with value: String) {
                        context.globalObject.setObject(value, forKeyedSubscript: "openFolderResult" as NSString)
                        context.evaluateScript("resolveOpenfolder(openFolderResult);")
                    }

                    private func rejectOpenfolder(with error: Error) {
                        context.globalObject.setObject(
                            error.localizedDescription, forKeyedSubscript: "errorMessage" as NSString)
                        context.evaluateScript("rejectOpenfolder(new Error(errorMessage));")
                    }

                    func openFolder() -> JSValue {
                        let promise = context.evaluateScript(
                            \"\"\"
                                new Promise((resolve, reject) => {
                                    globalThis.resolveOpenfolder = resolve;
                                    globalThis.rejectOpenfolder = reject;
                                });
                            \"\"\")!

                        Task {
                            do {
                                let result = try await openFolder()
                                resolveOpenfolder(with: result)
                            } catch {
                                rejectOpenfolder(with: error)
                            }
                        }

                        return promise
                    }

                    private func resolveSavefile(with value: Bool) {
                        context.globalObject.setObject(value, forKeyedSubscript: "saveFileResult" as NSString)
                        context.evaluateScript("resolveSavefile(saveFileResult);")
                    }

                    private func rejectSavefile(with error: Error) {
                        context.globalObject.setObject(
                            error.localizedDescription, forKeyedSubscript: "errorMessage" as NSString)
                        context.evaluateScript("rejectSavefile(new Error(errorMessage));")
                    }

                    func saveFile(_ content: String) -> JSValue {
                        let promise = context.evaluateScript(
                            \"\"\"
                                new Promise((resolve, reject) => {
                                    globalThis.resolveSavefile = resolve;
                                    globalThis.rejectSavefile = reject;
                                });
                            \"\"\")!

                        Task {
                            do {
                                let result = try await saveFile(content: content)
                                resolveSavefile(with: result)
                            } catch {
                                rejectSavefile(with: error)
                            }
                        }

                        return promise
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testMacroWithNamedParameters() throws {
        assertMacroExpansion(
            """
            @JSBridgeMacro
            class TestApi: NSObject, TestApiProtocol {
                func openFolder(with name: String) async throws -> String {
                    return "/path/to/folder"
                }
            }
            """,
            expandedSource: """
                class TestApi: NSObject, TestApiProtocol {
                    func openFolder(with name: String) async throws -> String {
                        return "/path/to/folder"
                    }

                    private func resolveOpenfolder(with value: String) {
                        context.globalObject.setObject(value, forKeyedSubscript: "openFolderResult" as NSString)
                        context.evaluateScript("resolveOpenfolder(openFolderResult);")
                    }

                    private func rejectOpenfolder(with error: Error) {
                        context.globalObject.setObject(
                            error.localizedDescription, forKeyedSubscript: "errorMessage" as NSString)
                        context.evaluateScript("rejectOpenfolder(new Error(errorMessage));")
                    }

                    func openFolder(_ name: String) -> JSValue {
                        let promise = context.evaluateScript(
                            \"\"\"
                                new Promise((resolve, reject) => {
                                    globalThis.resolveOpenfolder = resolve;
                                    globalThis.rejectOpenfolder = reject;
                                });
                            \"\"\")!

                        Task {
                            do {
                                let result = try await openFolder(with: name)
                                resolveOpenfolder(with: result)
                            } catch {
                                rejectOpenfolder(with: error)
                            }
                        }

                        return promise
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testMacroOnFunctionWithoutReturnType() throws {
        assertMacroExpansion(
            """
            @JSBridgeMacro
            class TestApi: NSObject, TestApiProtocol {
                func voidFunction() {
                    print("voidFunction")
                }
            }
            """,
            expandedSource: """
                class TestApi: NSObject, TestApiProtocol {
                    func voidFunction() {
                        print("voidFunction")
                    }
                }
                """,
            macros: testMacros
        )
    }

    func testMacroOnExtension() throws {
        assertMacroExpansion(
            """
            class TestApi: NSObject {}

            @JSBridgeMacro
            extension TestApi: TestApiProtocol {
                func openFolder() async throws -> String {
                    return "/path/to/folder"
                }
            }
            """,
            expandedSource: """
                class TestApi: NSObject {}
                extension TestApi: TestApiProtocol {
                    func openFolder() async throws -> String {
                        return "/path/to/folder"
                    }

                    private func resolveOpenfolder(with value: String) {
                        context.globalObject.setObject(value, forKeyedSubscript: "openFolderResult" as NSString)
                        context.evaluateScript("resolveOpenfolder(openFolderResult);")
                    }

                    private func rejectOpenfolder(with error: Error) {
                        context.globalObject.setObject(
                            error.localizedDescription, forKeyedSubscript: "errorMessage" as NSString)
                        context.evaluateScript("rejectOpenfolder(new Error(errorMessage));")
                    }

                    func openFolder() -> JSValue {
                        let promise = context.evaluateScript(
                            \"\"\"
                                new Promise((resolve, reject) => {
                                    globalThis.resolveOpenfolder = resolve;
                                    globalThis.rejectOpenfolder = reject;
                                });
                            \"\"\")!

                        Task {
                            do {
                                let result = try await openFolder()
                                resolveOpenfolder(with: result)
                            } catch {
                                rejectOpenfolder(with: error)
                            }
                        }

                        return promise
                    }
                }
                """,
            macros: testMacros
        )
    }

}
