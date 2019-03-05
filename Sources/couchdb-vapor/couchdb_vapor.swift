//
//  couchdb_vapor.swift
//  couchdb-vapor
//
//  Created by Sergey Armodin on 06/03/2019.
//

import Foundation
import HTTP


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


	// MARK: - Init
	override init() {
		super.init()
		
		self.couchBaseURL = self.buildBaseUrl()
	}
	
	
	// MARK: - Public methods
	func get(dbName: String, uri: String, query: [String: Any]? = nil, worker: Worker) -> Future<HTTPResponse>? {
		let client = HTTPClient.connect(
			scheme: .http,
			hostname: couchHost,
			port: couchPort,
			connectTimeout: TimeAmount.seconds(30),
			on: worker
		) { (error) in
			print(error)
		}
		
		let queryString = buildQuery(fromQuery: query)
		
		let url = self.couchBaseURL + "/" + dbName + "/" + uri + queryString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
		
		return client.flatMap { (httpCli) -> Future<HTTPResponse> in
			let httpReq = HTTPRequest(
				method: .GET,
				url: url)
			return httpCli.send(httpReq)
		}
	}
}


private extension CouchDBClient {
	/// Build Base URL
	///
	/// - Returns: Base URL string
	private func buildBaseUrl() -> String {
		return "\(self.couchProtocol)\(self.couchHost):\(self.couchPort)"
	}
	
	/// Build query string
	///
	/// - Parameter query: params dictionary
	/// - Returns: query string
	func buildQuery(fromQuery query: [String: Any]?) -> String {
		var queryString = ""
		
		if query != nil {
			var strings = [String]()
			for (key, value) in query! {
				strings.append("\(key)=\(value)")
			}
			queryString = "?\(strings.joined(separator: "&"))"
		}
		return queryString
	}
}
