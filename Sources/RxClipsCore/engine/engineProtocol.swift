import Foundation

public protocol ScriptProtocol: Identifiable, Codable {

}

public protocol EngineProtocol: Actor {
    associatedtype ScriptType: ScriptProtocol
    func run(script: ScriptType, cwd: URL, formData: [String: Any]) async throws
        -> any AsyncSequence<
            ExecuteResult, Error
        >
}
