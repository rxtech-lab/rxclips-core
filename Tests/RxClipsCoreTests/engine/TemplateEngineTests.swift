import Vapor
import XCTest

@testable import RxClipsCore

final class TemplateEngineTests: XCTestCase {
    var app: Application?

    private func tearDownTest() async throws {
        try await app?.asyncShutdown()
        // remove the temporary directory
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "template_source")
        try FileManager.default.removeItem(atPath: temporaryDirectory.path)
    }

    /// Creates a route that serves the specified template content
    /// - Parameter template: The template string to serve
    /// - Returns: The route path where the template is accessible
    private func createTemplateServer(template: String) async throws -> String {
        let routeId = UUID().uuidString
        app = try await Application.make(.testing)

        app?.get("template", .constant(routeId)) { req -> Response in
            return Response(
                status: .ok,
                headers: HTTPHeaders([("Content-Type", "text/plain")]),
                body: .init(string: template)
            )
        }
        try await app?.startup()

        return "template/\(routeId)"
    }

    func testTemplateEngine() async throws {
        // Define test cases with different template content and form data
        let testCases = [
            (
                templateContent: """
                Hello {{ name }}!
                Your age is {{ age }}.
                """,
                formData: ["name": "Swift", "age": 10],
                expectedOutput: "Hello Swift!\nYour age is 10."
            ),
            (
                templateContent: """
                Project: {{ project.name }}
                Description: {{ project.description }}
                Author:
                  Name: {{ project.author.name }}
                  Email: {{ project.author.email }}
                Environment:
                  Language: {{ environment.language }}
                  Version: {{ environment.version }}
                Dependencies: {{ dependencies | join:", " }}
                """,
                formData: [
                    "project": [
                        "name": "RxClips",
                        "description": "Template rendering engine",
                        "author": [
                            "name": "Swift Developer",
                            "email": "dev@example.com",
                        ],
                    ],
                    "environment": [
                        "language": "Swift",
                        "version": 6.0,
                    ],
                    "dependencies": ["Stencil", "Vapor", "SwiftUI"],
                ],
                expectedOutput: """
                Project: RxClips
                Description: Template rendering engine
                Author:
                  Name: Swift Developer
                  Email: dev@example.com
                Environment:
                  Language: Swift
                  Version: 6.0
                Dependencies: Stencil, Vapor, SwiftUI
                """
            ),
        ]

        // Run each test case
        for (index, testCase) in testCases.enumerated() {
            try await runTemplateTest(
                index: index,
                templateContent: testCase.templateContent,
                formData: testCase.formData,
                expectedOutput: testCase.expectedOutput
            )
        }
    }

    /// Runs a single template test with the given parameters
    /// - Parameters:
    ///   - index: The test case index for unique output paths
    ///   - templateContent: The template content to render
    ///   - formData: The form data to use for rendering
    ///   - expectedOutput: The expected output after rendering
    private func runTemplateTest(
        index: Int,
        templateContent: String,
        formData: [String: Any],
        expectedOutput: String
    ) async throws {
        // Create a template server with the specific template
        let templateUrl = try await createTemplateServer(template: templateContent)

        // Create a temporary directory for the test
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "template_source")

        // Create a unique output file name based on the test index
        let outputFileName = "./output_\(index).txt"

        // Create a mock repository source that handles the template URL
        let mockRepositorySource = MockTemplateServerRepositorySource(app: self.app!)

        // Create a template script with the remote template
        let templateFile = TemplateFile(
            file: templateUrl,
            output: outputFileName
        )

        let templateScript = Script.TemplateScript(files: [templateFile])

        // Run the template engine
        let engine = TemplateEngine()
        let resultSequence = try await engine.run(
            script: templateScript,
            cwd: temporaryDirectory,
            repositorySource: mockRepositorySource,
            repositoryPath: "",
            formData: formData
        )

        // Consume the sequence to complete the operation
        for try await _ in resultSequence {}

        // The expected output path is derived from the template's path
        let expectedOutputPath = temporaryDirectory.appendingPathComponent(outputFileName).path

        // Verify the output file was created with expected content
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: expectedOutputPath),
            "Output file does not exist for test case \(index)")
        let fileContent = try String(contentsOfFile: expectedOutputPath, encoding: .utf8)
        XCTAssertEqual(
            fileContent, expectedOutput,
            "Template output doesn't match expected for test case \(index)")

        // Clean up
        try await tearDownTest()
    }

    func testTemplateEngineWithRepositorySource() async throws {
        // Create a mock repository source for testing
        let mockRepositorySource = MockRepositorySource()
        let templatePath = "simple"
        let templateContent = "Hello {{ name }}!"
        let formData = ["name": "Repository"]
        let expectedOutput = "Hello Repository!"

        // Set up the mock to return the expected template content
        mockRepositorySource.resolvedContent = templateContent

        // Create a temporary directory for the test
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "template_source_test")
        try FileManager.default.createDirectory(
            at: temporaryDirectory, withIntermediateDirectories: true, attributes: nil)

        // Create the template script
        let outputFileName = "output.txt"
        let templateScript = Script.TemplateScript(
            id: "test-template",
            files: [.init(file: "template.tmpl", output: outputFileName)]
        )

        // Run the template engine with repository source
        let engine = TemplateEngine()
        let resultSequence = try await engine.run(
            script: templateScript,
            cwd: temporaryDirectory,
            repositorySource: mockRepositorySource,
            repositoryPath: templatePath,
            formData: formData
        )

        // Consume the sequence to complete the operation
        for try await _ in resultSequence {}

        // Verify the output file was created with expected content
        let expectedOutputPath = temporaryDirectory.appendingPathComponent(outputFileName).path
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: expectedOutputPath),
            "Output file does not exist")
        let fileContent = try String(contentsOfFile: expectedOutputPath, encoding: .utf8)
        XCTAssertEqual(fileContent, expectedOutput, "Template output doesn't match expected")

        // Verify that the repository source's resolve method was called with correct parameters
        XCTAssertEqual(mockRepositorySource.lastResolvedPath, templatePath)
        XCTAssertEqual(mockRepositorySource.lastResolvedFile, "template.tmpl")

        // Clean up
        try FileManager.default.removeItem(atPath: temporaryDirectory.path)
    }
}

