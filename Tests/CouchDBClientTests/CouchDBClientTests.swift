import XCTest
import NIO
import AsyncHTTPClient
@testable import CouchDBClient


final class CouchDBClientTests: XCTestCase {

	struct ExpectedDoc: CouchDBRepresentable {
		var name: String
		var _id: String?
		var _rev: String?
	}
	
	let testsDB = "fortests"

	let couchDBClient = CouchDBClient(
		couchProtocol: .http,
		couchHost: "127.0.0.1",
		couchPort: 5984,
		userName: "admin",
		userPassword: ProcessInfo.processInfo.environment["COUCHDB_PASS"] ?? ""
	)
	
	override func setUp() async throws {
        try await super.setUp()
	}

    func test00_CreateDB() async throws {
        do {
            let exists = try await couchDBClient.dbExists(testsDB)
            if exists {
                try await couchDBClient.deleteDB(testsDB)
            }

            try await couchDBClient.createDB(testsDB)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func test01_DBExists() async throws {
        do {
            let exists = try await couchDBClient.dbExists(testsDB)
            XCTAssertTrue(exists)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
	
	func test03_GetAllDbs() async throws {
		do {
			let dbs = try await couchDBClient.getAllDBs()

			XCTAssertNotNil(dbs)
			XCTAssertFalse(dbs.isEmpty)
			XCTAssertTrue(dbs.contains(testsDB))
		} catch {
			XCTFail(error.localizedDescription)
		}
	}

	func test04_updateAndDeleteDocMethods() async throws {
		var testDoc = ExpectedDoc(name: "test name")
		var expectedInsertId: String = ""
		var expectedInsertRev: String = ""

		// insert
		do {
			try await couchDBClient.insert(
				dbName: testsDB,
				doc: &testDoc
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
			testDoc = try await couchDBClient.get(fromDB: testsDB, uri: expectedInsertId)
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
				doc: &testDoc
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
		let getResponse2 = try await couchDBClient.get(
			fromDB: testsDB,
			uri: expectedInsertId
		)
		XCTAssertNotNil(getResponse2.body)

		let expectedBytes2 = getResponse2.headers.first(name: "content-length").flatMap(Int.init) ?? 1024 * 1024 * 10
		var bytes2 = try await getResponse2.body.collect(upTo: expectedBytes2)
		let data2 = bytes2.readData(length: bytes2.readableBytes)

		testDoc = try JSONDecoder().decode(
			ExpectedDoc.self,
			from: data2!
		)

		XCTAssertEqual(expectedName, testDoc.name)

		// Test delete doc
		do {
			let response = try await couchDBClient.delete(
				fromDb: testsDB,
				doc: testDoc
			)

			XCTAssertEqual(response.ok, true)
			XCTAssertNotNil(response.id)
			XCTAssertNotNil(response.rev)
		} catch let error {
			XCTFail(error.localizedDescription)
		}
	}
	
	func test05_InsertGetUpdateDelete() async throws {
		var testDoc = ExpectedDoc(name: "test name")
		var expectedInsertId: String = ""
		var expectedInsertRev: String = ""

		// test Insert
		do {
			let insertEncodeData = try JSONEncoder().encode(testDoc)
			let response = try await couchDBClient.insert(
				dbName: testsDB,
				body: .bytes(ByteBuffer(data: insertEncodeData))
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
			let response = try await couchDBClient.get(fromDB: testsDB, uri: expectedInsertId)
			XCTAssertNotNil(response.body)

			let expectedBytes = response.headers.first(name: "content-length").flatMap(Int.init) ?? 1024 * 1024 * 10
			var bytes = try await response.body.collect(upTo: expectedBytes)
			let data = bytes.readData(length: bytes.readableBytes)

			testDoc = try JSONDecoder().decode(
				ExpectedDoc.self,
				from: data!
			)

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
			let body: HTTPClientRequest.Body = .bytes(ByteBuffer(data: updateEncodedData))

			let updateResponse = try await couchDBClient.update(
				dbName: testsDB,
				uri: expectedInsertId,
				body: body
			)

			XCTAssertFalse(updateResponse.rev.isEmpty)
			XCTAssertFalse(updateResponse.id.isEmpty)
			XCTAssertNotEqual(updateResponse.rev, expectedInsertRev)
			XCTAssertEqual(updateResponse.id, expectedInsertId)

			let getResponse = try await couchDBClient.get(
				fromDB: testsDB,
				uri: expectedInsertId
			)
			XCTAssertNotNil(getResponse.body)

			let expectedBytes = getResponse.headers.first(name: "content-length").flatMap(Int.init) ?? 1024 * 1024 * 10
			var bytes = try await getResponse.body.collect(upTo: expectedBytes)
			let data = bytes.readData(length: bytes.readableBytes)

			testDoc = try JSONDecoder().decode(
				ExpectedDoc.self,
				from: data!
			)

			XCTAssertEqual(expectedName, testDoc.name)
		} catch let error {
			XCTFail(error.localizedDescription)
		}

		// Test delete
		do {
			let response = try await couchDBClient.delete(
				fromDb: testsDB,
				uri: testDoc._id!,
				rev: testDoc._rev!
			)

			XCTAssertEqual(response.ok, true)
			XCTAssertNotNil(response.id)
			XCTAssertNotNil(response.rev)

		} catch let error {
			XCTFail(error.localizedDescription)
		}
	}
	
	func test06_BuildUrl() {
		let expectedUrl = "http://127.0.0.1:5984?key=testKey"
		let url = couchDBClient.buildUrl(path: "", query: [
			URLQueryItem(name: "key", value: "testKey")
		])
		XCTAssertEqual(url, expectedUrl)
	}

	func test07_Auth() async throws {
		let session: CreateSessionResponse? = try await couchDBClient.authIfNeed()
		XCTAssertNotNil(session)
		XCTAssertEqual(true, session?.ok)
		XCTAssertNotNil(couchDBClient.sessionCookieExpires)
	}

	func test08_find_with_body() async throws {
		do {
			let testDoc = ExpectedDoc(name: "Greg")
			let insertEncodedData = try JSONEncoder().encode(testDoc)
			let insertResponse = try await couchDBClient.insert(
				dbName: testsDB,
				body: .bytes(ByteBuffer(data: insertEncodedData))
			)


			let selector = ["selector": ["name": "Greg"]]
			let bodyData = try JSONEncoder().encode(selector)
			let requestBody: HTTPClientRequest.Body = .bytes(ByteBuffer(data: bodyData))

			let findResponse = try await couchDBClient.find(
				inDB: testsDB,
				body: requestBody
			)

			let body = findResponse.body
			let expectedBytes = findResponse.headers.first(name: "content-length").flatMap(Int.init)
			var bytes = try await body.collect(upTo: expectedBytes ?? 1024 * 1024 * 10)

			guard let data = bytes.readData(length: bytes.readableBytes) else {
				throw CouchDBClientError.noData
			}

			let decodedResponse = try JSONDecoder().decode(CouchDBFindResponse<ExpectedDoc>.self, from: data)

			XCTAssertTrue(decodedResponse.docs.count > 0)
			XCTAssertTrue(decodedResponse.docs.contains(where: { $0._id == insertResponse.id }))

			_ = try await couchDBClient.delete(
				fromDb: testsDB,
				uri: insertResponse.id,
				rev: insertResponse.rev
			)
		} catch {
			XCTFail(error.localizedDescription)
		}
	}

	func test09_find_with_generics() async throws {
		do {
			let testDoc = ExpectedDoc(name: "Sam")
			let insertEncodedData = try JSONEncoder().encode(testDoc)
			let insertResponse = try await couchDBClient.insert(
				dbName: testsDB,
				body: .bytes(ByteBuffer(data: insertEncodedData))
			)

			let selector = ["selector": ["name": "Sam"]]
			let docs: [ExpectedDoc] = try await couchDBClient.find(inDB: testsDB, selector: selector)

			XCTAssertTrue(docs.count > 0)
			XCTAssertEqual(docs.first!._id, insertResponse.id)

			_ = try await couchDBClient.delete(
				fromDb: testsDB,
				uri: docs.first!._id!,
				rev: docs.first!._rev!
			)
		} catch {
			XCTFail(error.localizedDescription)
		}
	}

    func test99_deleteDB() async throws {
        do {
            try await couchDBClient.deleteDB(testsDB)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
}
