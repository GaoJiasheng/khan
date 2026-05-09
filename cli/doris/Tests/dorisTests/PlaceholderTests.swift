import XCTest
@testable import doris

final class PlaceholderTests: XCTestCase {
    func testCLILoads() {
        XCTAssertEqual(Doris.configuration.commandName, "doris")
    }
}
