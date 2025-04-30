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

public enum Script: Codable {
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

    public struct BashScript: Codable {
        public var type: ScriptType = .bash
        public var command: String

        public init(command: String) {
            self.command = command
        }
    }

    public struct JavaScriptScript: Codable {
        public var type: ScriptType = .javascript
        public var file: String

        public init(file: String) {
            self.file = file
        }
    }

    public struct TemplateScript: Codable {
        public var type: ScriptType = .template
        public var file: String
        public var files: [TemplateFile]?

        public init(file: String, files: [TemplateFile]? = nil) {
            self.file = file
            self.files = files
        }
    }
    case bash(BashScript)
    case javascript(JavaScriptScript)
    case template(TemplateScript)

}

// MARK: - Lifecycle Event
public struct LifecycleEvent: Codable, Comparable {
    public var script: Script
    public var on: LifecycleEventType

    public init(script: Script, on: LifecycleEventType) {
        self.script = script
        self.on = on
    }

    enum CodingKeys: String, CodingKey {
        case type
        case command
        case file
        case files
        case on
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ScriptType.self, forKey: .type)
        self.on = try container.decode(LifecycleEventType.self, forKey: .on)

        switch type {
        case .bash:
            let command = try container.decode(String.self, forKey: .command)
            self.script = .bash(Script.BashScript(command: command))
        case .javascript:
            let file = try container.decode(String.self, forKey: .file)
            self.script = .javascript(Script.JavaScriptScript(file: file))
        case .template:
            let files = try container.decodeIfPresent([TemplateFile].self, forKey: .files)
            let file = try container.decodeIfPresent(String.self, forKey: .file)

            if let file = file {
                self.script = .template(Script.TemplateScript(file: file, files: files))
            } else if let files = files, !files.isEmpty {
                self.script = .template(Script.TemplateScript(file: "", files: files))
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
            try container.encode(templateScript.file, forKey: .file)
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

    var value: Int {
        switch self {
        case .setup: return 0
        case .beforeStep: return 1
        case .afterStep: return 2
        case .teardown: return 3
        }
    }

    public static func < (lhs: LifecycleEventType, rhs: LifecycleEventType) -> Bool {
        return lhs.value < rhs.value
    }
}

// MARK: - Step
public struct Step: Codable {
    public var id: String?
    public var name: String?
    public var form: JSONSchema?
    public var ifCondition: String?
    public var script: Script
    public var lifecycle: [LifecycleEvent]?

    public init(
        id: String? = nil, name: String? = nil, form: JSONSchema? = nil,
        ifCondition: String? = nil, script: Script, lifecycle: [LifecycleEvent]? = nil
    ) {
        self.id = id
        self.name = name
        self.form = form
        self.ifCondition = ifCondition
        self.script = script
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.form = try container.decodeIfPresent(JSONSchema.self, forKey: .form)
        self.ifCondition = try container.decodeIfPresent(String.self, forKey: .ifCondition)
        self.lifecycle = try container.decodeIfPresent([LifecycleEvent].self, forKey: .lifecycle)

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
            let file = try container.decodeIfPresent(String.self, forKey: .file)

            if let file = file {
                self.script = .template(Script.TemplateScript(file: file, files: files))
            } else if let files = files, !files.isEmpty {
                self.script = .template(Script.TemplateScript(file: "", files: files))
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
            try container.encode(templateScript.file, forKey: .file)
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
    public var templateFolder: String?
    public var file: String
    public var output: String

    public init(templateFolder: String? = nil, file: String, output: String) {
        self.templateFolder = templateFolder
        self.file = file
        self.output = output
    }
}
