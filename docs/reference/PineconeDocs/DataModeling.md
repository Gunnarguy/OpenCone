# Data modeling

> Learn how to structure records for efficient data retrieval and management in Pinecone.

## Record format

<Tabs>
  <Tab title="Text">
    When you upsert raw text for Pinecone to convert to vectors automatically, each record consists of the following:

    * **ID**: A unique string identifier for the record.
    * **Text**: The raw text for Pinecone to convert to a dense vector for [semantic search](/guides/search/semantic-search) or a sparse vector for [lexical search](/guides/search/lexical-search), depending on the [embedding model](/guides/index-data/create-an-index#embedding-models) integrated with the index. This field name must match the `embed.field_map` defined in the index.
    * **Metadata** (optional): All additional fields are stored as record metadata. You can filter by metadata when searching or deleting records.

    <Note>
      Upserting raw text is supported only for [indexes with integrated embedding](/guides/index-data/indexing-overview#vector-embedding).
    </Note>

    Example:

    ```json  theme={null}
    {
      "_id": "document1#chunk1", 
      "chunk_text": "First chunk of the document content...", // Text to convert to a vector. 
      "document_id": "document1", // This and subsequent fields stored as metadata. 
      "document_title": "Introduction to Vector Databases",
      "chunk_number": 1,
      "document_url": "https://example.com/docs/document1", 
      "created_at": "2024-01-15",
      "document_type": "tutorial"
    }
    ```
  </Tab>

  <Tab title="Vectors">
    When you upsert pre-generated vectors, each record consists of the following:

    * **ID**: A unique string identifier for the record.
    * **Vector**: A dense vector for [semantic search](/guides/search/semantic-search), a sparse vector for [lexical search](/guides/search/lexical-search), or both for [hybrid search](/guides/search/hybrid-search) using a single hybrid index.
    * **Metadata** (optional):  A flat JSON document containing key-value pairs with additional information (nested objects are not supported). You can filter by metadata when searching or deleting records.

    <Note>
      When importing data from object storage, records must be in Parquet format. For more details, see [Import data](/guides/index-data/import-data#prepare-your-data).
    </Note>

    Example:

    <CodeGroup>
      ```json Dense theme={null}
      {
        "id": "document1#chunk1", 
        "values": [0.0236663818359375, -0.032989501953125, ..., -0.01041412353515625, 0.0086669921875], 
        "metadata": {
          "document_id": "document1",
          "document_title": "Introduction to Vector Databases",
          "chunk_number": 1,
          "chunk_text": "First chunk of the document content...",
          "document_url": "https://example.com/docs/document1",
          "created_at": "2024-01-15",
          "document_type": "tutorial"
        }
      }
      ```

      ```json Sparse theme={null}
      {
        "id": "document1#chunk1", 
        "sparse_values": {
          "values": [1.7958984, 0.41577148, ..., 4.4414062, 3.3554688],
          "indices": [822745112, 1009084850, ..., 3517203014, 3590924191]
        },
        "metadata": {
          "document_id": "document1",
          "document_title": "Introduction to Vector Databases",
          "chunk_number": 1,
          "chunk_text": "First chunk of the document content...",
          "document_url": "https://example.com/docs/document1",
          "created_at": "2024-01-15",
          "document_type": "tutorial"
        }
      }
      ```

      ```json Hybrid theme={null}
      {
        "id": "document1#chunk1", 
        "values": [0.0236663818359375, -0.032989501953125, ..., -0.01041412353515625, 0.0086669921875], 
        "sparse_values": {
          "values": [1.7958984, 0.41577148, ..., 4.4414062, 3.3554688],
          "indices": [822745112, 1009084850, ..., 3517203014, 3590924191]
        },
        "metadata": {
          "document_id": "document1",
          "document_title": "Introduction to Vector Databases",
          "chunk_number": 1,
          "chunk_text": "First chunk of the document content...",
          "document_url": "https://example.com/docs/document1",
          "created_at": "2024-01-15",
          "document_type": "tutorial"
        }
      }
      ```
    </CodeGroup>
  </Tab>
</Tabs>

## Use structured IDs

Use a structured, human-readable format for record IDs, including ID prefixes that reflect the type of data you're storing, for example:

* **Document chunks**: `document_id#chunk_number`
* **User data**: `user_id#data_type#item_id`
* **Multi-tenant data**: `tenant_id#document_id#chunk_id`

Choose a delimiter for your ID prefixes that won't appear elsewhere in your IDs. Common patterns include:

* `document1#chunk1` - Using hash delimiter
* `document1_chunk1` - Using underscore delimiter
* `document1:chunk1` - Using colon delimiter

Structuring IDs in this way provides several advantages:

* **Efficiency**: Applications can quickly identify which record it should operate on.
* **Clarity**: Developers can easily understand what they're looking at when examining records.
* **Flexibility**: ID prefixes enable list operations for fetching and updating records.

## Include metadata

Include [metadata key-value pairs](/guides/index-data/indexing-overview#metadata) that support your application's key operations, for example:

* **Enable query-time filtering**: Add fields for time ranges, categories, or other criteria for [filtering searches for increased accuracy and relevance](/guides/search/filter-by-metadata).
* **Link related chunks**: Use fields like `document_id` and `chunk_number` to keep track of related records and enable efficient [chunk deletion](#delete-chunks) and [document updates](#update-an-entire-document).
* **Link back to original data**: Include `chunk_text` or `document_url` for traceability and user display.

Metadata keys must be strings, and metadata values must be one of the following data types:

* String
* Number (integer or floating point, gets converted to a 64-bit floating point)
* Boolean (true, false)
* List of strings

<Note>
  Pinecone supports 40 KB of metadata per record.
</Note>

## Example

This example demonstrates how to manage document chunks in Pinecone using structured IDs and comprehensive metadata. It covers the complete lifecycle of chunked documents: upserting, searching, fetching, updating, and deleting chunks, and updating an entire document.

### Upsert chunks

When [upserting](/guides/index-data/upsert-data) documents that have been split into chunks, combine structured IDs with comprehensive metadata:

<Tabs>
  <Tab title="Upsert text">
    <Note>
      Upserting raw text is supported only for [indexes with integrated embedding](/guides/index-data/create-an-index#integrated-embedding).
    </Note>

    ```python Python theme={null}
    from pinecone.grpc import PineconeGRPC as Pinecone

    pc = Pinecone(api_key="YOUR_API_KEY")

    # To get the unique host for an index, 
    # see https://docs.pinecone.io/guides/manage-data/target-an-index
    index = pc.Index(host="INDEX_HOST")

    index.upsert_records(
      "example-namespace",
      [
        {
          "_id": "document1#chunk1", 
          "chunk_text": "First chunk of the document content...",
          "document_id": "document1",
          "document_title": "Introduction to Vector Databases",
          "chunk_number": 1,
          "document_url": "https://example.com/docs/document1",
          "created_at": "2024-01-15",
          "document_type": "tutorial"
        },
        {
          "_id": "document1#chunk2", 
          "chunk_text": "Second chunk of the document content...",
          "document_id": "document1",
          "document_title": "Introduction to Vector Databases", 
          "chunk_number": 2,
          "document_url": "https://example.com/docs/document1",
          "created_at": "2024-01-15",
          "document_type": "tutorial"
        },
        {
          "_id": "document1#chunk3", 
          "chunk_text": "Third chunk of the document content...",
          "document_id": "document1",
          "document_title": "Introduction to Vector Databases",
          "chunk_number": 3, 
          "document_url": "https://example.com/docs/document1",
          "created_at": "2024-01-15",
          "document_type": "tutorial"
        },
      ]
    )
    ```
  </Tab>

  <Tab title="Upsert vectors">
    ```python Python theme={null}
    from pinecone.grpc import PineconeGRPC as Pinecone

    pc = Pinecone(api_key="YOUR_API_KEY")

    # To get the unique host for an index, 
    # see https://docs.pinecone.io/guides/manage-data/target-an-index
    index = pc.Index(host="INDEX_HOST")

    index.upsert(
      namespace="example-namespace",
      vectors=[
        {
          "id": "document1#chunk1", 
          "values": [0.0236663818359375, -0.032989501953125, ..., -0.01041412353515625, 0.0086669921875], 
          "metadata": {
            "document_id": "document1",
            "document_title": "Introduction to Vector Databases",
            "chunk_number": 1,
            "chunk_text": "First chunk of the document content...",
            "document_url": "https://example.com/docs/document1",
            "created_at": "2024-01-15",
            "document_type": "tutorial"
          }
        },
        {
          "id": "document1#chunk2", 
          "values": [-0.0412445068359375, 0.028839111328125, ..., 0.01953125, -0.0174560546875],
          "metadata": {
            "document_id": "document1",
            "document_title": "Introduction to Vector Databases", 
            "chunk_number": 2,
            "chunk_text": "Second chunk of the document content...",
            "document_url": "https://example.com/docs/document1",
            "created_at": "2024-01-15",
            "document_type": "tutorial"
          }
        },
        {
          "id": "document1#chunk3", 
          "values": [0.0512237548828125, 0.041656494140625, ..., 0.02130126953125, -0.0394287109375],
          "metadata": {
            "document_id": "document1",
            "document_title": "Introduction to Vector Databases",
            "chunk_number": 3, 
            "chunk_text": "Third chunk of the document content...",
            "document_url": "https://example.com/docs/document1",
            "created_at": "2024-01-15",
            "document_type": "tutorial"
          }
        }
      ]
    )
    ```
  </Tab>
</Tabs>

### Search chunks

To search the chunks of a document, use a [metadata filter expression](/guides/search/filter-by-metadata#metadata-filter-expressions) that limits the search appropriately:

<Tabs>
  <Tab title="Search with text">
    <Note>
      Searching with text is supported only for [indexes with integrated embedding](/guides/index-data/create-an-index#integrated-embedding).
    </Note>

    ```python Python theme={null}
    from pinecone import Pinecone

    pc = Pinecone(api_key="YOUR_API_KEY")

    # To get the unique host for an index, 
    # see https://docs.pinecone.io/guides/manage-data/target-an-index
    index = pc.Index(host="INDEX_HOST")

    filtered_results = index.search(
        namespace="example-namespace", 
        query={
            "inputs": {"text": "What is a vector database?"}, 
            "top_k": 3,
            "filter": {"document_id": "document1"}
        },
        fields=["chunk_text"]
    )

    print(filtered_results)
    ```
  </Tab>

  <Tab title="Search with a vector">
    ```python Python theme={null}
    from pinecone.grpc import PineconeGRPC as Pinecone

    pc = Pinecone(api_key="YOUR_API_KEY")

    # To get the unique host for an index, 
    # see https://docs.pinecone.io/guides/manage-data/target-an-index
    index = pc.Index(host="INDEX_HOST")

    filtered_results = index.query(
        namespace="example-namespace",
        vector=[0.0236663818359375,-0.032989501953125, ..., -0.01041412353515625,0.0086669921875], 
        top_k=3,
        filter={
            "document_id": {"$eq": "document1"}
        },
        include_metadata=True,
        include_values=False
    )

    print(filtered_results)
    ```
  </Tab>
</Tabs>

### Fetch chunks

To retrieve all chunks for a specific document, first [list the record IDs](/guides/manage-data/list-record-ids) using the document prefix, and then [fetch](/guides/manage-data/fetch-data) the complete records:

```python Python theme={null}
from pinecone.grpc import PineconeGRPC as Pinecone

pc = Pinecone(api_key="YOUR_API_KEY")

# To get the unique host for an index, 
# see https://docs.pinecone.io/guides/manage-data/target-an-index
index = pc.Index(host="INDEX_HOST")

# List all chunks for document1 using ID prefix
chunk_ids = []
for record_id in index.list(prefix='document1#', namespace='example-namespace'):
    chunk_ids.append(record_id)

print(f"Found {len(chunk_ids)} chunks for document1")

# Fetch the complete records by ID
if chunk_ids:
    records = index.fetch(ids=chunk_ids, namespace='example-namespace')
    
    for record_id, record_data in records['vectors'].items():
        print(f"Chunk ID: {record_id}")
        print(f"Chunk text: {record_data['metadata']['chunk_text']}")
        # Process the vector values and metadata as needed
```

<Note>
  Pinecone is [eventually consistent](/guides/index-data/check-data-freshness), so it's possible that a write (upsert, update, or delete) followed immediately by a read (query, list, or fetch) may not return the latest version of the data. If your use case requires retrieving data immediately, consider implementing a small delay or [retry logic](/guides/production/error-handling#implement-retry-logic) after writes.
</Note>

### Update chunks

To [update](/guides/manage-data/update-data) specific chunks within a document, first list the chunk IDs, and then update individual records:

```python Python theme={null}
from pinecone.grpc import PineconeGRPC as Pinecone

pc = Pinecone(api_key="YOUR_API_KEY")

# To get the unique host for an index, 
# see https://docs.pinecone.io/guides/manage-data/target-an-index
index = pc.Index(host="INDEX_HOST")

# List all chunks for document1
chunk_ids = []
for record_id in index.list(prefix='document1#', namespace='example-namespace'):
    chunk_ids.append(record_id)

# Update specific chunks (e.g., update chunk 2)
if 'document1#chunk2' in chunk_ids:
    index.update(
        id='document1#chunk2',
        values=[<new dense vector>],
        set_metadata={
            "document_id": "document1",
            "document_title": "Introduction to Vector Databases - Revised",
            "chunk_number": 2,
            "chunk_text": "Updated second chunk content...",
            "document_url": "https://example.com/docs/document1",
            "created_at": "2024-01-15",
            "updated_at": "2024-02-15",
            "document_type": "tutorial"
        },
        namespace='example-namespace'
    )
    print("Updated chunk 2 successfully")
```

### Delete chunks

To [delete](/guides/manage-data/delete-data#delete-records-by-metadata) chunks of a document, use a [metadata filter expression](/guides/search/filter-by-metadata#metadata-filter-expressions) that limits the deletion appropriately:

```python Python theme={null}
from pinecone.grpc import PineconeGRPC as Pinecone

pc = Pinecone(api_key="YOUR_API_KEY")

# To get the unique host for an index, 
# see https://docs.pinecone.io/guides/manage-data/target-an-index
index = pc.Index(host="INDEX_HOST")

# Delete chunks 1 and 3
index.delete(
    namespace="example-namespace",
    filter={
        "document_id": {"$eq": "document1"},
        "chunk_number": {"$in": [1, 3]}
    }
)

# Delete all chunks for a document
index.delete(
    namespace="example-namespace",
    filter={
        "document_id": {"$eq": "document1"}
    }
)
```

### Update an entire document

When the amount of chunks or ordering of chunks for a document changes, the recommended approach is to first [delete all chunks using a metadata filter](/guides/manage-data/delete-data#delete-records-by-metadata), and then [upsert](/guides/index-data/upsert-data) the new chunks:

```python Python theme={null}
from pinecone.grpc import PineconeGRPC as Pinecone

pc = Pinecone(api_key="YOUR_API_KEY")

# To get the unique host for an index, 
# see https://docs.pinecone.io/guides/manage-data/target-an-index
index = pc.Index(host="INDEX_HOST")

# Step 1: Delete all existing chunks for the document
index.delete(
    namespace="example-namespace",
    filter={
        "document_id": {"$eq": "document1"}
    }
)

print("Deleted existing chunks for document1")

# Step 2: Upsert the updated document chunks
index.upsert(
  namespace="example-namespace", 
  vectors=[
    {
      "id": "document1#chunk1",
      "values": [<updated dense vector>],
      "metadata": {
        "document_id": "document1",
        "document_title": "Introduction to Vector Databases - Updated Edition",
        "chunk_number": 1,
        "chunk_text": "Updated first chunk with new content...",
        "document_url": "https://example.com/docs/document1",
        "created_at": "2024-02-15",
        "document_type": "tutorial",
        "version": "2.0"
      }
    },
    {
      "id": "document1#chunk2",
      "values": [<updated dense vector>],
      "metadata": {
        "document_id": "document1",
        "document_title": "Introduction to Vector Databases - Updated Edition",
        "chunk_number": 2,
        "chunk_text": "Updated second chunk with new content...",
        "document_url": "https://example.com/docs/document1",
        "created_at": "2024-02-15",
        "document_type": "tutorial",
        "version": "2.0"
      }
    }
    # Add more chunks as needed for the updated document
  ]
)

print("Successfully updated document1 with new chunks")
```

## Data freshness

Pinecone is [eventually consistent](/guides/index-data/check-data-freshness), so it's possible that a write (upsert, update, or delete) followed immediately by a read (query, list, or fetch) may not return the latest version of the data. If your use case requires retrieving data immediately, consider implementing a small delay or [retry logic](/guides/production/error-handling#implement-retry-logic) after writes.
