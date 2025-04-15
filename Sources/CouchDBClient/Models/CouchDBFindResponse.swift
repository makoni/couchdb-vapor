//
//  CouchDBFindResponse.swift
//
//
//  Created by Gregorio Gevartosky Torrezan on 2023-11-15.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A model that represents the response from a CouchDB `_find` query.
/// This structure is generic, allowing it to represent documents of any type conforming to `CouchDBRepresentable`.
/// It conforms to `Codable` and `Sendable` for serialization and thread safety.
public struct CouchDBFindResponse<T: CouchDBRepresentable>: Codable, Sendable {
	/// The array of documents returned by the CouchDB query.
	/// Each document conforms to the `CouchDBRepresentable` protocol.
	let docs: [T]

	/// The bookmark for use in paginated queries.
	/// This property is optional and will contain a string that can be used
	/// as a reference to continue the query from where it left off.
	let bookmark: String?
}
