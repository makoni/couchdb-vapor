# ``CouchDBClient``

A lightweight and powerful CouchDB client written in Swift.

## Overview

The source code is available on [GitHub](https://github.com/makoni/couchdb-swift).

`CouchDBClient` simplifies interactions with CouchDB by providing an easy-to-use API built with Swift Concurrency (`async/await`). It supports a wide range of platforms, including:

- **Linux**
- **iOS 13+**
- **iPadOS 13+**
- **tvOS 13+**
- **watchOS 6+**
- **visionOS 1.0+**
- **macOS 10.15+**

Built on top of [AsyncHTTPClient](https://github.com/swift-server/async-http-client), `CouchDBClient` is ideal for server-side development with Vapor and Hummingbird but is equally suitable for iOS and macOS applications. Check the **Essentials** section for usage examples.

### Features

`CouchDBClient` currently supports the following operations:

- **Database Management**:
  - Check if a database exists.
  - Create a database.
  - Delete a database.
  - Retrieve a list of all databases.

- **Document Operations**:
  - Get a document by ID or retrieve documents using a view.
  - Insert or update documents.
  - Find documents using a selector.
  - Delete documents.

- **Authorization**:
  - Authenticate with CouchDB.

## Topics

### Essentials

- <doc:Tutorial-Table-of-Contents>
