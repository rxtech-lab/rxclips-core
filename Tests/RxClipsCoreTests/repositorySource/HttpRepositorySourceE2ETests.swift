import XCTest

@testable import RxClipsCore

class HttpRepositorySourceE2ETests: XCTestCase {

    private var repositorySource: HttpRepositorySource!
    private let baseURL = URL(string: "https://rxtrading-strategy-templates.vercel.app")!

    override func setUp() {
        super.setUp()
        repositorySource = HttpRepositorySource(baseUrl: baseURL)
    }

    override func tearDown() {
        repositorySource = nil
        super.tearDown()
    }

    func testListRootRepositoryItems() async throws {
        let items = try await repositorySource.list(path: nil)

        XCTAssertFalse(items.isEmpty, "Root should contain repository items")

        // Verify each item has required properties
        for item in items {
            XCTAssertFalse(item.name.isEmpty, "Item name should not be empty")
            XCTAssertFalse(item.description.isEmpty, "Item description should not be empty")
            XCTAssertFalse(item.path.isEmpty, "Item path should not be empty")
            XCTAssertFalse(item.category.isEmpty, "Item category should not be empty")
        }

        print("Found \(items.count) repository items at root")
        for item in items {
            print("- \(item.name) (\(item.type.rawValue)): \(item.path)")
        }
    }

    func testListRootRepositoryItemsWithEmptyPath() async throws {
        let items = try await repositorySource.list(path: "")

        XCTAssertFalse(
            items.isEmpty, "Root should contain repository items when path is empty string")

        // Should be same as nil path
        let nilPathItems = try await repositorySource.list(path: nil)
        XCTAssertEqual(
            items.count, nilPathItems.count, "Empty string path should behave same as nil path")
    }

    func testGetSimpleRepositoryContent() async throws {
        let repository = try await repositorySource.get(path: "simple")

        XCTAssertFalse(repository.jobs.isEmpty, "Repository should contain jobs")

        print("Jobs count: \(repository.jobs.count)")

        // Verify first job structure
        let firstJob = repository.jobs[0]
        if let jobName = firstJob.name {
            XCTAssertFalse(jobName.isEmpty, "Job name should not be empty")
            print("First job: \(jobName) with \(firstJob.steps.count) steps")
        } else {
            print("First job: (unnamed) with \(firstJob.steps.count) steps")
        }
        XCTAssertFalse(firstJob.steps.isEmpty, "Job should contain steps")
    }

    func testErrorHandlingForInvalidPath() async throws {
        do {
            _ = try await repositorySource.get(path: "nonexistent-path-12345")
            XCTFail("Should throw error for non-existent path")
        } catch let error as RepositorySourceError {
            switch error {
            case .pathNotFound(let path):
                XCTAssertEqual(path, "nonexistent-path-12345")
            case .httpError(let statusCode):
                XCTAssertEqual(statusCode, 404)
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Should throw RepositorySourceError, but got: \(error)")
        }
    }

    func testErrorHandlingForInvalidListPath() async throws {
        do {
            _ = try await repositorySource.list(path: "invalid-list-path-67890")
            XCTFail("Should throw error for invalid list path")
        } catch let error as RepositorySourceError {
            switch error {
            case .pathNotFound(let path):
                XCTAssertEqual(path, "invalid-list-path-67890")
            case .httpError(let statusCode):
                XCTAssertEqual(statusCode, 404)
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Should throw RepositorySourceError, but got: \(error)")
        }
    }

    func testUrlBuildingWithPath() {
        // This test verifies internal URL building logic by testing actual requests
        let expectation = XCTestExpectation(description: "URL building test")

        Task {
            do {
                // Test that path is properly appended
                _ = try await repositorySource.get(path: "simple")
                expectation.fulfill()
            } catch {
                XCTFail("URL building failed: \(error)")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testConcurrentRequests() async throws {
        // Test that the actor properly handles concurrent requests
        let expectations = (1...3).map { i in
            XCTestExpectation(description: "Concurrent request \(i)")
        }

        await withTaskGroup(of: Void.self) { group in
            for (index, expectation) in expectations.enumerated() {
                group.addTask {
                    do {
                        if index == 0 {
                            _ = try await self.repositorySource.list(path: nil)
                        } else {
                            _ = try await self.repositorySource.get(path: "simple")
                        }
                        expectation.fulfill()
                    } catch {
                        XCTFail("Concurrent request \(index) failed: \(error)")
                        expectation.fulfill()
                    }
                }
            }
        }

        await fulfillment(of: expectations, timeout: 15.0)
    }
}
