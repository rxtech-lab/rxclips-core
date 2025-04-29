//
//  SimpleApiHandlingTests.swift
//  JSEngine
//
//  Created by Qiwei Li on 2/18/25.
//

import JSEngineMacro
import JavaScriptCore
import Testing

@testable import JSEngine

@JSBridgeProtocol
@objc private protocol TestApiProtocol: JSExport, APIProtocol {
    func ok()
}

@JSBridge
private class TestApi: NSObject, TestApiProtocol {
    func initializeJSExport(context: JSContext) {
        self.context = context
    }

    var context: JSContext!

    func ok() {}
}

@Suite("Simple Api Handling Tests")
private struct SimpleApiHandlingTests {
    let engine: JSEngine<TestApi>

    init() {
        engine = JSEngine<TestApi>(apiHandler: TestApi())
    }

    @Test func voidFunctionTest() async throws {
        let code = """
            async function handle(api) {
             api.ok()
             return "ok"
            }
            """

        let result: String = try await engine.execute(code: code, functionName: "handle")
        #expect(result == "ok")
    }
}
