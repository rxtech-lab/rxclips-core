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
        public var scriptId: String
        public var filePath: String
        /**
         Represents the percentage of templates rendered from 0 to 100 and calculated by the
         number of templates rendered divided by the total number of templates.
         */
        public var percentage: Double?
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

    public var scriptId: String {
        switch self {
        case .bash(let result):
            return result.scriptId
        case .template(let result):
            return result.scriptId
        case .nextStep(let result):
            return result.scriptId
        }
    }
}

public enum ExecuteError: Error {
    case executionFailed(String)
    case unsupportedScriptType(ScriptType)
    case engineNotFound(ScriptType)
    case graphBuildingFailed
    case parsingFailed
    case notRootNode
    case invalidPath(String)
}
