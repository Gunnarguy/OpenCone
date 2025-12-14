# Concepts

> Understand concepts in Pinecone and how they relate to each other.

<img className="block max-w-full dark:hidden" noZoom src="https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/objects.png?fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=6a1fed2139efe425406492dd141479e5" data-og-width="1560" width="1560" data-og-height="1080" height="1080" data-path="images/objects.png" data-optimize="true" data-opv="3" srcset="https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/objects.png?w=280&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=15a583143f38fe67a9779528372965ea 280w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/objects.png?w=560&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=b03b7fe3958699814d8f7600ccb35e31 560w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/objects.png?w=840&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=872bdd974921197be14dea5ea341a647 840w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/objects.png?w=1100&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=96031734ef609a1bf4ce017d47a47fd0 1100w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/objects.png?w=1650&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=73fcff368598a3dba7d66b003fbc1fa9 1650w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/objects.png?w=2500&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=5c9e9fd81f32f83f85d79469de2f95e9 2500w" />

<img className="hidden max-w-full dark:block" noZoom src="https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/objects-dark.png?fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=361fa6648a258883c2265e90a22465bb" data-og-width="1560" width="1560" data-og-height="1080" height="1080" data-path="images/objects-dark.png" data-optimize="true" data-opv="3" srcset="https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/objects-dark.png?w=280&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=49658c275fcaddc3171e318819b5de5a 280w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/objects-dark.png?w=560&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=41c0c829761a10e98db5e190abe1c4a8 560w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/objects-dark.png?w=840&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=38f01332bd715a340fbcbad69834dccd 840w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/objects-dark.png?w=1100&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=a879c00cc550e8816d7052c347331086 1100w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/objects-dark.png?w=1650&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=bd8b507daf829f6ff0ba2a75658404fe 1650w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/objects-dark.png?w=2500&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=f1b320141a2668e5f32cc2566aa6820c 2500w" />

## Organization

