# ``CouchDBClient``

A simple CouchDB client written in Swift.

## Overview

Source code is available on [GitHub](https://github.com/makoni/couchdb-vapor).

CouchDBClient allows you to make simple requests to CouchDB. It's using Swift Concurrency (async/await) and supports Linux, iOS 13+ and macOS 10.15+.

It's using [AsyncHTTPClient](https://github.com/swift-server/async-http-client) which makes it easy to use CouchDBClient for  server-side development with Vapor 4.

Currently CouchDBClient supports:
- Check if DB exists.
- Create DB.
- Delete DB.
- Get databases list.
- Get document by id or documents using view.
- Insert/update documents.
- Delete documents.
- CouchDB authorization.

## Topics

### Essentials

- <doc:Tutorial-Table-of-Contents>
