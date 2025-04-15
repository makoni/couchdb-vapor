# ``CouchDBClient/CouchDBClient``

A powerful and flexible CouchDB client for Swift, designed to simplify database interactions using Swift Concurrency.

## Overview

`CouchDBClient` provides a robust set of tools for interacting with CouchDB databases. It supports common database operations such as creating, deleting, and querying databases and documents. Built with Swift Concurrency, it ensures efficient and modern asynchronous programming.

This client is fully compatible with SwiftNIO, making it ideal for both server-side and client-side Swift applications.

## Topics

### Initialization
- ``init(config:httpClient:)``

### Database Management
- ``getAllDBs(eventLoopGroup:)``  
- ``createDB(_:eventLoopGroup:)``  
- ``deleteDB(_:eventLoopGroup:)``  
- ``dbExists(_:eventLoopGroup:)``  

### Document Operations
- ``insert(dbName:body:eventLoopGroup:)``  
- ``insert(dbName:doc:dateEncodingStrategy:eventLoopGroup:)``  
- ``update(dbName:doc:dateEncodingStrategy:eventLoopGroup:)``  
- ``update(dbName:uri:body:eventLoopGroup:)``  
- ``delete(fromDb:doc:eventLoopGroup:)``  
- ``delete(fromDb:uri:rev:eventLoopGroup:)``  

### Querying and Fetching
- ``get(fromDB:uri:queryItems:eventLoopGroup:)``  
- ``get(fromDB:uri:queryItems:dateDecodingStrategy:eventLoopGroup:)``  
- ``find(inDB:body:eventLoopGroup:)``  
- ``find(inDB:selector:dateDecodingStrategy:eventLoopGroup:)``  
