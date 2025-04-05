//
//  CouchDBClientError.swift
//  couchdb-vapor
//
//  Created by Sergei Armodin on 05.04.2025.
//

import Foundation

/// An enumeration representing the various errors that can occur when interacting with CouchDB through a client.
/// This enum conforms to both `Error` and `Sendable`, making it suitable for error handling and thread-safe operations.
public enum CouchDBClientError: Error, Sendable {
	/// The `id` property is empty or missing in the provided document.
	/// This error indicates that the document does not have a valid identifier.
	case idMissing

	/// The `_rev` property is empty or missing in the provided document.
	/// This error indicates that the document does not have a valid revision token for concurrency control.
	case revMissing

	/// The `GET` request was unsuccessful.
	/// - Parameter error: The `CouchDBError` returned by the server, providing details about the issue.
	case getError(error: CouchDBError)

	/// The `INSERT` request was unsuccessful.
	/// - Parameter error: The `CouchDBError` returned by the server, providing details about the issue.
	case insertError(error: CouchDBError)

	/// The `DELETE` request was unsuccessful.
	/// - Parameter error: The `CouchDBError` returned by the server, providing details about the issue.
	case deleteError(error: CouchDBError)

	/// The `UPDATE` request was unsuccessful.
	/// - Parameter error: The `CouchDBError` returned by the server, providing details about the issue.
	case updateError(error: CouchDBError)

	/// The `FIND` request was unsuccessful.
	/// - Parameter error: The `CouchDBError` returned by the server, providing details about the issue.
	case findError(error: CouchDBError)

	/// The response from CouchDB was unrecognized or could not be processed.
	/// This error indicates that the response was not in the expected format.
	case unknownResponse

	/// Authentication failed due to incorrect username or password.
	/// This error suggests that the provided credentials were invalid.
	case unauthorized

	/// The response body is missing required data.
	/// This error indicates that the server response lacked the expected content.
	case noData
}

/// Extends the `CouchDBClientError` enumeration to provide localized error descriptions.
/// This extension conforms to the `LocalizedError` protocol, offering user-friendly messages
/// that describe the nature of each error in detail.
extension CouchDBClientError: LocalizedError {
	/// A textual description of the error, tailored for user-facing contexts.
	/// The message provides specific details about the error type and underlying cause.
	public var errorDescription: String? {
		switch self {
		case .idMissing:
			return "The 'id' property is empty or missing in the provided document."
		case .revMissing:
			return "The '_rev' property is empty or missing in the provided document."
		case .getError(let error):
			return "The GET request wasn't successful: \(error.localizedDescription)"
		case .insertError(let error):
			return "The INSERT request wasn't successful: \(error.localizedDescription)"
		case .updateError(let error):
			return "The UPDATE request wasn't successful: \(error.localizedDescription)"
		case .deleteError(let error):
			return "The DELETE request wasn't successful: \(error.localizedDescription)"
		case .findError(let error):
			return "The FIND request wasn't successful: \(error.localizedDescription)"
		case .unknownResponse:
			return "The response from CouchDB was unrecognized or invalid."
		case .unauthorized:
			return "Authentication failed due to an incorrect username or password."
		case .noData:
			return "The response body is missing the expected data."
		}
	}
}
