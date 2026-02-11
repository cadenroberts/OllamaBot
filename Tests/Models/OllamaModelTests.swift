import XCTest
@testable import OllamaBot

final class OllamaModelTests: XCTestCase {
    func testInitialization() {
        let model = OllamaModel.coder
        XCTAssertEqual(model.displayName, "Coder")
        XCTAssertEqual(model.defaultTag, "qwen2.5-coder:32b")
    }
    
    func testCases() {
        XCTAssertEqual(OllamaModel.allCases.count, 4)
    }
}
