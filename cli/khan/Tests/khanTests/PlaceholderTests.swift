import XCTest
@testable import khan

final class PlaceholderTests: XCTestCase {
    func testCLILoads() {
        XCTAssertEqual(Khan.configuration.commandName, "khan")
    }
}
