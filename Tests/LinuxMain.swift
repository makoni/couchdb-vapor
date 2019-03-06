import XCTest

import CouchDBClient

var tests = [XCTestCaseEntry]()
tests += couchdb_vaporTests.allTests()
XCTMain(tests)
