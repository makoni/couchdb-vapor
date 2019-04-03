import XCTest
@testable import CouchDBClient
import HTTP

final class CouchDBClientTests: XCTestCase {
	let couchDBClient = CouchDBClient()
	
	override func setUp() {
		super.setUp()
	}
	
	func testGetAllDbs() {
		let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)
		var dbs: [String]?
		do {
			dbs = try couchDBClient.getAllDBs(worker: worker).wait()
			XCTAssertNotNil(dbs)
			XCTAssertTrue(dbs!.contains("_global_changes"))
		} catch (let error) {
			print(error)
		}
	}

    static var allTests = [
        ("testGetAllDbs", testGetAllDbs),
    ]
}
