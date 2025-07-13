import XCTest

@testable import RxClipsCore

class EngineExecuteTests: XCTestCase {
    func testExecute() async throws {
        // Create repository with numbered echo commands for easy testing
        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: [
                .init(script: .bash(.init(command: "echo \"Setup\"")), on: .setup),
                .init(script: .bash(.init(command: "echo \"Teardown\"")), on: .teardown),
            ],
            jobs: [
                .init(
                    id: "job1", name: "Test Job 1",
                    steps: [
                        .init(
                            name: "Job 1 Step",
                            script: .bash(.init(command: "echo \"Job 1 execution\"")),
                            lifecycle: [
                                .init(
                                    script: .bash(.init(command: "echo \"Before Job 1\"")),
                                    on: .beforeStep),
                                .init(
                                    script: .bash(.init(command: "echo \"After Job 1\"")),
                                    on: .afterStep),
                            ]
                        )
                    ],
                    needs: [], environment: [:], lifecycle: [], form: nil
                ),
                .init(
                    id: "job2", name: "Test Job 2",
                    steps: [
                        .init(
                            name: "Job 2 Step",
                            script: .bash(.init(command: "echo \"Job 2 execution\"")),
                            lifecycle: [
                                .init(
                                    script: .bash(.init(command: "echo \"Before Job 2\"")),
                                    on: .beforeStep),
                                .init(
                                    script: .bash(.init(command: "echo \"After Job 2\"")),
                                    on: .afterStep),
                            ]
                        )
                    ],
                    needs: ["job1"], environment: [:], lifecycle: [], form: nil
                ),
            ]
        )

        // Initialize engine
        let engine = Engine(repository: repository)

        // Get the execution stream
        let executeStream = try await engine.execute()

        // Track repositories and results
        var lastRepository: Repository? = nil
        var outputs: [String] = []
        var nextStepEvents = 0

        // Process all results from the stream
        for try await (updatedRepository, result) in executeStream {
            lastRepository = updatedRepository

            switch result {
            case .bash(let bashResult):
                outputs.append(bashResult.output.trimmingCharacters(in: .whitespacesAndNewlines))
            case .nextStep:
                nextStepEvents += 1
            default:
                continue
            }
        }

        // Verify the number of outputs and step events
        XCTAssertEqual(nextStepEvents, 8)
        XCTAssertEqual(outputs.count, 8)

        // Verify specific outputs exist
        XCTAssertTrue(outputs.contains("Setup"))
        XCTAssertTrue(outputs.contains("Before Job 1"))
        XCTAssertTrue(outputs.contains("Job 1 execution"))
        XCTAssertTrue(outputs.contains("After Job 1"))
        XCTAssertTrue(outputs.contains("Before Job 2"))
        XCTAssertTrue(outputs.contains("Job 2 execution"))
        XCTAssertTrue(outputs.contains("After Job 2"))
        XCTAssertTrue(outputs.contains("Teardown"))

        // Verify repository updates
        XCTAssertNotNil(lastRepository)

        // Verify the final repository contains execution results
        let finalRepository = lastRepository!

        // Check job results are populated
        for job in finalRepository.jobs {
            if job.id == "job1" || job.id == "job2" {
                // Each job should have execution results for each step
                for step in job.steps {
                    XCTAssertFalse(
                        step.results.isEmpty, "Step \(step.id) should have execution results")
                }

                // check the lifecycle results
                for lifecycle in job.lifecycle {
                    XCTAssertFalse(
                        lifecycle.results.isEmpty,
                        "Lifecycle \(lifecycle.id) should have execution results"
                    )
                }
            }
        }

