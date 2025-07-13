import Foundation

public protocol ScriptProtocol: Identifiable, Codable {

}

public protocol EngineProtocol: Actor {
    associatedtype ScriptType: ScriptProtocol
    /// Run the script with the provided parameters
    /// - Parameters:
    ///   - script: The script to execute
    ///   - cwd: The current working directory where the script will run
    ///   - repositorySource: The repository source to use to resolve template file references.
    ///   - repositoryPath: The path to the repository to use to resolve template file references.
    ///   - formData: Additional data provided as key-value pairs to be used during script execution
    /// - Returns: An AsyncSequence that yields execution results as they become available
    func run(
        script: ScriptType, cwd: URL, repositorySource: RepositorySource?, repositoryPath: String?,
        formData: [String: Any]
    ) async throws
        -> any AsyncSequence<
            ExecuteResult, Error
        >
}
