//
//  CouchDBFindResponse.swift
//  
//
//  Created by Gregorio Gevartosky Torrezan on 2023-11-15.
//

import Foundation

public struct CouchDBFindResponse<T: CouchDBRepresentable>: Codable, Sendable {
    var docs: [T]
    var bookmark: String?
}