An organization is a group of one or more [projects](#project) that use the same billing. Organizations allow one or more [users](#user) to control billing and permissions for all of the projects belonging to the organization.

For more information, see [Understanding organizations](/guides/organizations/understanding-organizations).

## Project

A project belongs to an [organization](#organization) and contains one or more [indexes](#index). Each project belongs to exactly one organization, but only [users](#user) who belong to the project can access the indexes in that project. [API keys](#api-key) and [Assistants](#assistant) are project-specific.

For more information, see [Understanding projects](/guides/projects/understanding-projects).

## Index

There are two types of [serverless indexes](/guides/index-data/indexing-overview), dense and sparse.

### Dense index

A dense index stores [dense vectors](#dense-vector), which are a series of numbers that represent the meaning and relationships of text, images, or other types of data. Each number in a dense vector corresponds to a point in a multidimensional space. Vectors that are closer together in that space are semantically similar.

When you query a dense index, Pinecone retrieves the dense vectors that are the most semantically similar to the query. This is often called **semantic search**, nearest neighbor search, similarity search, or just vector search.

### Sparse index

A sparse index stores [sparse vectors](#sparse-vector), which are a series of numbers that represent the words or phrases in a document. Sparse vectors have a very large number of dimensions, where only a small proportion of values are non-zero. The dimensions represent words from a dictionary, and the values represent the importance of these words in the document.

When you search a sparse index, Pinecone retrieves the sparse vectors that most exactly match the words or phrases in the query. Query terms are scored independently and then summed, with the most similar records scored highest. This is often called **lexical search** or **keyword search**.

## Namespace

A namespace is a partition within a [dense](#dense-index) or [sparse index](#sparse-index). It divides [records](#record) in an index into separate groups.

All [upserts](/guides/index-data/upsert-data), [queries](/guides/search/search-overview), and other [data operations](/reference/api/latest/data-plane) always target one namespace:

<img className="block max-w-full dark:hidden" noZoom src="https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert.png?fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=641c2aa9a3238bf70698c583097c1f29" data-og-width="1400" width="1400" data-og-height="880" height="880" data-path="images/quickstart-upsert.png" data-optimize="true" data-opv="3" srcset="https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert.png?w=280&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=5b394ed73cf8248f9a9ae8f9d3cdbd2d 280w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert.png?w=560&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=3bd0b45458ebbcab40605f149b5847d5 560w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert.png?w=840&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=9c1e1b064228344b3caf4c0a1aa8ab82 840w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert.png?w=1100&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=d40dd481d2e7cc8882d766d6df59fcba 1100w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert.png?w=1650&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=bf6be475e7bed3453299f6bbecd6aa54 1650w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert.png?w=2500&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=46c9efa0b08b8ac3c907a121289c19f2 2500w" />

<img className="hidden max-w-full dark:block" noZoom src="https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert-dark.png?fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=14a3e6c2847455db0821ebbf9bd51df9" data-og-width="1400" width="1400" data-og-height="880" height="880" data-path="images/quickstart-upsert-dark.png" data-optimize="true" data-opv="3" srcset="https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert-dark.png?w=280&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=229b97b3ea4581730afab68709201084 280w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert-dark.png?w=560&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=02fcdee17c689d31769c145fb86f259b 560w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert-dark.png?w=840&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=dd13a98f1154ffd8c4cc7cd4d37c0d33 840w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert-dark.png?w=1100&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=b13689e423b344828452efcf91c737b4 1100w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert-dark.png?w=1650&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=319293ecf19a483936595aaebfb5cb31 1650w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/quickstart-upsert-dark.png?w=2500&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=78ad3d1499ae4d57ff9e9cd0a8e56093 2500w" />

For more information, see [Use namespaces](/guides/index-data/indexing-overview#namespaces).

## Record

A record is a basic unit of data and consists of a [record ID](#record-id), a [dense vector](#dense-vector) or a [sparse vector](#sparse-vector) (depending on the type of index), and optional [metadata](#metadata).

For more information, see [Upsert data](/guides/index-data/upsert-data).

### Record ID

A record ID is a record's unique ID. [Use ID prefixes](/guides/index-data/data-modeling#use-structured-ids) that reflect the type of data you're storing.

### Dense vector

A dense vector, also referred to as a vector embedding or simply a vector, is a series of numbers that represent the meaning and relationships of data. Each number in a dense vector corresponds to a point in a multidimensional space. Vectors that are closer together in that space are semantically similar.

Dense vectors are stored in [dense indexes](#dense-index).

You use a dense embedding model to convert data to dense vectors. The embedding model can be external to Pinecone or [hosted on Pinecone infrastructure](/guides/index-data/create-an-index#embedding-models) and integrated with an index.

For more information about dense vectors, see [What are vector embeddings?](https://www.pinecone.io/learn/vector-embeddings/).

### Sparse vector

A sparse vector, also referred to as a sparse vector embedding, has a large number of dimensions, but only a small proportion of those values are non-zero. Sparse vectors are often used to represent documents or queries in a way that captures keyword information. Each dimension in a sparse vector typically represents a word from a dictionary, and the non-zero values represent the importance of these words in the document.

Sparse vectors are stored in [sparse indexes](#sparse-index).

You use a sparse embedding model to convert data to sparse vectors. The embedding model can be external to Pinecone or [hosted on Pinecone infrastructure](/guides/index-data/create-an-index#embedding-models) and integrated with an index.

For more information about sparse vectors, see [Sparse retrieval](https://www.pinecone.io/learn/sparse-retrieval/).

### Metadata

Metadata is additional information that can be attached to vector embeddings to provide more context and enable additional [filtering capabilities](/guides/index-data/indexing-overview#metadata). For example, the original text of the embeddings can be stored in the metadata.

## Other concepts

Although not represented in the diagram above, Pinecone also contains the following concepts:

* [API key](#api-key)
* [User](#user)
* [Backup or collection](#backup-or-collection)
* [Pinecone Inference](#pinecone-inference)

### API key

An API key is a unique token that [authenticates](/reference/api/authentication) and authorizes access to the [Pinecone APIs](/reference/api/introduction). API keys are project-specific.

### User

A user is a member of organizations and projects. Users are assigned specific roles at the organization and project levels that determine the user's permissions in the [Pinecone console](https://app.pinecone.io).

For more information, see [Manage organization members](/guides/organizations/manage-organization-members) and [Manage project members](/guides/projects/manage-project-members).

### Backup or collection

A backup is a static copy of a serverless index.

Backups only consume storage. They are non-queryable representations of a set of records. You can create a backup from an index, and you can create a new index from that backup. The new index configuration can differ from the original source index: for example, it can have a different name. However, it must have the same number of dimensions and similarity metric as the source index.

For more information, see [Understanding backups](/guides/manage-data/backups-overview).

### Pinecone Inference

Pinecone Inference is an API service that provides access to [embedding models](/guides/index-data/create-an-index#embedding-models) and [reranking models](/guides/search/rerank-results#reranking-models) hosted on Pinecone's infrastructure.

## Learn more

* [Vector database](https://www.pinecone.io/learn/vector-database/)
* [Pinecone APIs](/reference/api/introduction)
* [Approximate nearest neighbor (ANN) algorithms](https://www.pinecone.io/learn/a-developers-guide-to-ann-algorithms/)
* [Retrieval augmented generation (RAG)](https://www.pinecone.io/learn/retrieval-augmented-generation/)
* [Image search](https://www.pinecone.io/learn/series/image-search/)
* [Tokenization](https://www.pinecone.io/learn/tokenization/)
