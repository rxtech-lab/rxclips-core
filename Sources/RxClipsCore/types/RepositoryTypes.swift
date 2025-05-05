import Foundation
import JSONSchema

// MARK: - Main Repository Schema
public struct Repository: Codable {
    public var globalConfig: Configuration?
    public var permissions: [Permission]?
    public var lifecycle: [LifecycleEvent]?
    public var jobs: [Job]
    public var environment: [String: String]?

    public init(
        globalConfig: Configuration? = nil, permissions: [Permission]? = nil,
        lifecycle: [LifecycleEvent]? = [], jobs: [Job] = [], environment: [String: String]? = nil
    ) {
        self.globalConfig = globalConfig
        self.permissions = permissions
        self.lifecycle = lifecycle
        self.jobs = jobs
        self.environment = environment
    }
}

public struct Job: Codable, Identifiable {
    public var id: String
    public var name: String?
    public var steps: [Step]
    public var needs: [String]
    public var environment: [String: String]
    public var lifecycle: [LifecycleEvent]
    public var form: JSONSchema?

    public init(
        id: String? = nil, name: String? = nil, steps: [Step] = [], needs: [String] = [],
        environment: [String: String] = [:],
        lifecycle: [LifecycleEvent] = [], form: JSONSchema? = nil
    ) {
        self.id = id ?? UUID().uuidString
        self.name = name
        self.steps = steps
        self.needs = needs
        self.environment = environment
        self.lifecycle = lifecycle
        self.form = form
    }

    enum CodingKeys: String, CodingKey {
        case id, name, steps, needs, environment, lifecycle, form
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.steps = try container.decodeIfPresent([Step].self, forKey: .steps) ?? []
        self.needs = try container.decodeIfPresent([String].self, forKey: .needs) ?? []
        self.environment =
            try container.decodeIfPresent([String: String].self, forKey: .environment) ?? [:]
        self.lifecycle =
            try container.decodeIfPresent([LifecycleEvent].self, forKey: .lifecycle) ?? []
        self.form = try container.decodeIfPresent(JSONSchema.self, forKey: .form)
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

public enum Script: Identifiable, Codable {
    public var bashScript: BashScript? {
        guard case .bash(let bashScript) = self else {
            return nil
        }
        return bashScript
    }

    public var javascriptScript: JavaScriptScript? {
        guard case .javascript(let javascriptScript) = self else {
            return nil
        }
        return javascriptScript
    }

    public var templateScript: TemplateScript? {
        guard case .template(let templateScript) = self else {
            return nil
        }
        return templateScript
    }

    public var type: ScriptType {
        switch self {
        case .bash: return .bash
        case .javascript: return .javascript
        case .template: return .template
        }
    }

    public struct BashScript: ScriptProtocol {
        public var id: String
        public var type: ScriptType = .bash
        public var command: String

        public init(id: String? = nil, command: String) {
            self.id = id ?? UUID().uuidString
            self.command = command
        }

        public func updateId(id: String) -> BashScript {
            return BashScript(id: id, command: self.command)
        }
    }

    public struct JavaScriptScript: ScriptProtocol {
        public var id: String
        public var type: ScriptType = .javascript
        public var file: String

        public init(id: String? = nil, file: String) {
            self.id = id ?? UUID().uuidString
            self.file = file
        }

        public func updateId(id: String) -> JavaScriptScript {
            return JavaScriptScript(id: id, file: self.file)
        }
    }

    public struct TemplateScript: ScriptProtocol {
        public var id: String
        public var type: ScriptType = .template
        public var files: [TemplateFile]?

        public init(id: String? = nil, files: [TemplateFile]? = nil) {
            self.id = id ?? UUID().uuidString
            self.files = files
        }

        public func updateId(id: String) -> TemplateScript {
            return TemplateScript(id: id, files: self.files)
        }
    }
    case bash(BashScript)
    case javascript(JavaScriptScript)
    case template(TemplateScript)

    public var id: String {
        switch self {
        case .bash(let bashScript): return bashScript.id
        case .javascript(let javascriptScript): return javascriptScript.id
        case .template(let templateScript): return templateScript.id
        }
    }

    public func updateId(id: String) -> Script {
        switch self {
        case .bash(let bashScript): return .bash(bashScript.updateId(id: id))
        case .javascript(let javascriptScript):
            return .javascript(javascriptScript.updateId(id: id))
        case .template(let templateScript): return .template(templateScript.updateId(id: id))
        }
    }
}

// MARK: - Lifecycle Event
public struct LifecycleEvent: Identifiable, Codable, Comparable {
    public var id: String
    public var script: Script
    public var on: LifecycleEventType
    public var results: [ExecuteResult]

    public init(
        id: String? = nil, script: Script, on: LifecycleEventType, results: [ExecuteResult] = []
    ) {
        self.id = id ?? UUID().uuidString
        self.script = script
        self.on = on
        self.results = results
    }

