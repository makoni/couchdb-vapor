//
//  CouchUpdateResponse.swift
//  couchdb-vapor
//
//  Created by Sergey Armodin on 06/03/2019.
//

import Foundation

/// Model for insert/update/delete request response.
public struct CouchUpdateResponse: Codable {
	/// Operation status.
	public var ok: Bool
	/// Document ID.
	public var id: String
	/// Revision MVCC token.
	public var rev: String
}
