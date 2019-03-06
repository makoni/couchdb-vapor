import XCTest

@testable import CouchDBClientTests

var tests = [XCTestCaseEntry]()
tests += CouchDBClientTests.allTests()
XCTMain(tests)
