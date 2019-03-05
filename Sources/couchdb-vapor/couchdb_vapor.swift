//
//  couchdb_vapor.swift
//  couchdb-vapor
//
//  Created by Sergey Armodin on 06/03/2019.
//

import Foundation


class CouchDBClient: NSObject {
	
	// MARK: - Private properties
	
	/// Protocol
	private var couchProtocol: String = "http://"
	
	/// Host
	private var couchHost: String = "127.0.0.1"
	
	/// Port
	private var couchPort: Int = 5984
	
	/// Base URL
	private var couchBaseURL: String = ""

	
	override init() {
		super.init()
		
		self.couchBaseURL = self.buildBaseUrl()
	}
	
}


private extension CouchDBClient {
	/// Build Base URL
	///
	/// - Returns: Base URL string
	private func buildBaseUrl() -> String {
		return "\(self.couchProtocol)\(self.couchHost):\(self.couchPort)"
	}
}
