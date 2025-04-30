public actor BashEngine {
    private let commandExecutor: BashCommandExecutor

    public init(commandExecutor: BashCommandExecutor) {
        self.commandExecutor = commandExecutor
    }

    public func run(command: Script.BashScript) throws -> AsyncThrowingStream<String, Error>
    {
        return commandExecutor.runCommand(command: command.command)
    }

}
