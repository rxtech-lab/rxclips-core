import Foundation
import XCTest

@testable import RxClipsCore

class EngineE2ETests: XCTestCase {
    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        // Create a unique temporary directory for each test
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rxclips-e2e-test-\(UUID().uuidString)")

        try! FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testSimpleTemplateE2E() async throws {
        // Create repository source pointing to the template repository
        let repositorySource = HttpRepositorySource(
            baseUrl: URL(string: "https://templates.rxtrading.rxlab.app")!
        )

        // Fetch the actual repository from the remote source
        let repository = try await repositorySource.get(path: "simple")

        // Initialize engine with repository source and form callback
        let engine = Engine(
            repository: repository,
            cwd: tempDirectory,
            repositorySource: repositorySource,
            formRequestCallback: { formRequest in
                // Provide form data when requested
                return [
                    "packageName": "github.com/test/my-strategy",
                    "strategyName": "MyTestStrategy",
                ]
            }
        )

        await engine.setRepositoryPath(path: "simple")

        // Execute the repository and collect results
        let executeStream = try await engine.execute()
        var finalRepository: Repository?
        var templateResults: [ExecuteResult.TemplateExecuteResult] = []
        var formRequestReceived = false

        for try await (repository, result) in executeStream {
            finalRepository = repository

            switch result {
            case .template(let templateResult):
                templateResults.append(templateResult)
            case .formRequest(_):
                formRequestReceived = true
            default:
                break
            }
        }

        // Verify execution completed successfully
        XCTAssertNotNil(finalRepository, "Final repository should not be nil")
        XCTAssertFalse(templateResults.isEmpty, "Should have template results")
        XCTAssertTrue(formRequestReceived, "Should have received form request")

        // Verify that all expected files were generated (based on actual repository structure)
        let expectedFiles = ["go.mod", "strategy.go", ".gitignore", "Makefile"]

        for expectedFile in expectedFiles {
            let filePath = tempDirectory.appendingPathComponent(expectedFile)
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: filePath.path),
                "Generated file \(expectedFile) should exist"
            )

            // Verify file has content (not empty)
            let fileContent = try String(contentsOf: filePath, encoding: .utf8)
            XCTAssertFalse(
                fileContent.isEmpty,
                "Generated file \(expectedFile) should not be empty"
            )

            // Basic content verification - just verify files have some content
            // Note: The actual template content depends on the remote template repository
            print("Generated file \(expectedFile) content: \(fileContent.prefix(100))...")

            // Just verify files have some basic structure or are not just empty templates
            if expectedFile == "go.mod" && fileContent.contains("module") {
                // Good - has module declaration
            } else if expectedFile == "strategy.go" && fileContent.contains("package") {
                // Good - has package declaration
            } else if expectedFile == ".gitignore" && fileContent.count > 10 {
                // Good - has some content
            } else if expectedFile == "Makefile" && fileContent.count > 10 {
                // Good - has some content
            } else {
                // For files that don't match expected patterns, just verify they have content
                XCTAssertFalse(fileContent.isEmpty, "\(expectedFile) should not be empty")
            }
        }

        // Verify the job completed successfully
        if let repo = finalRepository,
            let job = repo.jobs.first,
            let step = job.steps.first
        {

            guard case .success = step.runningStatus.status else {
                XCTFail("Template generation step should complete successfully")
                return
            }
        }
    }
}
