# ``CouchDBClient/CouchDBClient``

CouchDB client.

## Overview

A CouchDB client class with methods using Swift Concurrency.

## Topics

### Initializer
- ``init(couchProtocol:couchHost:couchPort:userName:userPassword:)``

### Getting list of databases
- ``getAllDBs(worker:)``

### Requests to a database
- ``get(dbName:uri:queryItems:worker:)-5vf6k``
- ``get(dbName:uri:queryItems:worker:)-7h5ke``
- ``insert(dbName:body:worker:)``
- ``insert(dbName:doc:worker:)``
- ``update(dbName:doc:worker:)``
- ``update(dbName:uri:body:worker:)``
- ``delete(fromDb:doc:worker:)``
- ``delete(fromDb:uri:rev:worker:)``
