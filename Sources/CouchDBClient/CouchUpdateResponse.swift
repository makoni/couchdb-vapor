//
//  CouchUpdateResponse.swift
//  couchdb-vapor
//
//  Created by Sergey Armodin on 06/03/2019.
//

import Foundation


/// Model for update/delete request response
public struct CouchUpdateResponse: Codable {
	init(ok: Bool, id: String, rev: String) {
		self.ok = ok
		self.id = id
		self.rev = rev
	}

	/// Operation status
	public var ok: Bool
	/// Document ID
	public var id: String
	/// Revision MVCC token
	public var rev: String
	
	enum CodingKeys: String, CodingKey {
		case ok
		case id
		case rev
	}
}
