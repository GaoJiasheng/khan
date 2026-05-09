import XCTest
@testable import DorisCore

final class SchemaTests: XCTestCase {
    func testSchemaModelsCount() {
        XCTAssertEqual(SchemaV1.models.count, 8)
    }
}
