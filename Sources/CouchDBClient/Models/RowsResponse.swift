//
//  RowsResponse.swift
//
//
//  Created by Sergei Armodin on 07.04.2024.
//

import Foundation

/// A response model for CouchDB query results organized in rows.
/// This structure is generic, allowing it to represent documents of any type conforming to `CouchDBRepresentable`.
/// It conforms to `Codable` and `Sendable` for serialization and thread safety.
public struct RowsResponse<T: CouchDBRepresentable>: Codable, Sendable {
	/// A nested structure representing an individual row in the response.
	/// Each row contains a CouchDB document as its value.
	public struct Row: Codable, Sendable {
		/// A CouchDB document associated with this row.
		/// The document type must conform to the `CouchDBRepresentable` protocol.
		public let value: T
	}

	/// The total number of documents available in the response.
	/// This value represents the count of all documents matching the query, not just the ones included in the current response.
	public let total_rows: Int

	/// The offset position of the results in the query.
	/// Indicates the starting point of the rows included in the response relative to the full dataset.
	public let offset: Int

	/// The array of rows returned by the query.
	/// Each row contains a CouchDB document and is represented by the nested `Row` structure.
	public let rows: [Row]
}
