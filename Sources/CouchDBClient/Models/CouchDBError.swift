//
//  CouchDBError.swift
//
//
//  Created by Sergey Armodin on 01.09.2022.
//

import Foundation

/// A model that represents errors that CouchDB might return.
public struct CouchDBError: Error, Codable, Sendable {
	/// Error message.
	public let error: String
	/// Error reason.
	public let reason: String
}
