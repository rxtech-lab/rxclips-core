# RxClipsCore

RxClipsCore is a powerful, flexible, and extensible workflow execution engine written in Swift. It allows you to define and run complex, dependency-based workflows composed of various script types, including shell commands, Stencil templates, and JavaScript.

The engine is designed with a focus on parallelism, type safety, and extensibility, making it suitable for a wide range of automation tasks, from CI/CD pipelines to complex data processing and code generation.

## Core Concepts

The engine's architecture is built around a few key concepts:

-   **Repository**: The top-level container for a workflow definition. It holds a collection of jobs, global configurations, and lifecycle events.
-   **Job**: A set of steps that can be executed. Jobs can have dependencies on other jobs, forming a Directed Acyclic Graph (DAG).
-   **Step**: A single, atomic action within a job, defined by a script.
-   **Script**: The actual code to be executed. RxClipsCore supports multiple script types out-of-the-box:
    -   `bash`: Executes a shell command.
    -   `template`: Renders files using the [Stencil](https://stencil.fuller.li/en/latest/) template engine.
    -   `javascript`: Executes JavaScript code using a built-in engine.
-   **Lifecycle Events**: Hooks that allow you to run scripts at specific points in the execution flow, such as `setup`, `teardown`, `beforeJob`, `afterJob`, `beforeStep`, and `afterStep`.

## Features

-   **Declarative Workflows**: Define complex workflows using simple, `Codable` Swift structures. This makes it easy to create, parse, and manage workflows from various data sources like JSON or YAML.
-   **Dependency Management**: The engine automatically builds a dependency graph (DAG) from your job definitions. It ensures that jobs are executed in the correct order and runs independent jobs in parallel to maximize efficiency.
-   **Extensible Scripting**: Easily add new script engines by conforming to the `EngineProtocol`.
-   **Powerful JavaScript Integration (`JSEngine`)**:
    -   Run JavaScript code in a sandboxed environment using Apple's `JavaScriptCore`.
    -   Expose native Swift APIs to the JavaScript context.
    -   Seamlessly handle `async` Swift functions from JavaScript, with automatic Promise wrapping and resolution.
-   **Swift Macros for JS Bridging (`JSEngineMacros`)**:
    -   `@JSBridge`: A member macro that automatically generates the necessary boilerplate to expose `async` Swift functions to the `JSEngine`. It creates a Promise-based wrapper that JavaScript can `await`.
    -   `@JSBridgeProtocol`: A member macro for protocols that generates the required function signatures for the JS bridge, ensuring consistency between your protocol and its implementation.
-   **Real-time Execution Tracking**: The engine provides detailed status updates (`notStarted`, `running`, `success`, `failure`) for the entire repository, as well as for individual jobs and steps.

## Modules

### 1. `RxClipsCore`

This is the heart of the execution engine.

-   **`Engine`**: The main actor responsible for parsing a `Repository`, building the execution graph, and running the workflow. It provides an `AsyncThrowingStream` of execution results.
-   **`GraphNode`**: Represents a job in the dependency graph. The engine uses a graph of these nodes to manage the execution order, starting with a `root` node and finishing with a `tail` node.
-   **`BashEngine`**: An engine for executing shell commands via `Process`. It streams stdout and stderr in real-time.
-   **`TemplateEngine`**: An engine that uses `Stencil` to render templates. It can fetch template files from local or remote URLs and write the output to the filesystem.
-   **`RepositoryTypes`**: Defines all the `Codable` data structures (`Repository`, `Job`, `Step`, `Script`, etc.) that constitute a workflow.

### 2. `JSEngine`

A dedicated module for embedding and interacting with JavaScript.

-   It provides a generic `JSEngine` struct that can be initialized with a custom Swift API object (`APIProtocol`).
-   It automatically handles the conversion between Swift and `JSValue` types, including `Codable` types (via JSON serialization).
-   It includes extensions on `JSContext` and `JSValue` to elegantly handle `async` function calls, bridging Swift's `async/await` with JavaScript's Promises.

### 3. `JSEngineMacros`

This module provides Swift macros to significantly reduce the boilerplate required for bridging Swift and JavaScript.

-   **`@JSBridge`**: Apply this to a `class` or `extension` that implements your JavaScript API. For each `async` function, it generates:
    1.  Private `resolve` and `reject` helper methods.
    2.  A public, non-`async` version of the function that returns a `JSValue` (which is a JavaScript `Promise`). This wrapper function invokes the original `async` function in a `Task` and uses the helpers to resolve or reject the promise.
-   **`@JSBridgeProtocol`**: Apply this to your API protocol. It automatically generates the non-`async`, `JSValue`-returning function requirements corresponding to the `async` functions in your protocol.

#### Macro Example

**Before (Manual Boilerplate):**
```swift
protocol MyAPIProtocol: APIProtocol {
    func fetchData() async throws -> String
    // Manually add this for the bridge
    func fetchData() -> JSValue
}

class MyAPI: MyAPIProtocol {
    // ... context property ...
    func fetchData() async throws -> String {
        // ... implementation ...
    }

    // Manually write all this boilerplate
    func fetchData() -> JSValue {
        let promise = context.evaluateScript("""
            new Promise((resolve, reject) => {
                globalThis.resolveFetchData = resolve;
                globalThis.rejectFetchData = reject;
            });
        """)!

        Task {
            do {
                let result = try await fetchData()
                // resolve with result
            } catch {
                // reject with error
            }
        }
        return promise
    }
}
```

**After (Using Macros):**
```swift
@JSBridgeProtocol
protocol MyAPIProtocol: APIProtocol {
    func fetchData() async throws -> String
}

@JSBridge
class MyAPI: MyAPIProtocol {
    // ... context property ...

    // You only need to write the core logic
    func fetchData() async throws -> String {
        // ... implementation ...
    }
}
```

## High-Level Usage

1.  **Define a Workflow**: Create an instance of the `Repository` struct, defining your jobs and their steps.
2.  **Instantiate the Engine**: Create an instance of the `Engine`, passing in your repository.
3.  **Execute**: Call the `execute()` method on the engine.
4.  **Process Results**: Await results from the returned `AsyncThrowingStream`. Each element contains the updated `Repository` state and the specific `ExecuteResult` that triggered the update.

```swift
import RxClipsCore

// 1. Define a repository
let myRepository = Repository(
    jobs: [
        Job(id: "build", steps: [
            Step(script: .bash(.init(command: "swift build")))
        ]),
        Job(id: "test", steps: [
            Step(script: .bash(.init(command: "swift test")))
        ], needs: ["build"]) // Depends on the "build" job
    ]
)

// 2. Create the engine
let engine = Engine(repository: myRepository, baseURL: URL(fileURLWithPath: "."))

do {
    // 3. Execute and 4. Process results
    for try await (updatedRepo, result) in try engine.execute() {
        print("New result received for script: \(result.scriptId)")
        print("Current job status: \(updatedRepo.jobs.first?.runningStatus.status)")
    }
    print("Workflow finished!")
} catch {
    print("Workflow failed: \(error)")
}

```
