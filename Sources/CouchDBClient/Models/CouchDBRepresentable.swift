//
//  CouchDBRepresentable.swift
//  
//
//  Created by Sergey Armodin on 30.08.2022.
//

import Foundation

/// CouchDB document
public protocol CouchDBRepresentable: Codable {
	/// Document ID
	var _id: String? { get set }
	/// Document revision
	var _rev: String? { get set }
}
