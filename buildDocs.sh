#!/bin/bash

swift package --allow-writing-to-directory ~/Downloads \
    generate-documentation \
    --target CouchDBClient \
    --disable-indexing \
    --output-path ~/Downloads/couchdbclient \
    --transform-for-static-hosting \
    --hosting-base-path docs/couchdbclient
