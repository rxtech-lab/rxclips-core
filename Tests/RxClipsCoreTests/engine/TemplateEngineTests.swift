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
            baseURL: URL(string: "http://localhost:8080")!,
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
}
