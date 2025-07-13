import XCTest

@testable import RxClipsCore

class EngineParseRepositoryTests: XCTestCase {
    func testParseRepository() async throws {
        let repository = Repository(
            globalConfig: .init(templatePath: "./"), permissions: [],
            lifecycle: [
                .init(script: .bash(.init(command: "echo 'before global step'")), on: .setup),
                .init(script: .bash(.init(command: "echo 'after global step'")), on: .teardown),
            ],
            jobs: [
                .init(
                    id: "a", name: "a",
                    steps: [
                        .init(
                            name: "Test Step",
                            script: .bash(.init(command: "ls")),
                            lifecycle: [
                                .init(
                                    script: .bash(.init(command: "echo 'after step'")),
                                    on: .afterStep),
                                .init(
                                    script: .bash(.init(command: "echo 'before step'")),
                                    on: .beforeStep),
                            ]
                        )
                    ], needs: [], environment: [:], lifecycle: [],
                    form: nil)
            ])
        let engine = Engine(repository: repository)
        try await engine.parseRepository()
        let scriptExecutionSteps = await engine.rootNode!.children[0].executionScripts
        XCTAssertEqual(scriptExecutionSteps.count, 3)
        XCTAssertEqual(scriptExecutionSteps[0].bashScript?.command, "echo 'before step'")
        XCTAssertEqual(scriptExecutionSteps[1].bashScript?.command, "ls")
        XCTAssertEqual(scriptExecutionSteps[2].bashScript?.command, "echo 'after step'")

        let rootSteps = await engine.rootNode!.job.steps
        XCTAssertEqual(rootSteps.count, 1)
        XCTAssertEqual(rootSteps[0].script.bashScript?.command, "echo 'before global step'")

        let tailSteps = await engine.tailNode!.job.steps
        XCTAssertEqual(tailSteps.count, 1)
        XCTAssertEqual(tailSteps[0].script.bashScript?.command, "echo 'after global step'")
    }

    func testParseRepositoryWithOnlyGlobalLifecycle() async throws {
        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: [
                .init(script: .bash(.init(command: "echo 'setup'")), on: .setup),
                .init(script: .bash(.init(command: "echo 'teardown'")), on: .teardown),
            ],
            jobs: []
        )

        let engine = Engine(repository: repository)
        try await engine.parseRepository()

        let rootSteps = await engine.rootNode!.job.steps
        let tailSteps = await engine.tailNode!.job.steps
        XCTAssertEqual(rootSteps.count, 1)
        XCTAssertEqual(tailSteps.count, 1)
        XCTAssertEqual(rootSteps[0].script.bashScript?.command, "echo 'setup'")
        XCTAssertEqual(tailSteps[0].script.bashScript?.command, "echo 'teardown'")
    }

    func testParseRepositoryWithOnlySteps() async throws {
        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: [],
            jobs: [
                .init(
                    id: "job1", name: "Job 1",
                    steps: [
                        .init(
                            name: "Step 1",
                            script: .bash(.init(command: "echo 'step 1'"))
                        ),
                        .init(
                            name: "Step 2",
                            script: .bash(.init(command: "echo 'step 2'"))
                        ),
                    ],
                    needs: [], environment: [:], lifecycle: [], form: nil
                )
            ]
        )

        let engine = Engine(repository: repository)
        try await engine.parseRepository()
        let scriptExecutionSteps = await engine.rootNode!.children[0].executionScripts

        XCTAssertEqual(scriptExecutionSteps.count, 2)
        XCTAssertEqual(scriptExecutionSteps[0].bashScript?.command, "echo 'step 1'")
        XCTAssertEqual(scriptExecutionSteps[1].bashScript?.command, "echo 'step 2'")
    }

    func testParseRepositoryWithStepLifecycle() async throws {
        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: [],
            jobs: [
                .init(
                    id: "job1", name: "Job with Lifecycle",
                    steps: [
                        .init(
                            name: "Step With Lifecycle",
                            script: .bash(.init(command: "echo 'main step'")),
                            lifecycle: [
                                .init(
                                    script: .bash(.init(command: "echo 'before step'")),
                                    on: .beforeStep),
                                .init(
                                    script: .bash(.init(command: "echo 'after step'")),
                                    on: .afterStep),
                            ]
                        )
                    ],
                    needs: [], environment: [:], lifecycle: [], form: nil
                )
            ]
        )

        let engine = Engine(repository: repository)
        try await engine.parseRepository()
        let scriptExecutionSteps = await engine.rootNode!.children[0].executionScripts

        XCTAssertEqual(scriptExecutionSteps.count, 3)
        XCTAssertEqual(scriptExecutionSteps[0].bashScript?.command, "echo 'before step'")
        XCTAssertEqual(scriptExecutionSteps[1].bashScript?.command, "echo 'main step'")
        XCTAssertEqual(scriptExecutionSteps[2].bashScript?.command, "echo 'after step'")
    }

    func testParseRepositoryWithEmptyRepository() async throws {
        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: [],
            jobs: []
        )

        let engine = Engine(repository: repository)
        try await engine.parseRepository()
        let scriptExecutionSteps = await engine.rootNode!.executionScripts

        XCTAssertEqual(scriptExecutionSteps.count, 0)
    }

    func testParseRepositoryWithMultipleStepsAndMixedLifecycles() async throws {
        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: [
                .init(script: .bash(.init(command: "echo 'global setup'")), on: .setup)
            ],
            jobs: [
                .init(
                    id: "job1", name: "Job with Mixed Lifecycles",
                    steps: [
                        .init(
                            name: "Step 1",
                            script: .bash(.init(command: "echo 'step 1'")),
                            lifecycle: [
                                .init(
                                    script: .bash(.init(command: "echo 'before step 1'")),
                                    on: .beforeStep)
                            ]
                        ),
                        .init(
                            name: "Step 2",
                            script: .bash(.init(command: "echo 'step 2'")),
                            lifecycle: nil
                        ),
                        .init(
                            name: "Step 3",
                            script: .bash(.init(command: "echo 'step 3'")),
                            lifecycle: [
                                .init(
                                    script: .bash(.init(command: "echo 'after step 3'")),
                                    on: .afterStep)
                            ]
                        ),
                    ],
                    needs: [], environment: [:], lifecycle: [], form: nil
                )
            ]
        )

        let engine = Engine(repository: repository)
        try await engine.parseRepository()
        let scriptExecutionSteps = await engine.rootNode!.children[0].executionScripts
        let rootSteps = await engine.rootNode!.job.steps
        let tailSteps = await engine.tailNode!.job.steps

        XCTAssertEqual(scriptExecutionSteps.count, 5)
        XCTAssertEqual(scriptExecutionSteps[0].bashScript?.command, "echo 'before step 1'")
        XCTAssertEqual(scriptExecutionSteps[1].bashScript?.command, "echo 'step 1'")
        XCTAssertEqual(scriptExecutionSteps[2].bashScript?.command, "echo 'step 2'")
        XCTAssertEqual(scriptExecutionSteps[3].bashScript?.command, "echo 'step 3'")
        XCTAssertEqual(scriptExecutionSteps[4].bashScript?.command, "echo 'after step 3'")

        XCTAssertEqual(rootSteps.count, 1)
        XCTAssertEqual(tailSteps.count, 0)
        XCTAssertEqual(rootSteps[0].script.bashScript?.command, "echo 'global setup'")
    }
}
