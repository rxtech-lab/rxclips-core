import Foundation
import JSONSchema

// MARK: - Main Repository Schema
public struct Repository: Codable {
    public var globalConfig: Configuration?
    public var permissions: [Permission]?
    public var lifecycle: [LifecycleEvent]?
    public var steps: [Step]?

    public init(
        globalConfig: Configuration? = nil, permissions: [Permission]? = nil,
        lifecycle: [LifecycleEvent]? = nil, steps: [Step]? = nil
    ) {
        self.globalConfig = globalConfig
        self.permissions = permissions
        self.lifecycle = lifecycle
        self.steps = steps
    }
}

// MARK: - Configuration
public struct Configuration: Codable {
    public var templatePath: String?

    public init(templatePath: String? = nil) {
        self.templatePath = templatePath
    }
}

// MARK: - Permission
public enum Permission: String, Codable {
    case readFile
    case writeFile
    case runCommand
    case runScript
    case deleteFile
    case readDirectory
    case writeDirectory
    case deleteDirectory
    case readEnvironmentVariable
    case writeEnvironmentVariable
    case readSecret
    case writeSecret
    case readVariable
    case writeVariable
}

// MARK: - Lifecycle Event
public enum LifecycleEvent: Codable {
    public struct BashScript: Codable {
        public var type: ScriptType = .bash
        public var command: String
        public var on: LifecycleEventType

        public init(command: String, on: LifecycleEventType) {
            self.command = command
            self.on = on
        }
    }

    public struct JavaScriptScript: Codable {
        public var type: ScriptType = .javascript
        public var file: String
        public var on: LifecycleEventType

        public init(file: String, on: LifecycleEventType) {
            self.file = file
            self.on = on
        }
    }

    public struct TemplateScript: Codable {
        public var type: ScriptType = .template
        public var file: String
        public var on: LifecycleEventType

        public init(file: String, on: LifecycleEventType) {
            self.file = file
            self.on = on
        }
    }

    case bash(BashScript)
    case javascript(JavaScriptScript)
    case template(TemplateScript)

    enum CodingKeys: String, CodingKey {
        case type
        case command
        case file
        case on
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ScriptType.self, forKey: .type)

        switch type {
        case .bash:
            let command = try container.decode(String.self, forKey: .command)
            let on = try container.decode(LifecycleEventType.self, forKey: .on)
            self = .bash(BashScript(command: command, on: on))
        case .javascript:
            let file = try container.decode(String.self, forKey: .file)
            let on = try container.decode(LifecycleEventType.self, forKey: .on)
            self = .javascript(JavaScriptScript(file: file, on: on))
        case .template:
            let file = try container.decode(String.self, forKey: .file)
            let on = try container.decode(LifecycleEventType.self, forKey: .on)
            self = .template(TemplateScript(file: file, on: on))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .bash(let script):
            try container.encode(script.type, forKey: .type)
            try container.encode(script.command, forKey: .command)
            try container.encode(script.on, forKey: .on)
        case .javascript(let script):
            try container.encode(script.type, forKey: .type)
            try container.encode(script.file, forKey: .file)
            try container.encode(script.on, forKey: .on)
        case .template(let script):
            try container.encode(script.type, forKey: .type)
            try container.encode(script.file, forKey: .file)
            try container.encode(script.on, forKey: .on)
        }
    }
}

public enum LifecycleEventType: String, Codable {
    case setup
    case teardown
    case beforeStep
    case afterStep
}

// MARK: - Step
public struct Step: Codable {
    public var id: String?
    public var name: String?
    public var form: JSONSchema?
    public var ifCondition: String?
    public var type: ScriptType
    public var command: String?
    public var file: String?
    public var files: [TemplateFile]?
    public var lifecycle: [LifecycleEvent]?

    public init(
        id: String? = nil, name: String? = nil, form: JSONSchema? = nil,
        ifCondition: String? = nil, type: ScriptType, command: String? = nil, file: String? = nil,
        files: [TemplateFile]? = nil, lifecycle: [LifecycleEvent]? = nil
    ) {
        self.id = id
        self.name = name
        self.form = form
        self.ifCondition = ifCondition
        self.type = type
        self.command = command
        self.file = file
        self.files = files
        self.lifecycle = lifecycle
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case form
        case ifCondition = "if"
        case type
        case command
        case file
        case files
        case lifecycle
    }
}

// MARK: - Script Type
public enum ScriptType: String, Codable {
    case bash
    case javascript
    case template
}

// MARK: - Template File
public struct TemplateFile: Codable {
    public var templateFolder: String?
    public var file: String
    public var output: String

    public init(templateFolder: String? = nil, file: String, output: String) {
        self.templateFolder = templateFolder
        self.file = file
        self.output = output
    }
}
