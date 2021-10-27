//
//  CouchUpdateResponse.swift
//  couchdb-vapor
//
//  Created by Sergey Armodin on 06/03/2019.
//

import Foundation


/// Model for update request response
public struct CouchUpdateResponse: Codable {
	init(ok: Bool, id: String, rev: String) {
		self.ok = ok
		self.id = id
		self.rev = rev
	}
	
	public var ok: Bool
	public var id: String
	public var rev: String
	
	enum CodingKeys: String, CodingKey {
		case ok
		case id
		case rev
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		
		ok = try container.decodeIfPresent(Bool.self, forKey: .ok) ?? false
		id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
		rev = try container.decodeIfPresent(String.self, forKey: .rev) ?? ""
	}
}
