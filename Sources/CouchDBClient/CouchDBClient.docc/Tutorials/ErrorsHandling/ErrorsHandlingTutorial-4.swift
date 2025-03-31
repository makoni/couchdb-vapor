Task {
	var doc = MyDoc(title: "My Document")

	do {
		doc = try await couchDBClient.insert(dbName: dbName, doc: doc)
	} catch CouchDBClientError.insertError(let error) {
		print(error.reason)
		return
	} catch {
		print(error.localizedDescription)
		return
	}
	print(doc)

	doc.title = "Updated title"
	do {
		doc = try await couchDBClient.update(dbName: dbName, doc: doc)
	} catch CouchDBClientError.updateError(let error) {
		print(error.reason)
		return
	} catch {
		print(error.localizedDescription)
		return
	}
	print(doc)

	do {
		let docFromDB: MyDoc = try await couchDBClient.get(fromDB: dbName, uri: doc._id)
	} catch CouchDBClientError.getError(let error) {
		print(error.reason)
		return
	} catch {
		print(error.localizedDescription)
		return
	}
	print(docFromDB)

	let deleteResponse = try await couchDBClient.delete(fromDb: dbName, doc: doc)
}
