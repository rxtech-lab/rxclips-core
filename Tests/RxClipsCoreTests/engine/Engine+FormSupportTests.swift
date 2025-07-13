import XCTest
import JSONSchema

@testable import RxClipsCore

class EngineFormSupportTests: XCTestCase {
    
    func testJobLevelFormRequest() async throws {
        let formSchema = JSONSchema.object(
            properties: [
                "name": .string(),
                "email": .string()
            ],
            required: ["name"]
        )
        
        let repository = Repository(
            jobs: [
                .init(
                    id: "job1",
                    name: "Job with Form",
                    steps: [
                        .init(
                            name: "Echo Step",
                            script: .bash(.init(command: "echo \"Hello World\"")),
                            lifecycle: []
                        )
                    ],
                    form: formSchema
                )
            ]
        )
        
        var formRequestReceived: ExecuteResult.FormRequestExecuteResult?
        var callbackFormData: [String: Any]?
        
        let engine = Engine(
            repository: repository,
            formRequestCallback: { formRequest in
                formRequestReceived = formRequest
                let data = ["name": "John Doe", "email": "john@example.com"]
                callbackFormData = data
                return data
            }
        )
        
        let executeStream = try await engine.execute()
        var formRequestEvents: [ExecuteResult.FormRequestExecuteResult] = []
        var bashOutputs: [String] = []
        
        for try await (_, result) in executeStream {
            switch result {
            case .formRequest(let formRequest):
                formRequestEvents.append(formRequest)
            case .bash(let bashResult):
                bashOutputs.append(bashResult.output.trimmingCharacters(in: .whitespacesAndNewlines))
            default:
                continue
            }
        }
        
        // Verify form request was emitted
        XCTAssertEqual(formRequestEvents.count, 1)
        let formRequest = formRequestEvents[0]
        XCTAssertEqual(formRequest.scriptId, "job1")
        XCTAssertTrue(formRequest.uniqueId.hasPrefix("job_job1_"))
        XCTAssertNotNil(formRequest.schema)
        
        // Verify callback was called with correct form request
        XCTAssertNotNil(formRequestReceived)
        XCTAssertEqual(formRequestReceived?.scriptId, "job1")
        XCTAssertEqual(formRequestReceived?.uniqueId, formRequest.uniqueId)
        
        // Verify callback provided data
        XCTAssertNotNil(callbackFormData)
        XCTAssertEqual(callbackFormData?["name"] as? String, "John Doe")
        
        // Verify the step executed after form was provided
        XCTAssertTrue(bashOutputs.contains("Hello World"))
    }
    
    func testStepLevelFormRequest() async throws {
        let stepFormSchema = JSONSchema.object(
            properties: [
                "message": .string(),
                "count": .integer(minimum: 1)
            ],
            required: ["message"]
        )
        
        let repository = Repository(
            jobs: [
                .init(
                    id: "job1",
                    name: "Job with Step Form",
                    steps: [
                        .init(
                            id: "step1",
                            name: "Form Step",
                            form: stepFormSchema,
                            script: .bash(.init(id: "step1", command: "echo \"Step Executed\"")),
                            lifecycle: []
                        )
                    ]
                )
            ]
        )
        
        var callbackInvocations = 0
        var receivedFormData: [String: Any]?
        
        let engine = Engine(
            repository: repository,
            formRequestCallback: { formRequest in
                callbackInvocations += 1
                let data = ["message": "Test Message", "count": 5]
                receivedFormData = data
                return data
            }
        )
        
        let executeStream = try await engine.execute()
        var formRequestEvents: [ExecuteResult.FormRequestExecuteResult] = []
        var bashOutputs: [String] = []
        
        for try await (_, result) in executeStream {
            switch result {
            case .formRequest(let formRequest):
                formRequestEvents.append(formRequest)
            case .bash(let bashResult):
                bashOutputs.append(bashResult.output.trimmingCharacters(in: .whitespacesAndNewlines))
            default:
                continue
            }
        }
        
        // Verify form request was emitted
        XCTAssertEqual(formRequestEvents.count, 1)
        let formRequest = formRequestEvents[0]
        XCTAssertEqual(formRequest.scriptId, "step1")
        XCTAssertTrue(formRequest.uniqueId.hasPrefix("step_step1_"))
        XCTAssertNotNil(formRequest.schema)
        
        // Verify callback was called exactly once
        XCTAssertEqual(callbackInvocations, 1)
        XCTAssertNotNil(receivedFormData)
        
        // Verify step executed after form was provided
        XCTAssertTrue(bashOutputs.contains("Step Executed"))
    }
    
