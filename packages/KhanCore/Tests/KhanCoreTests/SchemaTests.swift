import XCTest
@testable import KhanCore

final class SchemaTests: XCTestCase {
    func testSchemaModelsCount() {
        XCTAssertEqual(SchemaV1.models.count, 8)
    }
}
