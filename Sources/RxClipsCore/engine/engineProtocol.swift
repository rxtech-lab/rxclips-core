import Foundation

public protocol ScriptProtocol: Identifiable, Codable {

}

public protocol EngineProtocol: Actor {
    associatedtype ScriptType: ScriptProtocol
    /// Run the script with the provided parameters
    /// - Parameters:
    ///   - script: The script to execute
    ///   - cwd: The current working directory where the script will run
    ///   - baseURL: The base URL used to resolve template file references. Template files typically use
    ///     paths like `/output/filename`, which are joined with this baseURL to create the complete URL
    ///   - formData: Additional data provided as key-value pairs to be used during script execution
    /// - Returns: An AsyncSequence that yields execution results as they become available
    func run(script: ScriptType, cwd: URL, baseURL: URL, formData: [String: Any]) async throws
        -> any AsyncSequence<
            ExecuteResult, Error
        >
}
