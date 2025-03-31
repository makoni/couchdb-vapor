//
//  CouchDBFindResponse.swift
//
//
//  Created by Gregorio Gevartosky Torrezan on 2023-11-15.
//

import Foundation

public struct CouchDBFindResponse<T: CouchDBRepresentable>: Codable, Sendable {
	let docs: [T]
    let bookmark: String?
}
