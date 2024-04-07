//
//  RowsResponse.swift
//  
//
//  Created by Sergei Armodin on 07.04.2024.
//

import Foundation

public struct RowsResponse<T: CouchDBRepresentable>: Codable {
	public struct Row: Codable {
		public let value: T
	}

	public let total_rows: Int
	public let offset: Int
	public let rows: [Row]
}
