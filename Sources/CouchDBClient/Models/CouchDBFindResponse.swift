//
//  CouchDBFindResponse.swift
//  
//
//  Created by Gregorio Gevartosky Torrezan on 2023-11-15.
//

import Foundation

public struct CouchDBFindResponse<T: Codable & CouchDBRepresentable>: Codable {
    var docs: [T]
    var bookmark: String?
}
