import XCTest
import NIO
import AsyncHTTPClient
@testable import CouchDBClient


final class CouchDBClientTests: XCTestCase {

	struct ExpectedDoc: Codable {
		var name: String
		var _id: String?
		var _rev: String?
	}
	
	let testsDB = "fortests"
	#warning("set your admin password if need")
	let c1 = CouchDBClient()
	let couchDBClient = CouchDBClient(
		couchProtocol: .http,
		couchHost: "127.0.0.1",
		couchPort: 5984,
		userName: "admin",
		userPassword: ""
	)
	
	
	override func setUp() {
		super.setUp()
	}
	
	func testGetAllDbs() async throws {
		let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)
		let dbs = try await couchDBClient.getAllDBs(worker: worker)

		XCTAssertNotNil(dbs)
		XCTAssertFalse(dbs!.isEmpty)
		XCTAssertTrue(dbs!.contains(testsDB))
	}
	
	func testInsertGetUpdateDelete() async throws {
		let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		let testData = ExpectedDoc(name: "test name")
		var expectedInsertId: String = ""
		var expectedInsertRev: String = ""

		// test Insert
		do {
			let data = try JSONEncoder().encode(testData)

			let response = try await couchDBClient
				.insert(
					dbName: testsDB,
					body: .data(data),
					worker: worker
				)

			XCTAssertEqual(response.ok, true)
			XCTAssertFalse(response.id.isEmpty)
			XCTAssertFalse(response.rev.isEmpty)

			expectedInsertId = response.id
			expectedInsertRev = response.rev
		} catch (let error) {
			XCTFail(error.localizedDescription)
		}

		// Test Get
		XCTAssertFalse(expectedInsertId.isEmpty)
		do {
			var response = try await couchDBClient.get(dbName: testsDB, uri: expectedInsertId, worker: worker)
			XCTAssertNotNil(response.body)

			let bytes = response.body!.readBytes(length: response.body!.readableBytes)!
			let data = Data(bytes)
			let doc = try JSONDecoder().decode(ExpectedDoc.self, from: data)

			XCTAssertNotNil(doc)
			XCTAssertEqual(doc.name, testData.name)

		} catch let error {
			XCTFail(error.localizedDescription)
		}

		// Test update
		let updatedData = ExpectedDoc(name: "test name 2", _id: expectedInsertId, _rev: expectedInsertRev)

		do {
			let data = try JSONEncoder().encode(updatedData)
			let response = try await couchDBClient.update(
				dbName: testsDB,
				uri: expectedInsertId,
				body: .data(data),
				worker: worker
			)

			XCTAssertFalse(response.rev.isEmpty)
			XCTAssertFalse(response.id.isEmpty)
			XCTAssertNotEqual(response.rev, expectedInsertRev)
			XCTAssertEqual(response.id, expectedInsertId)

			var getResponse = try await couchDBClient.get(
				dbName: testsDB,
				uri: expectedInsertId,
				worker: worker
			)
			
			XCTAssertNotNil(getResponse.body)

			let bytes = getResponse.body!.readBytes(length: getResponse.body!.readableBytes)!
			let getData = Data(bytes)
			let doc = try JSONDecoder().decode(ExpectedDoc.self, from: getData)

			XCTAssertNotNil(doc)
			XCTAssertEqual(doc.name, updatedData.name)

			expectedInsertRev = doc._rev!
		} catch (let error) {
			XCTFail(error.localizedDescription)
		}

		// Test delete
		do {
			let response = try await couchDBClient.delete(
				fromDb: testsDB,
				uri: expectedInsertId,
				rev: expectedInsertRev,
				worker: worker
			)

			XCTAssertEqual(response.ok, true)
			XCTAssertNotNil(response.id)
			XCTAssertNotNil(response.rev)

		} catch (let error) {
			XCTAssertFalse(true)
			print(error)
		}
	}
	
	func testBuildUrl() {
		let expectedUrl = "http://127.0.0.1:5984?key=testKey"
		let url = couchDBClient.buildUrl(path: "", query: [
			URLQueryItem(name: "key", value: "testKey")
		])
		XCTAssertEqual(url, expectedUrl)
	}

	func testAuth() async throws {
		let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)
		let session: CreateSessionResponse? = try await couchDBClient.authIfNeed(worker: worker)
		XCTAssertNotNil(session)
		XCTAssertEqual(true, session?.ok)
	}
}
