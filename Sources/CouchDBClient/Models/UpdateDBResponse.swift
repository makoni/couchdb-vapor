//
//  UpdateDBResponse.swift
//
//
//  Created by Sergei Armodin on 26.12.2022.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A response model for database creation and deletion requests in CouchDB.
/// This structure conforms to `Codable` and `Sendable` for serialization and thread safety.
public struct UpdateDBResponse: Codable, Sendable {
	/// Indicates whether the database creation or deletion operation was successful.
	/// This property is `true` if the operation succeeded; otherwise, `false`.
	public let ok: Bool
}
