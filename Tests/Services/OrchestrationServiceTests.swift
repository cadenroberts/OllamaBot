import XCTest
@testable import OllamaBot

final class OrchestrationServiceTests: XCTestCase {
    var service: OrchestrationService!
    var config: SharedConfigService!
    
    override func setUp() {
        super.setUp()
        config = SharedConfigService()
        service = OrchestrationService(sharedConfig: config)
    }
    
    @MainActor
    func testStartOrchestration() {
        service.startOrchestration(task: "Test Task", mode: .full)
        
        XCTAssertTrue(service.state.isActive)
        XCTAssertEqual(service.state.currentSchedule, .knowledge)
        XCTAssertEqual(service.state.currentProcess, .first)
        XCTAssertEqual(service.state.task, "Test Task")
    }
    
    @MainActor
    func testAdvanceProcess() throws {
        service.startOrchestration(task: "Test Task", mode: .full)
        
        // P1 -> P2
        try service.advanceProcess()
        XCTAssertEqual(service.state.currentProcess, .second)
        
        // P2 -> P3
        try service.advanceProcess()
        XCTAssertEqual(service.state.currentProcess, .third)
        
        // P3 -> Next Schedule P1
        try service.advanceProcess()
        XCTAssertEqual(service.state.currentSchedule, .plan)
        XCTAssertEqual(service.state.currentProcess, .first)
    }
    
    @MainActor
    func testNavigationRules() {
        service.startOrchestration(task: "Test Task", mode: .full)
        
        // Knowledge (1) can navigate to itself
        XCTAssertTrue(service.canNavigateTo(.knowledge))
        
        // Knowledge (1) cannot navigate to Plan (2) until S1 is completed
        XCTAssertFalse(service.canNavigateTo(.plan))
    }
    
    @MainActor
    func testFlowCode() throws {
        service.startOrchestration(task: "Test Task", mode: .full)
        XCTAssertEqual(service.flowCode, "S1P1")
        
        try service.advanceProcess() // S1P2
        XCTAssertEqual(service.flowCode, "S1P1P2")
        
        try service.advanceProcess() // S1P3
        XCTAssertEqual(service.flowCode, "S1P1P2P3")
        
        try service.advanceProcess() // S2P1
        XCTAssertEqual(service.flowCode, "S1P1P2P3S2P1")
    }
}
