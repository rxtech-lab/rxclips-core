import JSONSchema
import XCTest

@testable import RxClipsCore

final class GraphLookupTests: XCTestCase {

    struct TestCase {
        let name: String
        let path: String
        let expectation: Result<Any, ExecuteError>

        init(name: String, path: String, success expectedValue: Any) {
            self.name = name
            self.path = path
            self.expectation = .success(expectedValue)
        }

        init(name: String, path: String, failure expectedError: ExecuteError) {
            self.name = name
            self.path = path
            self.expectation = .failure(expectedError)
        }
    }

    // Test setup - create a test graph
    func createTestGraph() throws -> GraphNode {
        // Create a repository with multiple jobs and steps
        let step1 = Step(
            id: "step1",
            name: "Step 1",
            script: .bash(Script.BashScript(id: "bash1", command: "echo 'Hello world'"))
        )

        let step2 = Step(
            id: "step2",
            name: "Step 2",
            script: .template(
                Script.TemplateScript(
                    id: "template1",
                    files: [
                        TemplateFile(file: "template.txt", output: "output.txt")
                    ]))
        )

        // Create JSONSchema for forms
        let job1Form = JSONSchema.object(
            properties: ["name": .string()],
            required: ["name"]
        )

        let step3Form = JSONSchema.object(
            properties: ["question": .string()],
            required: ["question"]
        )

        let job1 = Job(
            id: "job1",
            name: "Job 1",
            steps: [step1, step2],
            form: job1Form
        )

        let step3 = Step(
            id: "step3",
            name: "Step 3",
            form: step3Form,
            script: .bash(Script.BashScript(id: "bash3", command: "ls -la"))
        )

        let job2 = Job(
            id: "job2",
            name: "Job 2",
            steps: [step3],
            needs: ["job1"]
        )

        let repository = Repository(jobs: [job1, job2])

        // Build the graph
        let (rootNode, _) = try GraphNode.buildGraph(jobs: repository.jobs)
        return rootNode
    }

    func testLookup() throws {
        // Create the test graph
        let rootNode = try createTestGraph()

        // Helper function to find nodes for tests
        func findJob1Node() -> GraphNode? {
            var result: GraphNode? = nil
            _ = rootNode.traverse { node in
                if node.job.id == "job1" {
                    result = node
                }
            }
            return result
        }

        func findJob2Node() -> GraphNode? {
            var result: GraphNode? = nil
            _ = rootNode.traverse { node in
                if node.job.id == "job2" {
                    result = node
                }
            }
            return result
        }

        // Define table tests
        let testCases: [TestCase] = [
            // Access jobs by index
            TestCase(
                name: "Access first job",
                path: "jobs[0]",
                success: findJob1Node() ?? rootNode),

            // Access steps by index
            TestCase(
                name: "Access second step in job1",
                path: "jobs[0].steps[1]",
                success: (findJob1Node()?.job.steps[1])
                    ?? Step(id: "", script: .bash(.init(command: "")))),

            // Access jobs by ID
            TestCase(
                name: "Access job by ID",
                path: "jobs.job1",
                success: findJob1Node() ?? rootNode),

            // Access steps by ID
            TestCase(
                name: "Access step by ID",
                path: "jobs.job2.steps.step3",
                success: (findJob2Node()?.job.steps[0])
                    ?? Step(id: "", script: .bash(.init(command: "")))),

            // Access form data
            TestCase(
                name: "Access job form data",
                path: "jobs.job1.formData",
                success: [:]),

            TestCase(
                name: "Access step form data",
                path: "jobs.job2.steps.step3.formData",
                success: [:]),

            // Error cases
            TestCase(
                name: "Invalid job index",
                path: "jobs[99]",
                failure: ExecuteError.invalidPath("Job index out of bounds: 99")),

            TestCase(
                name: "Invalid step index",
                path: "jobs[0].steps[99]",
                failure: ExecuteError.invalidPath("Step index out of bounds: 99")),

            TestCase(
                name: "Invalid job ID",
                path: "jobs.nonexistent",
                failure: ExecuteError.invalidPath("Job with ID 'nonexistent' not found")),

            TestCase(
                name: "Invalid step ID",
                path: "jobs.job1.steps.nonexistent",
                failure: ExecuteError.invalidPath("Step with ID 'nonexistent' not found")),

            TestCase(
                name: "Invalid path component",
                path: "invalid.path",
                failure: ExecuteError.invalidPath("Unknown path component: invalid")),
        ]

        // Run tests
        for testCase in testCases {
            do {
                let result = try rootNode.lookup(path: testCase.path)

                switch testCase.expectation {
                case .success(let expectedValue):
                    // Check result based on type
                    if let nodeResult = result as? GraphNode,
                        let expectedNode = expectedValue as? GraphNode
                    {
                        XCTAssertEqual(nodeResult.id, expectedNode.id, "Test: \(testCase.name)")
                    } else if let stepResult = result as? Step,
                        let expectedStep = expectedValue as? Step
                    {
                        XCTAssertEqual(stepResult.id, expectedStep.id, "Test: \(testCase.name)")
                    } else if let dictResult = result as? [String: Any],
                        let expectedDict = expectedValue as? [String: Any]
                    {
                        // Convert to strings for comparison
                        let resultString = String(describing: dictResult)
                        let expectedString = String(describing: expectedDict)
                        XCTAssertEqual(resultString, expectedString, "Test: \(testCase.name)")
                    } else {
                        XCTFail("Test \(testCase.name): Result type mismatch")
                    }

                case .failure:
                    XCTFail("Test \(testCase.name): Expected failure but got success")
                }
            } catch let error as ExecuteError {
                switch testCase.expectation {
                case .success:
                    XCTFail("Test \(testCase.name): Expected success but got error: \(error)")

                case .failure(let expectedError):
                    // Compare error strings since we can't directly compare enum values with associated values
                    XCTAssertEqual(
                        String(describing: error), String(describing: expectedError),
                        "Test: \(testCase.name)")
                }
            } catch {
                XCTFail("Test \(testCase.name): Unexpected error: \(error)")
            }
        }
    }

    // Test accessing results in steps
    func testLookupResults() throws {
        let rootNode = try createTestGraph()

        // Add some sample results to step1
        let step1Result = ExecuteResult.bash(
            ExecuteResult.BashExecuteResult(scriptId: "bash1", output: "Hello world")
        )

        // Update job1's step1 with results
        var updatedRoot = rootNode
        _ = updatedRoot.traverse { node in
            if node.job.id == "job1" {
                if var step = node.job.steps.first(where: { $0.id == "step1" }) {
                    step.results = [step1Result]

                    // Replace the step
                    var steps = node.job.steps
                    if let index = steps.firstIndex(where: { $0.id == "step1" }) {
                        steps[index] = step
                    }
                    node.job.steps = steps
                }
            }
        }

        // Test accessing results
        do {
            let results =
                try updatedRoot.lookup(path: "jobs.job1.steps.step1.results") as? [ExecuteResult]
            XCTAssertNotNil(results)
            XCTAssertEqual(results?.count, 1)

            if case .bash(let bashResult) = results?.first {
                XCTAssertEqual(bashResult.scriptId, "bash1")
                XCTAssertEqual(bashResult.output, "Hello world")
            } else {
                XCTFail("Expected bash result")
            }
        } catch {
            XCTFail("Failed to lookup results: \(error)")
        }
    }
}
