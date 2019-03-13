import XCTest
@testable import CouchDBClient

final class CouchDBClientTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
		let couchDBClient = CouchDBClient()
		XCTAssertNotNil(couchDBClient)
//        XCTAssertEqual(CouchDBClient().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
