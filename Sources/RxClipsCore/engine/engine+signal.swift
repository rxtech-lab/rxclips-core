import Foundation

// MARK: - Signal
extension Engine {
    /// Emits an event to all registered listeners for the specified event name
    /// - Parameters:
    ///   - eventName: The name of the event to emit
    ///   - data: Optional dictionary of data to pass to the listeners
    /// - Note: If there are listeners registered for this event, the first listener will be triggered and then removed
    func emit(_ eventName: String, data: [String: Any] = [:]) {
        guard let listeners = eventListeners[eventName], !listeners.isEmpty else {
            return
        }

        // Get the first listener for 'once' behavior
        let listener = listeners[0]

        // Remove this listener since 'once' only triggers once
        eventListeners[eventName]?.removeAll { $0.id == listener.id }

        // Resume the continuation with the data
        listener.continuation.resume(returning: data)
    }

    /// Waits for an event to occur once and returns the associated data
    /// - Parameter eventName: The name of the event to listen for
    /// - Returns: Dictionary containing data passed when the event is emitted
    /// - Note: This function registers a one-time listener that will be automatically removed after the event occurs
    func once(_ eventName: String) async -> [String: Any] {
        return await withCheckedContinuation { continuation in
            let listenerId = UUID()

            if eventListeners[eventName] == nil {
                eventListeners[eventName] = []
            }

            eventListeners[eventName]?.append((id: listenerId, continuation: continuation))
        }
    }
}