    func testJobAndStepFormRequests() async throws {
        let jobFormSchema = JSONSchema.object(
            properties: ["jobParam": .string()],
            required: ["jobParam"]
        )
        
        let stepFormSchema = JSONSchema.object(
            properties: ["stepParam": .string()],
            required: ["stepParam"]
        )
        
        let repository = Repository(
            jobs: [
                .init(
                    id: "job1",
                    name: "Job with Both Forms",
                    steps: [
                        .init(
                            id: "step1",
                            name: "Step with Form",
                            form: stepFormSchema,
                            script: .bash(.init(id: "step1", command: "echo \"Both Forms Test\"")),
                            lifecycle: []
                        )
                    ],
                    form: jobFormSchema
                )
            ]
        )
        
        var formRequestCount = 0
        var formRequests: [ExecuteResult.FormRequestExecuteResult] = []
        
        let engine = Engine(
            repository: repository,
            formRequestCallback: { formRequest in
                formRequestCount += 1
                formRequests.append(formRequest)
                if formRequest.scriptId == "job1" {
                    return ["jobParam": "JobValue"]
                } else {
                    return ["stepParam": "StepValue"]
                }
            }
        )
        
        let executeStream = try await engine.execute()
        var formRequestEvents: [ExecuteResult.FormRequestExecuteResult] = []
        var bashOutputs: [String] = []
        
        for try await (_, result) in executeStream {
            switch result {
            case .formRequest(let formRequest):
                formRequestEvents.append(formRequest)
            case .bash(let bashResult):
                bashOutputs.append(bashResult.output.trimmingCharacters(in: .whitespacesAndNewlines))
            default:
                continue
            }
        }
        
        // Verify both form requests were emitted
        XCTAssertEqual(formRequestEvents.count, 2)
        
        let jobFormRequest = formRequestEvents.first { $0.scriptId == "job1" }
        let stepFormRequest = formRequestEvents.first { $0.scriptId == "step1" }
        
        XCTAssertNotNil(jobFormRequest)
        XCTAssertNotNil(stepFormRequest)
        
        // Verify callback was called twice
        XCTAssertEqual(formRequestCount, 2)
        XCTAssertEqual(formRequests.count, 2)
        
        // Verify step executed after both forms were provided
        XCTAssertTrue(bashOutputs.contains("Both Forms Test"))
    }
    
    func testWaitForFormDataMethod() async throws {
        let formSchema = JSONSchema.object(
            properties: ["input": .string()],
            required: ["input"]
        )
        
        let repository = Repository(
            jobs: [
                .init(
                    id: "job1",
                    name: "Job with Form",
                    steps: [
                        .init(
                            name: "Echo Step",
                            script: .bash(.init(command: "echo \"Test Complete\"")),
                            lifecycle: []
                        )
                    ],
                    form: formSchema
                )
            ]
        )
        
        // Engine without callback - will use waitForFormData
        let engine = Engine(
            repository: repository
        )
        
        var capturedUniqueId: String?
        var executionCompleted = false
        
        // Start execution in background task
        let executionTask = Task {
            let executeStream = try await engine.execute()
            
            for try await (_, result) in executeStream {
                switch result {
                case .formRequest(let formRequest):
                    capturedUniqueId = formRequest.uniqueId
                    // Simulate external app providing form data
                    Task {
                        try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
                        await engine.provideFormData(
                            uniqueId: formRequest.uniqueId,
                            formData: ["input": "External Input"]
                        )
                    }
                case .bash:
                    executionCompleted = true
                default:
                    continue
                }
            }
        }
        
        try await executionTask.value
        
        // Verify form data was requested and execution completed
        XCTAssertNotNil(capturedUniqueId)
        XCTAssertTrue(executionCompleted)
    }
    
