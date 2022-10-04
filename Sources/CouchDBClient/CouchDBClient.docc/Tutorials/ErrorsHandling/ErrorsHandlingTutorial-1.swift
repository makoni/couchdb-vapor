Task {
    var doc = MyDoc(title: "My Document")
    
    try await couchDBClient.insert(dbName: dbName, doc: &doc)
    print(doc)
    
    doc.title = "Updated title"
    try await couchDBClient.update(dbName: dbName, doc: &doc)
    print(doc)
    
    let docFromDB: MyDoc = try await couchDBClient.get(dbName: dbName, uri: doc._id!)
    print(docFromDB)
    
    let deleteResponse = try await couchDBClient.delete(fromDb: dbName, doc: doc)
}
