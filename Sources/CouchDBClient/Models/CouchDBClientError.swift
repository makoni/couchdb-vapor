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
		if #available(macOS 12, *) {
			switch self {
			case .idMissing:
				return String(
					localized: "ID_MISSING_ERROR",
					defaultValue: "The 'id' property is empty or missing in the provided document.",
					bundle: Bundle.module
				)
			case .revMissing:
				return String(
					localized: "REV_MISSING_ERROR",
					defaultValue: "The '_rev' property is empty or missing in the provided document.",
					bundle: Bundle.module
				)
			case .getError(let error):
				return String(
					localized: "GET_ERROR",
					defaultValue: "The GET request wasn't successful: \(error.localizedDescription)",
					bundle: Bundle.module
				)
			case .insertError(let error):
				return String(
					localized: "INSERT_ERROR",
					defaultValue: "The INSERT request wasn't successful: \(error.localizedDescription)",
					bundle: Bundle.module
				)
			case .updateError(let error):
				return String(
					localized: "UPDATE_ERROR",
					defaultValue: "The UPDATE request wasn't successful: \(error.localizedDescription)",
					bundle: Bundle.module
				)
			case .deleteError(let error):
				return String(
					localized: "DELETE_ERROR",
					defaultValue: "The DELETE request wasn't successful: \(error.localizedDescription)",
					bundle: Bundle.module
				)
			case .findError(let error):
				return String(
					localized: "FIND_ERROR",
					defaultValue: "The FIND request wasn't successful: \(error.localizedDescription)",
					bundle: Bundle.module
				)
			case .unknownResponse:
				return String(
					localized: "UNKNOWN_RESPONSE_ERROR",
					defaultValue: "The response from CouchDB was unrecognized or invalid.",
					bundle: Bundle.module
				)
			case .unauthorized:
				return String(
					localized: "UNAUTHORIZED_ERROR",
					defaultValue: "Authentication failed due to an incorrect username or password.",
					bundle: Bundle.module
				)
			case .noData:
				return String(
					localized: "NO_DATA_ERROR",
					defaultValue: "The response body is missing the expected data.",
					bundle: Bundle.module
				)
			}
		} else {
			switch self {
			case .idMissing:
				return NSLocalizedString("ID_MISSING_ERROR", tableName: nil, bundle: Bundle.module, value: "The 'id' property is empty or missing in the provided document.", comment: "Error description for missing document ID")
			case .revMissing:
				return NSLocalizedString("REV_MISSING_ERROR", tableName: nil, bundle: Bundle.module, value: "The '_rev' property is empty or missing in the provided document.", comment: "Error description for missing revision field")
			case .getError(let error):
				return NSLocalizedString("GET_ERROR", tableName: nil, bundle: Bundle.module, value: "The GET request wasn't successful: \(error.localizedDescription)", comment: "GET request failure message")
			case .insertError(let error):
				return NSLocalizedString("INSERT_ERROR", tableName: nil, bundle: Bundle.module, value: "The INSERT request wasn't successful: \(error.localizedDescription)", comment: "INSERT request failure message")
			case .updateError(let error):
				return NSLocalizedString("UPDATE_ERROR", tableName: nil, bundle: Bundle.module, value: "The UPDATE request wasn't successful: \(error.localizedDescription)", comment: "UPDATE request failure message")
			case .deleteError(let error):
				return NSLocalizedString("DELETE_ERROR", tableName: nil, bundle: Bundle.module, value: "The DELETE request wasn't successful: \(error.localizedDescription)", comment: "DELETE request failure message")
			case .findError(let error):
				return NSLocalizedString("FIND_ERROR", tableName: nil, bundle: Bundle.module, value: "The FIND request wasn't successful: \(error.localizedDescription)", comment: "FIND request failure message")
			case .unknownResponse:
				return NSLocalizedString("UNKNOWN_RESPONSE_ERROR", tableName: nil, bundle: Bundle.module, value: "The response from CouchDB was unrecognized or invalid.", comment: "Unknown response message")
			case .unauthorized:
				return NSLocalizedString("UNAUTHORIZED_ERROR", tableName: nil, bundle: Bundle.module, value: "Authentication failed due to an incorrect username or password.", comment: "Unauthorized access message")
			case .noData:
				return NSLocalizedString("NO_DATA_ERROR", tableName: nil, bundle: Bundle.module, value: "The response body is missing the expected data.", comment: "No data error message")
			}
		}
	}
}
