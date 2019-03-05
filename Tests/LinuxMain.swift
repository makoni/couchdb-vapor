import XCTest

import couchdb_vaporTests

var tests = [XCTestCaseEntry]()
tests += couchdb_vaporTests.allTests()
XCTMain(tests)