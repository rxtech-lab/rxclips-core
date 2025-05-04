import Foundation

public actor BashEngine: EngineProtocol {
    public typealias ScriptType = Script.BashScript

    private let commandExecutor: BashCommandExecutor

    public init(commandExecutor: BashCommandExecutor) {
        self.commandExecutor = commandExecutor
    }

    public func run(script: Script.BashScript, cwd: URL, baseURL: URL, formData: [String: Any])
        throws
        -> any AsyncSequence<
            ExecuteResult, Error
        >
    {
        return self.commandExecutor.runCommand(command: script.command, workingDirectory: cwd)
            .map { result in
                return ExecuteResult.bash(.init(scriptId: script.id, output: result))
            }
    }
}
