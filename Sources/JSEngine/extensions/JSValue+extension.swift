import JavaScriptCore

extension JSValue {
    func call(withArguments arguments: [Any]) async throws -> JSValue? {
        return try await withCheckedThrowingContinuation { continuation in
            let onFulfilled: @convention(block) (JSValue) -> Void = {
                continuation.resume(returning: $0)
            }
            let onRejected: @convention(block) (JSValue) -> Void = {
                continuation.resume(
                    throwing: JSEngineError.promiseRejected(reason: $0.toString() ?? "Unknown"))
            }
            let promiseArgs = [
                unsafeBitCast(onFulfilled, to: JSValue.self),
                unsafeBitCast(onRejected, to: JSValue.self),
            ]
            let promise = self.call(withArguments: arguments)
            promise?.invokeMethod("then", withArguments: promiseArgs)
        }
    }
}