    func testMultipleConcurrentFormRequests() async throws {
        let formSchema = JSONSchema.object(
            properties: ["value": .string()],
            required: ["value"]
        )
        
        let repository = Repository(
            jobs: [
                .init(
                    id: "job1",
                    name: "Job 1",
                    steps: [
                        .init(
                            name: "Step 1",
                            script: .bash(.init(command: "echo \"Job 1 Complete\"")),
                            lifecycle: []
                        )
                    ],
                    form: formSchema
                ),
                .init(
                    id: "job2",
                    name: "Job 2",
                    steps: [
                        .init(
                            name: "Step 2",
                            script: .bash(.init(command: "echo \"Job 2 Complete\"")),
                            lifecycle: []
                        )
                    ],
                    form: formSchema
                )
            ]
        )
        
        var callbackCount = 0
        var receivedRequests: [ExecuteResult.FormRequestExecuteResult] = []
        
        let engine = Engine(
            repository: repository,
            formRequestCallback: { formRequest in
                callbackCount += 1
                receivedRequests.append(formRequest)
                if formRequest.scriptId == "job1" {
                    return ["value": "Value1"]
                } else {
                    return ["value": "Value2"]
                }
            }
        )
        
        let executeStream = try await engine.execute()
        var formRequestEvents: [ExecuteResult.FormRequestExecuteResult] = []
        var bashOutputs: [String] = []
        
        for try await (_, result) in executeStream {
            switch result {
            case .formRequest(let formRequest):
                formRequestEvents.append(formRequest)
            case .bash(let bashResult):
                bashOutputs.append(bashResult.output.trimmingCharacters(in: .whitespacesAndNewlines))
            default:
                continue
            }
        }
        
        // Verify both jobs triggered form requests
        XCTAssertEqual(formRequestEvents.count, 2)
        XCTAssertEqual(callbackCount, 2)
        XCTAssertEqual(receivedRequests.count, 2)
        
        // Verify both jobs completed execution
        XCTAssertTrue(bashOutputs.contains("Job 1 Complete"))
        XCTAssertTrue(bashOutputs.contains("Job 2 Complete"))
    }
    
    func testFormRequestWithoutCallback() async throws {
        let formSchema = JSONSchema.object(
            properties: ["test": .string()],
            required: ["test"]
        )
        
        let repository = Repository(
            jobs: [
                .init(
                    id: "job1",
                    name: "Job with Form",
                    steps: [
                        .init(
                            name: "Echo Step",
                            script: .bash(.init(command: "echo \"Test Complete\"")),
                            lifecycle: []
                        )
                    ],
                    form: formSchema
                )
            ]
        )
        
        let engine = Engine(
            repository: repository
            // No callback provided
        )
        
        var formRequestReceived: ExecuteResult.FormRequestExecuteResult?
        var executionCompleted = false
        
        // Test the direct API methods
        let executionTask = Task {
            let executeStream = try await engine.execute()
            
            for try await (_, result) in executeStream {
                switch result {
                case .formRequest(let formRequest):
                    formRequestReceived = formRequest
                    
                    // Simulate external response
                    Task {
                        await engine.provideFormData(
                            uniqueId: formRequest.uniqueId,
                            formData: ["test": "DirectAPI"]
                        )
                    }
                case .bash:
                    executionCompleted = true
                default:
                    continue
                }
            }
        }
        
        try await executionTask.value
        
        // Verify form request was emitted
        XCTAssertNotNil(formRequestReceived)
        XCTAssertEqual(formRequestReceived?.scriptId, "job1")
        XCTAssertNotNil(formRequestReceived?.schema)
        XCTAssertTrue(executionCompleted)
    }
    
    func testWaitForFormDataAPI() async throws {
        let engine = Engine(
            repository: Repository(jobs: [])
        )
        
        let uniqueId = "test_unique_id"
        let testData = ["test": "value"]
        
        // Test waitForFormData with provideFormData
        let waitTask = Task {
            return await engine.waitForFormData(uniqueId: uniqueId)
        }
        
        // Provide data after a short delay
        Task {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
            await engine.provideFormData(uniqueId: uniqueId, formData: testData)
        }
        
        let receivedData = await waitTask.value
        
        // Verify the correct data was received
        XCTAssertEqual(receivedData["test"] as? String, "value")
    }
}