import Foundation

public actor BashEngine {
    private let commandExecutor: BashCommandExecutor

    public init(commandExecutor: BashCommandExecutor) {
        self.commandExecutor = commandExecutor
    }

    internal func run(command: Script.BashScript, cwd: URL? = nil) throws -> any AsyncSequence<
        ExecuteResult, Error
    > {
        return self.commandExecutor.runCommand(command: command.command, workingDirectory: cwd)
            .map { result in
                return ExecuteResult.bash(.init(scriptId: command.id, output: result))
            }
    }
}
