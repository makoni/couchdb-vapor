//
//  CreateSessionResponse.swift
//
//
//  Created by Sergey Armodin on 15.05.2020.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A response model for a create session request.
/// This structure represents the data returned by the server upon a session creation request
/// and conforms to `Codable` and `Sendable` for serialization and thread safety.
struct CreateSessionResponse: Codable, Sendable {
	/// Indicates whether the session creation was successful.
	/// This property is `true` if the request succeeded; otherwise, `false`.
	let ok: Bool

	/// The name of the user associated with the created session.
	/// This property is optional and may be `nil` if the user's name is not included in the response.
	let name: String?

	/// The list of roles assigned to the user for the created session.
	/// This property is optional and may be `nil` if no roles are specified in the response.
	let roles: [String]?

	/// Custom keys for encoding and decoding the response properties.
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
