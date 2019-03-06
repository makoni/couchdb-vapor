#if os(Linux)
@testable import CouchDBClientTests

import XCTest

XCTMain([
	testCase(CouchDBClientTests.allTests)
	])
#endif
