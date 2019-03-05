//
//  CouchUpdateResponse.swift
//  couchdb-vapor
//
//  Created by Sergey Armodin on 06/03/2019.
//

import Foundation


struct CouchUpdateResponse {
	var ok: Bool
	var id: String
	var rev: String
}
