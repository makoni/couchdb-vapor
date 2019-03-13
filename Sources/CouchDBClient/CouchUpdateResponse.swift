//
//  CouchUpdateResponse.swift
//  couchdb-vapor
//
//  Created by Sergey Armodin on 06/03/2019.
//

import Foundation


public struct CouchUpdateResponse: Codable {
	public var ok: Bool
	public var id: String
	public var rev: String
	
	enum CodingKeys: String, CodingKey {
		case ok
		case id
		case rev
	}
}


public extension CouchUpdateResponse {
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		
		let ok = try container.decodeIfPresent(Bool.self, forKey: .ok)
		let id = try container.decodeIfPresent(String.self, forKey: .id)
		let rev = try container.decodeIfPresent(String.self, forKey: .rev)
		
		self.init(ok: ok ?? false, id: id ?? "", rev: rev ?? "")
	}
}
