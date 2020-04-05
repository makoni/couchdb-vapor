import XCTest
import NIO
import AsyncHTTPClient
@testable import CouchDBClient


final class CouchDBClientTests: XCTestCase {
	struct TestData: Codable {
		var name: String
	}
	
	struct ExpectedDoc: Codable {
		var name: String
		var _id: String
		var _rev: String
	}
	
	let testsDB = "fortests"
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
	
	func testInsertGetUpdateDelete() {
		let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		let encoder = JSONEncoder()

		let testData = TestData(name: "test name")
		var expectedInsertId: String = ""
		var expectedInsertRev: String = ""

		// test Insert
		do {
			let data = try encoder.encode(testData)
			let string = String(data: data, encoding: .utf8)!
			
			let response = try couchDBClient
				.insert(
					dbName: testsDB,
					body: .string(string),
					worker: worker
				)?.wait()
			
			XCTAssertNotNil(response)

			XCTAssertEqual(response?.ok, true)
			XCTAssertNotNil(response?.id)
			XCTAssertNotNil(response?.rev)

			expectedInsertId = response!.id
			expectedInsertRev = response!.rev
		} catch (let error) {
			XCTAssertFalse(true)
			print(error)
		}

		// Test Get
		XCTAssertFalse(expectedInsertId.isEmpty)
		do {
			let response = try couchDBClient.get(dbName: testsDB, uri: expectedInsertId, worker: worker)?.wait()
			XCTAssertNotNil(response)
			XCTAssertNotNil(response!.body)
			
			let data = Data(buffer: response!.body!)
			let decoder = JSONDecoder()
			let doc = try decoder.decode(ExpectedDoc.self, from: data)

			XCTAssertNotNil(doc)
			XCTAssertEqual(doc.name, testData.name)

		} catch (let error) {
			XCTAssertFalse(true)
			print(error)
		}

		// Test update
		let updatedData = ExpectedDoc(name: "test name 2", _id: expectedInsertId, _rev: expectedInsertRev)

		do {
			let data = try encoder.encode(updatedData)
			let string = String(data: data, encoding: .utf8)!
			let response = try couchDBClient.update(
				dbName: testsDB,
				uri: expectedInsertId,
				body: .string(string),
				worker: worker
			)?.wait()

			XCTAssertNotNil(response)
			XCTAssertFalse(response!.rev.isEmpty)
			XCTAssertFalse(response!.id.isEmpty)
			XCTAssertNotEqual(response!.rev, expectedInsertRev)
			XCTAssertEqual(response!.id, expectedInsertId)

			let getResponse = try couchDBClient.get(
				dbName: testsDB,
				uri: expectedInsertId,
				worker: worker
			)?.wait()
			
			XCTAssertNotNil(getResponse)
			XCTAssertNotNil(getResponse?.body)

			let getData = Data(buffer: getResponse!.body!)
			let decoder = JSONDecoder()
			let doc = try decoder.decode(ExpectedDoc.self, from: getData)

			XCTAssertNotNil(doc)
			XCTAssertEqual(doc.name, updatedData.name)

			expectedInsertRev = doc._rev
		} catch (let error) {
			XCTAssertFalse(true)
			print(error)
		}

		// Test delete
		do {
			let response = try couchDBClient.delete(fromDb: testsDB, uri: expectedInsertId, rev: expectedInsertRev, worker: worker)?.wait()

			XCTAssertEqual(response?.ok, true)
			XCTAssertNotNil(response?.id)
			XCTAssertNotNil(response?.rev)

		} catch (let error) {
			XCTAssertFalse(true)
			print(error)
		}
	}

	func testBuildBaseUrl() {
		let expectedUrl = "http://127.0.0.1:5984"
		let baseUrl = couchDBClient.buildBaseUrl()
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
		("testBuildBaseUrl", testBuildBaseUrl),
		("testBuildQuery", testBuildQuery),
		("testInsertGetUpdateDelete", testInsertGetUpdateDelete)
    ]
}
