//
//  CouchUpdateResponse.swift
//  couchdb-vapor
//
//  Created by Sergey Armodin on 06/03/2019.
//

import Foundation


struct CouchUpdateResponse: Codable {
	var ok: Bool
	var id: String
	var rev: String
	
	enum CodingKeys: String, CodingKey {
		case ok
		case id
		case rev
	}
}


extension CouchUpdateResponse {
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		
		let ok = try container.decodeIfPresent(Bool.self, forKey: .ok)
		let id = try container.decodeIfPresent(String.self, forKey: .id)
		let rev = try container.decodeIfPresent(String.self, forKey: .rev)
		
		self.init(ok: ok ?? false, id: id ?? "", rev: rev ?? "")
	}
}