        // check the lifecycle results
        for lifecycle in finalRepository.lifecycle! {
            XCTAssertFalse(
                lifecycle.results.isEmpty, "Lifecycle \(lifecycle.id) should have execution results"
            )
        }

    }

    func testExecuteWithFailure() async throws {
        // Create repository with a failing command
        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: [],
            jobs: [
                .init(
                    id: "job1", name: "Success Job",
                    steps: [
                        .init(
                            name: "Success Step",
                            script: .bash(.init(command: "echo \"Success\"")),
                            lifecycle: []
                        )
                    ],
                    needs: [], environment: [:], lifecycle: [], form: nil
                ),
                .init(
                    id: "job2", name: "Failing Job",
                    steps: [
                        .init(
                            name: "Failing Step",
                            script: .bash(.init(command: "command_that_does_not_exist")),
                            lifecycle: []
                        )
                    ],
                    needs: [], environment: [:], lifecycle: [], form: nil
                ),
            ]
        )

        // Initialize engine
        let engine = Engine(repository: repository)

        // Get the execution stream
        let executeStream = try await engine.execute()

        // Track outputs and repositories
        var repositories: [Repository] = []
        var gotError = false

        do {
            for try await (updatedRepository, _) in executeStream {
                repositories.append(updatedRepository)
            }
        } catch {
            gotError = true
        }

        // Should throw an error
        XCTAssertTrue(gotError)

        // Should at least have processed the successful job
        XCTAssertFalse(repositories.isEmpty)
    }
    
    func testExecuteWithRepositorySource() async throws {
        // Create a mock repository source
        let mockRepositorySource = MockEngineRepositorySource()
        mockRepositorySource.templateContent = "Hello from Repository Source!"
        
        // Create a temporary directory for output
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "engine_repository_source_test")
        try FileManager.default.createDirectory(
            at: temporaryDirectory, withIntermediateDirectories: true, attributes: nil)
        
        // Create repository with template job
        let repository = Repository(
            globalConfig: .init(templatePath: "simple"),
            permissions: [],
            lifecycle: [],
            jobs: [
                .init(
                    id: "template-job", name: "Template Job",
                    steps: [
                        .init(
                            name: "Generate File",
                            script: .template(.init(
                                id: "template-step",
                                files: [.init(file: "template.tmpl", output: "output.txt")]
                            )),
                            lifecycle: []
                        )
                    ],
                    needs: [], environment: [:], lifecycle: [], form: nil
                )
            ]
        )
        
        // Initialize engine with repository source
        let engine = Engine(
            repository: repository,
            cwd: temporaryDirectory,
            repositorySource: mockRepositorySource,
            repositoryPath: repository.globalConfig?.templatePath
        )
        
        // Get the execution stream
        let executeStream = try await engine.execute()
        
        // Track outputs and repositories
        var lastRepository: Repository?
        var templateResults: [ExecuteResult.TemplateExecuteResult] = []
        
        for try await (updatedRepository, result) in executeStream {
            lastRepository = updatedRepository
            
            if case .template(let templateResult) = result {
                templateResults.append(templateResult)
            }
        }
        
        // Verify template was executed
        XCTAssertFalse(templateResults.isEmpty, "Should have template execution results")
        
        // Verify output file was created
        let outputPath = temporaryDirectory.appendingPathComponent("output.txt").path
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath), "Output file should exist")
        
        // Verify file content
        let fileContent = try String(contentsOfFile: outputPath, encoding: .utf8)
        XCTAssertEqual(fileContent, "Hello from Repository Source!", "File should contain resolved template")
        
        // Verify repository source was called correctly
        XCTAssertEqual(mockRepositorySource.lastResolvedPath, "simple")
        XCTAssertEqual(mockRepositorySource.lastResolvedFile, "template.tmpl")
        
        // Clean up
        try FileManager.default.removeItem(atPath: temporaryDirectory.path)
    }
}

// Mock Repository Source for Engine testing
class MockEngineRepositorySource: RepositorySource {
    var templateContent: String = ""
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
        
        // Return a data URL with the template content for testing
        let base64Content = Data(templateContent.utf8).base64EncodedString()
        return "data:text/plain;base64,\(base64Content)"
    }
}
