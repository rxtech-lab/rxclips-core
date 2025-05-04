import Foundation

public enum ExecuteResult: Identifiable, Codable {
    public struct BashExecuteResult: Identifiable, Codable {
        public var id = UUID()
        public var scriptId: String
        public var output: String
    }

    public struct NextStepExecuteResult: Identifiable, Codable {
        public var id = UUID()
        public var scriptId: String
    }

    public struct TemplateExecuteResult: Identifiable, Codable {
        public var id = UUID()
        public var filePath: String
    }

    case bash(BashExecuteResult)
    case template(TemplateExecuteResult)
    case nextStep(NextStepExecuteResult)

    public var id: UUID {
        switch self {
        case .bash(let result):
            return result.id
        case .template(let result):
            return result.id
        case .nextStep(let result):
            return result.id
        }
    }

}

public enum ExecuteError: Error {
    case executionFailed(String)
    case unsupportedScriptType(ScriptType)
    case engineNotFound(ScriptType)
    case graphBuildingFailed
}
