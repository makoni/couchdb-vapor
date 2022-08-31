import XCTest
import NIO
import AsyncHTTPClient
@testable import CouchDBClient


final class CouchDBClientTests: XCTestCase {

	struct ExpectedDoc: CouchDBRepresentable, Codable {
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
		do {
			let dbs = try await couchDBClient.getAllDBs()

			XCTAssertNotNil(dbs)
			XCTAssertFalse(dbs.isEmpty)
			XCTAssertTrue(dbs.contains(testsDB))
		} catch {
			XCTFail(error.localizedDescription)
		}
	}

	func test_updateAndDeleteDocMethods() async throws {
		let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		var testDoc = ExpectedDoc(name: "test name")
		var expectedInsertId: String = ""
		var expectedInsertRev: String = ""

		// insert
		do {
			try await couchDBClient.insert(
				dbName: testsDB,
				doc: &testDoc,
				worker: worker
			)
		} catch CouchDBClientError.insertError(let error) {
			XCTFail(error.reason)
			return
		} catch {
			XCTFail(error.localizedDescription)
			return
		}

		expectedInsertId = testDoc._id!
		expectedInsertRev = testDoc._rev!

		// get inserted doc
		do {
			testDoc = try await couchDBClient.get(dbName: testsDB, uri: expectedInsertId, worker: worker)
		} catch CouchDBClientError.getError(let error) {
			XCTFail(error.reason)
			return
		} catch {
			XCTFail(error.localizedDescription)
			return
		}

		// Test update doc
		testDoc.name = "test name 3"
		let expectedName = testDoc.name

		do {
			try await couchDBClient.update(
				dbName: testsDB,
				doc: &testDoc,
				worker: worker
			)
		} catch CouchDBClientError.updateError(let error) {
			XCTFail(error.reason)
			return
		} catch {
			XCTFail(error.localizedDescription)
			return
		}

		XCTAssertNotEqual(testDoc._rev, expectedInsertRev)
		XCTAssertEqual(testDoc._id, expectedInsertId)

		// get updated doc
		var getResponse2 = try await couchDBClient.get(
			dbName: testsDB,
			uri: expectedInsertId,
			worker: worker
		)
		XCTAssertNotNil(getResponse2.body)

		let bytes2 = getResponse2.body!.readBytes(length: getResponse2.body!.readableBytes)!
		testDoc = try JSONDecoder().decode(ExpectedDoc.self, from: Data(bytes2))

		XCTAssertEqual(expectedName, testDoc.name)

		// Test delete doc
		do {
			let response = try await couchDBClient.delete(
				fromDb: testsDB,
				doc: testDoc,
				worker: worker
			)

			XCTAssertEqual(response.ok, true)
			XCTAssertNotNil(response.id)
			XCTAssertNotNil(response.rev)
		} catch let error {
			XCTFail(error.localizedDescription)
		}
	}
	
	func testInsertGetUpdateDelete() async throws {
		let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		var testDoc = ExpectedDoc(name: "test name")
		var expectedInsertId: String = ""
		var expectedInsertRev: String = ""

		// test Insert
		do {
			let insertEncodeData = try JSONEncoder().encode(testDoc)
			let response = try await couchDBClient.insert(
				dbName: testsDB,
				body: .data(insertEncodeData)
			)

			XCTAssertEqual(response.ok, true)
			XCTAssertFalse(response.id.isEmpty)
			XCTAssertFalse(response.rev.isEmpty)

			expectedInsertId = response.id
			expectedInsertRev = response.rev
		} catch let error {
			XCTFail(error.localizedDescription)
		}

		// Test Get
		var expectedName = testDoc.name
		do {
			var response = try await couchDBClient.get(dbName: testsDB, uri: expectedInsertId, worker: worker)
			XCTAssertNotNil(response.body)

			let bytes = response.body!.readBytes(length: response.body!.readableBytes)!
			testDoc = try JSONDecoder().decode(ExpectedDoc.self, from: Data(bytes))

			XCTAssertEqual(expectedName, testDoc.name)
			XCTAssertEqual(testDoc._rev, expectedInsertRev)
			XCTAssertEqual(testDoc._id, expectedInsertId)
		} catch let error {
			XCTFail(error.localizedDescription)
		}

		// Test update with body
		testDoc.name = "test name 2"
		expectedName = testDoc.name

		do {
			let updateEncodedData = try JSONEncoder().encode(testDoc)
			let updateResponse = try await couchDBClient.update(
				dbName: testsDB,
				uri: expectedInsertId,
				body: .data(updateEncodedData),
				worker: worker
			)

			XCTAssertFalse(updateResponse.rev.isEmpty)
			XCTAssertFalse(updateResponse.id.isEmpty)
			XCTAssertNotEqual(updateResponse.rev, expectedInsertRev)
			XCTAssertEqual(updateResponse.id, expectedInsertId)

			var getResponse = try await couchDBClient.get(
				dbName: testsDB,
				uri: expectedInsertId,
				worker: worker
			)
			XCTAssertNotNil(getResponse.body)

			let bytes = getResponse.body!.readBytes(length: getResponse.body!.readableBytes)!
			testDoc = try JSONDecoder().decode(ExpectedDoc.self, from: Data(bytes))

			XCTAssertEqual(expectedName, testDoc.name)
		} catch let error {
			XCTFail(error.localizedDescription)
		}

		// Test delete
		do {
			let response = try await couchDBClient.delete(
				fromDb: testsDB,
				uri: testDoc._id!,
				rev: testDoc._rev!,
				worker: worker
			)

			XCTAssertEqual(response.ok, true)
			XCTAssertNotNil(response.id)
			XCTAssertNotNil(response.rev)

		} catch let error {
			XCTFail(error.localizedDescription)
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
