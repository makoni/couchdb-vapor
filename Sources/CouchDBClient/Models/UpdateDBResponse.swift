//
//  UpdateDBResponse.swift
//
//
//  Created by Sergei Armodin on 26.12.2022.
//

import Foundation

/// DB creation response.
public struct UpdateDBResponse: Codable, Sendable {
	/// Operation status.
	public let ok: Bool
}
