//
//  CouchDBRepresentable.swift
//
//
//  Created by Sergey Armodin on 30.08.2022.
//

import Foundation

/// A protocol representing an object that can be stored in a CouchDB database.
/// Conforming types must support Codable and Sendable for serialization and thread safety.
/// Every CouchDB document should have **\_id** and **\_rev** properties. Unfortunately DocC ignores properties starting with `_` symbol so check the example in the Overview section.
///
/// Example:
/// ```swift
/// // Example struct
/// struct ExpectedDoc: CouchDBRepresentable {
///     var name: String
///     var _id: String = NSUUID().uuidString
///     var _rev: String?
///
///     func updateRevision(_ newRevision: String) -> Self {
///         return ExpectedDoc(name: name, _id: _id, _rev: newRevision)
///     }
/// }
/// ```
public protocol CouchDBRepresentable: Codable, Sendable {
    /// The unique identifier for the CouchDB document.
    /// This property is required and must contain a valid document ID.
    var _id: String { get }

    /// The MVCC (Multi-Version Concurrency Control) revision token for the document.
    /// Used for tracking changes to the document and resolving conflicts in CouchDB.
    /// - Note: This property is optional and can be set to `nil` for new documents.
    var _rev: String? { get set }
    
    /// Creates a new instance of the conforming type with the updated revision token.
    /// - Parameter newRevision: The new MVCC revision token to associate with the document.
    /// - Returns: A new instance of the conforming type with the updated `_rev` property.
    func updateRevision(_ newRevision: String) -> Self
}
