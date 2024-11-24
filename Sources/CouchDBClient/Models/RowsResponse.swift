//
//  RowsResponse.swift
//  
//
//  Created by Sergei Armodin on 07.04.2024.
//

import Foundation

/// Rows response model.
public struct RowsResponse<T: CouchDBRepresentable>: Codable, Sendable {
	public struct Row: Codable, Sendable {
		/// A CouchDB document.
		public let value: T
	}
	
	/// Total documents in a response.
	public let total_rows: Int
	/// Results offset.
	public let offset: Int
	/// CouchDB documents.
	public let rows: [Row]
}
