import XCTest

@testable import RxClipsCore

class GraphTests: XCTestCase {

    // Test case 1: Empty job graph
    func testEmptyJobGraph() throws {
        // Given an empty array of jobs
        let jobs: [Job] = []

        // When building the graph
        let (root, tail) = try GraphNode.buildGraph(jobs: jobs)

        // Then the graph should be empty
        XCTAssertTrue(tail.isEmpty, "Graph should be empty for empty job list")
        XCTAssertEqual(root.children.count, 1, "Root node should have one dependency")
        XCTAssertEqual(root.children[0].id, tail.id, "Root node should connect to tail node")
    }

    // Test case 2: Cyclic dependency in the graph
    func testCyclicDependency() throws {
        // Given jobs with cyclic dependencies
        let jobs: [Job] = [
            Job(
                id: "job1", name: "Job 1", steps: [], needs: ["job2"], environment: [:],
                lifecycle: [], form: nil),
            Job(
                id: "job2", name: "Job 2", steps: [], needs: ["job3"], environment: [:],
                lifecycle: [], form: nil),
            Job(
                id: "job3", name: "Job 3", steps: [], needs: ["job1"], environment: [:],
                lifecycle: [], form: nil),
        ]

        // When building the graph, expect an error
        do {
            _ = try GraphNode.buildGraph(jobs: jobs)
            XCTFail("Expected to throw a cyclic dependency error")
        } catch GraphError.cyclicDependency(let cycle) {
            // Then we should get a cycle error with the cycle path
            XCTAssertTrue(cycle.contains("job1"), "Cycle should contain job1")
            XCTAssertTrue(cycle.contains("job2"), "Cycle should contain job2")
            XCTAssertTrue(cycle.contains("job3"), "Cycle should contain job3")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // Test case 3: Single node graph
    func testSingleNodeGraph() throws {
        // Given a single job with no dependencies
        let jobs: [Job] = [
            Job(
                id: "job1", name: "Job 1", steps: [], needs: [], environment: [:], lifecycle: [],
                form: nil)
        ]

        // When building the graph
        let (root, tail) = try GraphNode.buildGraph(jobs: jobs)

        // Then root should connect to job1, and job1 should connect to tail
        XCTAssertEqual(root.children.count, 1, "Root node should have one dependency")
        XCTAssertEqual(root.children[0].id, "job1", "Root should connect to job1")
        XCTAssertEqual(tail.parents.count, 1, "Tail node should have one dependency")
        XCTAssertEqual(tail.parents[0].id, "job1", "Tail should connect to job1")
    }

    // Test case 4: Two parallel nodes
    func testTwoParallelNodes() throws {
        // Given two jobs with no dependencies
        let jobs: [Job] = [
            Job(
                id: "job1", name: "Job 1", steps: [], needs: [], environment: [:], lifecycle: [],
                form: nil),
            Job(
                id: "job2", name: "Job 2", steps: [], needs: [], environment: [:], lifecycle: [],
                form: nil),
        ]

        // When building the graph
        let (root, tail) = try GraphNode.buildGraph(jobs: jobs)

        // Then root should connect to both jobs, and both jobs should connect to tail
        XCTAssertEqual(root.children.count, 2, "Root node should have two dependencies")
        XCTAssertTrue(
            root.children.contains(where: { $0.id == "job1" }), "Root should connect to job1")
        XCTAssertTrue(
            root.children.contains(where: { $0.id == "job2" }), "Root should connect to job2")
        XCTAssertEqual(tail.parents.count, 2, "Tail node should have two dependencies")
        XCTAssertTrue(
            tail.parents.contains(where: { $0.id == "job1" }), "Tail should connect to job1")
        XCTAssertTrue(
            tail.parents.contains(where: { $0.id == "job2" }), "Tail should connect to job2")
    }

    // Test case 5: Two parallel nodes with one exit node depending on both
    func testTwoParallelNodesWithExitNode() throws {
        // Given two jobs and one exit job that depends on both
        let jobs: [Job] = [
            Job(
                id: "job1", name: "Job 1", steps: [], needs: [], environment: [:], lifecycle: [],
                form: nil),
            Job(
                id: "job2", name: "Job 2", steps: [], needs: [], environment: [:], lifecycle: [],
                form: nil),
            Job(
                id: "job3", name: "Job 3", steps: [], needs: ["job1", "job2"], environment: [:],
                lifecycle: [], form: nil),
        ]

        // When building the graph
        let (root, tail) = try GraphNode.buildGraph(jobs: jobs)

        // Then verify the graph structure
        // Root should connect to job1 and job2
        XCTAssertEqual(root.children.count, 2, "Root node should have two dependencies")
        XCTAssertTrue(
            root.children.contains(where: { $0.id == "job1" }), "Root should connect to job1")
        XCTAssertTrue(
            root.children.contains(where: { $0.id == "job2" }), "Root should connect to job2")

        // job3 should connect to tail
        XCTAssertEqual(tail.parents.count, 1, "Tail node should have one dependency")
        XCTAssertEqual(tail.parents[0].id, "job3", "Tail should connect to job3")

        // Verify job3's needs by looking at the job itself
        let job3 = jobs.first { $0.id == "job3" }
        XCTAssertNotNil(job3, "job3 should exist")
        if let job3 = job3 {
            XCTAssertEqual(job3.needs.count, 2, "job3 should have two dependencies")
            XCTAssertTrue(job3.needs.contains("job1"), "job3 should depend on job1")
            XCTAssertTrue(job3.needs.contains("job2"), "job3 should depend on job2")
        }
    }
}
