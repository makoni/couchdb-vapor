//
//  CouchUpdateResponse.swift
//  couchdb-swift
//
//  Created by Sergey Armodin on 06/03/2019.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A model for the response returned by CouchDB after performing insert, update, or delete operations.
/// This structure conforms to `Codable` and `Sendable` for serialization and thread safety.
public struct CouchUpdateResponse: Codable, Sendable {
	/// Indicates whether the operation was successful.
	/// This property is `true` if the operation was successful; otherwise, `false`.
	public let ok: Bool

	/// The unique identifier of the CouchDB document affected by the operation.
	/// This property contains the document's ID.
	public let id: String

	/// The MVCC (Multi-Version Concurrency Control) revision token for the document.
	/// This token is updated after each successful operation and is used to track document versions.
	public let rev: String
}
