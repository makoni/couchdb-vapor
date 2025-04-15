//
//  CouchDBError.swift
//
//
//  Created by Sergey Armodin on 01.09.2022.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A model that represents errors that CouchDB might return.
/// This structure conforms to `Error`, `Codable`, and `Sendable` protocols for flexibility,
/// serialization, and thread safety.
public struct CouchDBError: Error, Codable, Sendable {
	/// A short description of the error returned by CouchDB.
	/// This property contains a general error type or category, such as `"not_found"`.
	public let error: String

	/// A detailed explanation or reason for the error returned by CouchDB.
	/// This property provides more context about why the error occurred.
	public let reason: String
}
