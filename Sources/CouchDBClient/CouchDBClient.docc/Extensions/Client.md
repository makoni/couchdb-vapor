# ``CouchDBClient/CouchDBClient``

CouchDB client.

## Overview

A CouchDB client class with methods using Swift Concurrency.

## Topics

### Initializer
- ``init(couchProtocol:couchHost:couchPort:userName:userPassword:)``

### Methods for databases
- ``getAllDBs(eventLoopGroup:)``
- ``createDB(_:eventLoopGroup:)``
- ``deleteDB(_:eventLoopGroup:)``
- ``dbExists(_:eventLoopGroup:)``

### Requests to a database
- ``createDB(_:eventLoopGroup:)``
- ``deleteDB(_:eventLoopGroup:)``
- ``dbExists(_:eventLoopGroup:)``
- ``get(dbName:uri:queryItems:eventLoopGroup:)``
- ``get(dbName:uri:queryItems:dateDecodingStrategy:eventLoopGroup:)``
- ``insert(dbName:body:eventLoopGroup:)``
- ``insert(dbName:doc:dateEncodingStrategy:eventLoopGroup:)``
- ``update(dbName:doc:dateEncodingStrategy:eventLoopGroup:)``
- ``update(dbName:uri:body:eventLoopGroup:)``
- ``delete(fromDb:doc:eventLoopGroup:)``
- ``delete(fromDb:uri:rev:eventLoopGroup:)``
