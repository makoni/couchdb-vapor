import XCTest
@testable import couchdb_vapor

final class couchdb_vaporTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(couchdb_vapor().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
