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
- ``get(dbName:uri:queryItems:eventLoopGroup:)-2fzuv``
- ``get(dbName:uri:queryItems:eventLoopGroup:)-53osp``
- ``insert(dbName:doc:eventLoopGroup:)``
- ``insert(dbName:body:eventLoopGroup:)``
- ``update(dbName:doc:eventLoopGroup:)``
- ``update(dbName:uri:body:eventLoopGroup:)``
- ``delete(fromDb:doc:eventLoopGroup:)``
- ``delete(fromDb:uri:rev:eventLoopGroup:)``
