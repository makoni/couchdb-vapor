//
//  CouchUpdateResponse.swift
//  couchdb-vapor
//
//  Created by Sergey Armodin on 06/03/2019.
//

import Foundation

/// Model for insert/update/delete request response.
public struct CouchUpdateResponse: Codable, Sendable {
	/// Operation status.
	public let ok: Bool
	/// Document ID.
	public let id: String
	/// Revision MVCC token.
	public let rev: String
}
