public enum JSEngineError: Error {
    case contextNotInitialized
    case functionNotFound
    case functionWithoutReturn
    case handlerCreationFailed
    case promiseRejected(reason: String)
    case typeConversionFailed
}
