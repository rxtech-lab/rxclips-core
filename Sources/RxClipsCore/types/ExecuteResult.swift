import Foundation
import JSONSchema

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

    public struct FormRequestExecuteResult: Identifiable, Codable {
        public var id = UUID()
        public var scriptId: String
        public var uniqueId: String
        public var schema: JSONSchema?
        
        public init(scriptId: String, uniqueId: String, schema: JSONSchema?) {
            self.scriptId = scriptId
            self.uniqueId = uniqueId
            self.schema = schema
        }
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
    case formRequest(FormRequestExecuteResult)

    public var id: UUID {
        switch self {
        case .bash(let result):
            return result.id
        case .template(let result):
            return result.id
        case .nextStep(let result):
            return result.id
        case .formRequest(let result):
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
        case .formRequest(let result):
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