// Mock Repository Source that works with the test server
class MockTemplateServerRepositorySource: RepositorySource {
    let app: Application
    
    init(app: Application) {
        self.app = app
    }
    
    func list(path: String?) async throws -> [RepositoryItem] {
        return []
    }
    
    func get(path: String) async throws -> Repository {
        return Repository(jobs: [])
    }
    
    func resolve(path: String, file: String) async throws -> String {
        // For test server, we know it's running on localhost:8080
        // The file parameter already contains the full path like "template/uuid"
        return "http://127.0.0.1:8080/\(file)"
    }
}

// Mock Repository Source for testing
class MockRepositorySource: RepositorySource {
    var resolvedContent: String = ""
    var lastResolvedPath: String?
    var lastResolvedFile: String?

    func list(path: String?) async throws -> [RepositoryItem] {
        return []
    }

    func get(path: String) async throws -> Repository {
        return Repository(jobs: [])
    }

    func resolve(path: String, file: String) async throws -> String {
        lastResolvedPath = path
        lastResolvedFile = file

        // Create a mock server to serve the template content
        let app = try await Application.make(.testing)
        let routeId = UUID().uuidString

        app.get("mock", .constant(routeId)) { req -> Response in
            return Response(
                status: .ok,
                headers: HTTPHeaders([("Content-Type", "text/plain")]),
                body: .init(string: self.resolvedContent)
            )
        }

        try await app.startup()

        // Schedule cleanup
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds
            try await app.asyncShutdown()
        }

        return "http://localhost:8080/mock/\(routeId)"
    }
}
