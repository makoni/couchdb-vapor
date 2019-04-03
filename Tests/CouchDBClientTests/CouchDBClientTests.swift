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
	
	func testCreateClient() {
		let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)
		let client = couchDBClient.createClient(forWorker: worker)
		XCTAssertNotNil(client)
	}
	
	func testBuildBaseUrl() {
		let expectedUrl = "http://127.0.0.1:5984"
		let baseUrl = couchDBClient.buildBaseUrl()
		print(baseUrl)
		XCTAssertFalse(baseUrl.isEmpty)
		XCTAssertEqual(baseUrl, expectedUrl)
	}
	
	func testBuildQuery() {
		let query = ["key": "\"testKey\""]
		let expectedQuery = "?key=\"testKey\""
		
		let querString = couchDBClient.buildQuery(fromQuery: query)
		
		XCTAssertFalse(querString.isEmpty)
		XCTAssertEqual(querString, expectedQuery)
	}

    static var allTests = [
        ("testGetAllDbs", testGetAllDbs),
		("testCreateClient", testCreateClient),
		("testBuildBaseUrl", testBuildBaseUrl),
		("testBuildQuery", testBuildQuery)
    ]
}
