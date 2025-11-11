# Indexing overview

> Understand key concepts related to indexing data in Pinecone.

export const word_0 = "records"

## Indexes

In Pinecone, you store vector data in indexes. There are two types of indexes: dense and sparse.

### Dense indexes

Dense indexes store dense vectors, which are a series of numbers that represent the meaning and relationships of text, images, or other types of data. Each number in a dense vector corresponds to a point in a multidimensional space. Vectors that are closer together in that space are semantically similar.

When you query a dense index, Pinecone retrieves the dense vectors that are the most semantically similar to the query. This is often called **semantic search**, nearest neighbor search, similarity search, or just vector search.

Learn more:

* [Create a dense index](/guides/index-data/create-an-index#create-a-dense-index)
* [Upsert dense vectors](/guides/index-data/upsert-data#upsert-dense-vectors)
* [Semantic search](/guides/search/semantic-search)

### Sparse indexes

Sparse indexes store sparse vectors, which are a series of numbers that represent the words or phrases in a document. Sparse vectors have a very large number of dimensions, where only a small proportion of values are non-zero. The dimensions represent words from a dictionary, and the values represent the importance of these words in the document.

When you search a sparse index, Pinecone retrieves the sparse vectors that most exactly match the words or phrases in the query. Query terms are scored independently and then summed, with the most similar records scored highest. This is often called **lexical search** or **keyword search**.

Learn more:

* [Create a sparse index](/guides/index-data/create-an-index#create-a-sparse-index)
* [Upsert sparse vectors](/guides/index-data/upsert-data#upsert-sparse-vectors)
* [Lexical search](/guides/search/lexical-search)

<Tip>
  Semantic search can miss results based on exact keyword matches, while lexical search can miss results based on relationships. To lift these limitations, you can perform [hybrid search](/guides/search/hybrid-search).
</Tip>

#### Limitations

<Note>
  These limitations are subject to change during the public preview period.
</Note>

Sparse indexes have the following limitations:

* Max non-zero values per sparse vector: 1000
* Max upserts per second per sparse index: 10
* Max queries per second per sparse index: 100
* Max `top_k` value per query: 1000

  <Note>
    You may get fewer than `top_k` results if `top_k` is larger than the number of sparse vectors in your index that match your query. That is, any vectors where the dotproduct score is `0` will be discarded.
  </Note>
* Max query results size: 4MB

## Namespaces

Within an index, records are partitioned into namespaces, and all [upserts](/guides/index-data/upsert-data), [queries](/guides/search/search-overview), and other [data operations](/guides/index-data/upsert-data) always target one namespace. This has two main benefits:

* **Multitenancy:** When you need to isolate data between customers, you can use one namespace per customer and target each customer's writes and queries to their dedicated namespace. See [Implement multitenancy](/guides/index-data/implement-multitenancy) for end-to-end guidance.

* **Faster queries:** When you divide records into namespaces in a logical way, you speed up queries by ensuring only relevant records are scanned. The same applies to fetching records, listing record IDs, and other data operations.

Namespaces are created automatically during [upsert](/guides/index-data/upsert-data). If a namespace doesn't exist, it is created implicitly.

<Note>
  While the Standard and Enterprise plans support up to [100,000 namespaces per index](/reference/api/database-limits#namespaces-per-serverless-index), Pinecone can accommodate million-scale namespaces and beyond for specific use cases. If your application requires more than 100,000 namespaces, [contact Support](https://app.pinecone.io/organizations/-/settings/support/ticket).
</Note>

<img className="block max-w-full dark:hidden" noZoom src="https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert.png?fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=641c2aa9a3238bf70698c583097c1f29" data-og-width="1400" width="1400" data-og-height="880" height="880" data-path="images/quickstart-upsert.png" data-optimize="true" data-opv="3" srcset="https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert.png?w=280&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=5b394ed73cf8248f9a9ae8f9d3cdbd2d 280w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert.png?w=560&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=3bd0b45458ebbcab40605f149b5847d5 560w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert.png?w=840&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=9c1e1b064228344b3caf4c0a1aa8ab82 840w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert.png?w=1100&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=d40dd481d2e7cc8882d766d6df59fcba 1100w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert.png?w=1650&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=bf6be475e7bed3453299f6bbecd6aa54 1650w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert.png?w=2500&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=46c9efa0b08b8ac3c907a121289c19f2 2500w" />

<img className="hidden max-w-full dark:block" noZoom src="https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert-dark.png?fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=14a3e6c2847455db0821ebbf9bd51df9" data-og-width="1400" width="1400" data-og-height="880" height="880" data-path="images/quickstart-upsert-dark.png" data-optimize="true" data-opv="3" srcset="https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert-dark.png?w=280&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=229b97b3ea4581730afab68709201084 280w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert-dark.png?w=560&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=02fcdee17c689d31769c145fb86f259b 560w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert-dark.png?w=840&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=dd13a98f1154ffd8c4cc7cd4d37c0d33 840w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert-dark.png?w=1100&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=b13689e423b344828452efcf91c737b4 1100w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert-dark.png?w=1650&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=319293ecf19a483936595aaebfb5cb31 1650w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert-dark.png?w=2500&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=78ad3d1499ae4d57ff9e9cd0a8e56093 2500w" />

## Vector embedding

[Dense vectors](/guides/get-started/concepts#dense-vector) and [sparse vectors](/guides/get-started/concepts#sparse-vector) are the basic units of data in Pinecone and what Pinecone was specially designed to store and work with. Dense vectors represents the semantics of data such as text, images, and audio recordings, while sparse vectors represent documents or queries in a way that captures keyword information.

To transform data into vector format, you use an embedding model. You can either use Pinecone's integrated embedding models to convert your source data to vectors automatically, or you can use an external embedding model and bring your own vectors to Pinecone.

### Integrated embedding

1. [Create an index](/guides/index-data/create-an-index) that is integrated with one of Pinecone's [hosted embedding models](/guides/index-data/create-an-index#embedding-models).
2. [Upsert](/guides/index-data/upsert-data) your source text. Pinecone uses the integrated model to convert the text to vectors automatically.
3. [Search](/guides/search/search-overview) with a query text. Again, Pinecone uses the integrated model to convert the text to a vector automatically.

<Note>
  Indexes with integrated embedding do not support [updating](/guides/manage-data/update-data) or [importing](/guides/index-data/import-data) with text.
</Note>

### Bring your own vectors

1. Use an embedding model to convert your text to vectors. The model can be [hosted by Pinecone](/reference/api/latest/inference/generate-embeddings) or an external provider.
2. [Create an index](/guides/index-data/create-an-index) that matches the characteristics of the model.
3. [Upsert](/guides/index-data/upsert-data) your vectors directly.
4. Use the same external embedding model to convert a query to a vector.
5. [Search](/guides/search/search-overview) with your query vector directly.

## Data ingestion

<Tip>
  To control costs when ingesting large datasets (10,000,000+ records), use [import](/guides/index-data/import-data) instead of upsert.
</Tip>

There are two ways to ingest data into an index:

* [Importing from object storage](/guides/index-data/import-data) is the most efficient and cost-effective way to load large numbers of records into an index. You store your data as Parquet files in object storage, integrate your object storage with Pinecone, and then start an asynchronous, long-running operation that imports and indexes your records.

* [Upserting](/guides/index-data/upsert-data) is intended for ongoing writes to an index. [Batch upserting](/guides/index-data/upsert-data#upsert-in-batches) can improve throughput performance and is a good option for larger numbers of records (up to 1000 per batch) if you cannot work around import's current limitations.

## Metadata

Every [record](/guides/get-started/concepts#record) in an index must contain an ID and a vector. In addition, you can include metadata key-value pairs to store additional information or context. When you query the index, you can then include a [metadata filter](/guides/search/filter-by-metadata) to limit the search to records matching a filter expression. Searches without metadata filters do not consider metadata and search the entire namespace.

### Metadata format

* Metadata fields must be key-value pairs in a flat JSON object. Nested JSON objects are not supported.
* Keys must be strings and must not start with a `$`.
* Values must be one of the following data types:
  * String
  * Integer (converted to a 64-bit floating point by Pinecone)
  * Floating point
  * Boolean (`true`, `false`)
  * List of strings
* Null metadata values aren't supported. Instead of setting a key to `null`, remove the key from the metadata payload.

**Examples**

<CodeGroup>
  ```json Valid metadata theme={null}
  {
    "document_id": "document1",
    "document_title": "Introduction to Vector Databases",
    "chunk_number": 1,
    "chunk_text": "First chunk of the document content...",
    "is_public": true,
    "tags": ["beginner", "database", "vector-db"],
    "scores": ["85", "92"]
  }
  ```

  ```json Invalid metadata theme={null}
  {
    "document": {       // Nested JSON objects are not supported
      "document_id": "document1",
      "document_title": "Introduction to Vector Databases",
    },
    "$chunk_number": 1, // Keys must not start with a `$`
    "chunk_text": null, // Null values are not supported
    "is_public": true,
    "tags": ["beginner", "database", "vector-db"],
    "scores": [85, 92]  // Lists of non-strings are not supported
  }
  ```
</CodeGroup>

### Metadata size

Pinecone supports 40KB of metadata per record.

### Metadata filter expressions

Pinecone's filtering language supports the following operators:

| Operator  | Function                                                                                                                           | Supported types         |
| :-------- | :--------------------------------------------------------------------------------------------------------------------------------- | :---------------------- |
| `$eq`     | Matches {word_0} with metadata values that are equal to a specified value. Example: `{"genre": {"$eq": "documentary"}}`            | Number, string, boolean |
| `$ne`     | Matches {word_0} with metadata values that are not equal to a specified value. Example: `{"genre": {"$ne": "drama"}}`              | Number, string, boolean |
| `$gt`     | Matches {word_0} with metadata values that are greater than a specified value. Example: `{"year": {"$gt": 2019}}`                  | Number                  |
| `$gte`    | Matches {word_0} with metadata values that are greater than or equal to a specified value. Example:`{"year": {"$gte": 2020}}`      | Number                  |
| `$lt`     | Matches {word_0} with metadata values that are less than a specified value. Example: `{"year": {"$lt": 2020}}`                     | Number                  |
| `$lte`    | Matches {word_0} with metadata values that are less than or equal to a specified value. Example: `{"year": {"$lte": 2020}}`        | Number                  |
| `$in`     | Matches {word_0} with metadata values that are in a specified array. Example: `{"genre": {"$in": ["comedy", "documentary"]}}`      | String, number          |
| `$nin`    | Matches {word_0} with metadata values that are not in a specified array. Example: `{"genre": {"$nin": ["comedy", "documentary"]}}` | String, number          |
| `$exists` | Matches {word_0} with the specified metadata field. Example: `{"genre": {"$exists": true}}`                                        | Number, string, boolean |
| `$and`    | Joins query clauses with a logical `AND`. Example: `{"$and": [{"genre": {"$eq": "drama"}}, {"year": {"$gte": 2020}}]}`             | -                       |
| `$or`     | Joins query clauses with a logical `OR`. Example: `{"$or": [{"genre": {"$eq": "drama"}}, {"year": {"$gte": 2020}}]}`               | -                       |

<Note>
  Only `$and` and `$or` are allowed at the top level of the query expression.
</Note>

For example, the following has a `"genre"` metadata field with a list of strings:

```JSON JSON theme={null}
{ "genre": ["comedy", "documentary"] }
```

This means `"genre"` takes on both values, and requests with the following filters will match:

```JSON JSON theme={null}
{"genre":"comedy"}

{"genre": {"$in":["documentary","action"]}}

{"$and": [{"genre": "comedy"}, {"genre":"documentary"}]}
```

However, requests with the following filter will **not** match:

```JSON JSON theme={null}
{ "$and": [{ "genre": "comedy" }, { "genre": "drama" }] }
```

Additionally, requests with the following filters will **not** match because they are invalid. They will result in a compilation error:

```json JSON theme={null}
# INVALID QUERY:
{"genre": ["comedy", "documentary"]}
```

```json JSON theme={null}
# INVALID QUERY:
{"genre": {"$eq": ["comedy", "documentary"]}}
```
