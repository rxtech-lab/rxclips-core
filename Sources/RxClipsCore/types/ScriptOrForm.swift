import JSONSchema

public enum ScriptOrForm {
    case script(Script)
    case form(JSONSchema)
}
