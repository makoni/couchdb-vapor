//
//  CouchDBRepresentable.swift
//
//
//  Created by Sergey Armodin on 30.08.2022.
//

import Foundation

/// Every CouchDB document should have **\_id** and **\_rev** properties. Both should be optional **String?** type. Unfortunately DocC ignores properties starting with `_` symbol so check the example in the Overview section.
///
/// Example:
/// ```swift
/// // Example struct
/// struct ExpectedDoc: CouchDBRepresentable {
///   var name: String
///   var _id: String?
///   var _rev: String?
/// }
/// ```
public protocol CouchDBRepresentable: Codable, Sendable {
	/// Document ID.
	var _id: String? { get set }
	/// Revision MVCC token.
	var _rev: String? { get set }
}
