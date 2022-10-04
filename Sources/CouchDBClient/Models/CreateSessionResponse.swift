//
//  CreateSessionResponse.swift
//  
//
//  Created by Sergey Armodin on 15.05.2020.
//

import Foundation

/// Resonse model for create session request
struct CreateSessionResponse: Codable {
	var ok: Bool
	var name: String?
	var roles: [String]?
	
	enum CodingKeys: String, CodingKey {
		case ok
		case name
		case roles
	}
}

extension CreateSessionResponse {
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		
		let ok = try container.decodeIfPresent(Bool.self, forKey: .ok) ?? false
		let name = try container.decodeIfPresent(String.self, forKey: .name)
		let roles = try container.decodeIfPresent([String].self, forKey: .roles)
		
		self.init(ok: ok, name: name, roles: roles)
	}
}