    enum CodingKeys: String, CodingKey {
        case type
        case command
        case file
        case files
        case on
        case id
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ScriptType.self, forKey: .type)
        self.on = try container.decode(LifecycleEventType.self, forKey: .on)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.results = []

        switch type {
        case .bash:
            let command = try container.decode(String.self, forKey: .command)
            self.script = .bash(Script.BashScript(command: command))
        case .javascript:
            let file = try container.decode(String.self, forKey: .file)
            self.script = .javascript(Script.JavaScriptScript(file: file))
        case .template:
            let files = try container.decodeIfPresent([TemplateFile].self, forKey: .files)

            if let files = files, !files.isEmpty {
                self.script = .template(Script.TemplateScript(files: files))
            } else {
                throw DecodingError.dataCorruptedError(
                    forKey: .file,
                    in: container,
                    debugDescription: "Template script requires either 'file' or 'files'"
                )
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.on, forKey: .on)

        switch script {
        case .bash(let bashScript):
            try container.encode(bashScript.command, forKey: .command)
            try container.encode(bashScript.type, forKey: .type)
        case .javascript(let jsScript):
            try container.encode(jsScript.file, forKey: .file)
            try container.encode(jsScript.type, forKey: .type)
        case .template(let templateScript):
            try container.encodeIfPresent(templateScript.files, forKey: .files)
            try container.encode(templateScript.type, forKey: .type)
        }
    }

    public static func < (lhs: LifecycleEvent, rhs: LifecycleEvent) -> Bool {
        return lhs.on < rhs.on
    }

    public static func == (lhs: LifecycleEvent, rhs: LifecycleEvent) -> Bool {
        return lhs.on == rhs.on
    }

    public static func != (lhs: LifecycleEvent, rhs: LifecycleEvent) -> Bool {
        return lhs.on != rhs.on
    }

    public static func <= (lhs: LifecycleEvent, rhs: LifecycleEvent) -> Bool {
        return lhs.on <= rhs.on
    }

    public static func >= (lhs: LifecycleEvent, rhs: LifecycleEvent) -> Bool {
        return lhs.on >= rhs.on
    }
}

public enum LifecycleEventType: String, Codable, Comparable {
    case setup
    case beforeStep
    case afterStep
    case teardown
    case beforeJob
    case afterJob

    var value: Int {
        switch self {
        case .setup: return 0
        case .beforeJob: return 1
        case .beforeStep: return 2
        case .afterStep: return 3
        case .afterJob: return 4
        case .teardown: return 5
        }
    }

    public static func < (lhs: LifecycleEventType, rhs: LifecycleEventType) -> Bool {
        return lhs.value < rhs.value
    }
}

// MARK: - Step
public struct Step: Identifiable, Codable {
    public var id: String
    public var name: String?
    public var form: JSONSchema?
    public var ifCondition: String?
    public var script: Script
    public var lifecycle: [LifecycleEvent]?
    public var results: [ExecuteResult]

    public init(
        id: String? = nil, name: String? = nil, form: JSONSchema? = nil,
        ifCondition: String? = nil, script: Script, lifecycle: [LifecycleEvent]? = nil
    ) {
        self.id = id ?? UUID().uuidString
        self.name = name
        self.form = form
        self.ifCondition = ifCondition
        self.script = script
        self.lifecycle = lifecycle
        self.results = []
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.form = try container.decodeIfPresent(JSONSchema.self, forKey: .form)
        self.ifCondition = try container.decodeIfPresent(String.self, forKey: .ifCondition)
        self.lifecycle = try container.decodeIfPresent([LifecycleEvent].self, forKey: .lifecycle)
        self.results = []

        let type = try container.decode(ScriptType.self, forKey: .type)

        switch type {
        case .bash:
            let command = try container.decode(String.self, forKey: .command)
            self.script = .bash(Script.BashScript(command: command))
        case .javascript:
            let file = try container.decode(String.self, forKey: .file)
            self.script = .javascript(Script.JavaScriptScript(file: file))
        case .template:
            let files = try container.decodeIfPresent([TemplateFile].self, forKey: .files)

            if let files = files, !files.isEmpty {
                self.script = .template(Script.TemplateScript(files: files))
            } else {
                throw DecodingError.dataCorruptedError(
                    forKey: .file,
                    in: container,
                    debugDescription: "Template script requires either 'file' or 'files'"
                )
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(form, forKey: .form)
        try container.encodeIfPresent(ifCondition, forKey: .ifCondition)
        try container.encodeIfPresent(lifecycle, forKey: .lifecycle)

        switch script {
        case .bash(let bashScript):
            try container.encode(bashScript.type, forKey: .type)
            try container.encode(bashScript.command, forKey: .command)
        case .javascript(let jsScript):
            try container.encode(jsScript.type, forKey: .type)
            try container.encode(jsScript.file, forKey: .file)
        case .template(let templateScript):
            try container.encode(templateScript.type, forKey: .type)
            try container.encodeIfPresent(templateScript.files, forKey: .files)
        }
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
    public var file: String
    public var output: String

    public init(file: String, output: String) {
        self.file = file
        self.output = output
    }
}
