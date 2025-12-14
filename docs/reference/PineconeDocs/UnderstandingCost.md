# Understanding cost

> Understand how costs are incurred in Pinecone.

For the latest pricing details, see [Pricing](https://www.pinecone.io/pricing/).

## Minimum usage

The Standard and Enterprise [pricing plans](https://www.pinecone.io/pricing/) include a monthly minimum usage committment:

| Plan       | Minimum usage |
| ---------- | ------------- |
| Starter    | \$0/month     |
| Standard   | \$50/month    |
| Enterprise | \$500/month   |

Beyond the monthly minimum, customers are charged for what they use each month.

**Examples**

<AccordionGroup>
  <Accordion title="Usage below monthly minimum">
    * You are on the Standard plan.
    * Your usage for the month of August amounts to \$20.
    * Your usage is below the \$50 monthly minimum, so your total for the month is \$50.

    In this case, the August invoice would include line items for each service you used (totaling \$20), plus a single line item covering the rest of the minimum usage commitment (\$30).
  </Accordion>

  <Accordion title="Usage exceeds monthly minimum">
    * You are on the Standard plan.
    * Your usage for the month of August amounts to \$100.
    * Your usage exceeds the \$50 monthly minimum, so your total for the month is \$100.

    In this case, the August invoice would only show line items for each service you used (totaling \$100). Since your usage exceeds the minimum usage commitment, you are only charged for your actual usage and no additional minimum usage line item appears on your invoice.
  </Accordion>
</AccordionGroup>

## Serverless indexes

With serverless indexes, you pay for the amount of data stored and operations performed, based on three usage metrics: [read units](#read-units), [write units](#write-units), and [storage](#storage).

For the latest serverless pricing rates, see [Pricing](https://www.pinecone.io/pricing/).

### Read units

Read units (RUs) measure the compute, I/O, and network resources consumed by the following read requests:

* [Query](#query)
* [Fetch](#fetch)
* [List](#list)

<Tip>
  Read requests return the number of RUs used. You can use this information to [monitor read costs](/guides/manage-cost/monitor-usage-and-costs#read-units).
</Tip>

#### Query

The cost of a query scales linearly with the size of the targeted namespace. Specifically, a query uses 1 RU for every 1 GB of [namespace size](#storage), with a minimum of 0.25 RUs per query.

For example, the following table contains the RU cost of searching indexes at different namespace sizes:

<Tabs>
  <Tab title="Dense index">
    | Records    | Dense dimension | Avg. metadata size | Avg. record size | Namespace size | RUs  |
    | :--------- | :-------------- | :----------------- | :--------------- | :------------- | :--- |
    | 500,000    | 768             | 500 bytes          | 3.57 KB          | 1.78 GB        | 1.78 |
    | 1,000,000  | 1536            | 1000 bytes         | 7.14 KB          | 7.14 GB        | 7.14 |
    | 5,000,000  | 1024            | 15,000 bytes       | 19.10 KB         | 95.5 GB        | 95.5 |
    | 10,000,000 | 1536            | 1000 bytes         | 7.14 KB          | 71.4 GB        | 71.4 |
  </Tab>

  <Tab title="Sparse index">
    | Records    | Sparse non-zero values | Avg. metadata size | Avg. record size | Namespace size | RUs  |
    | :--------- | :--------------------- | :----------------- | :--------------- | :------------- | :--- |
    | 500,000    | 10                     | 500 bytes          | 0.09 KB          | 0.045 GB       | 0.25 |
    | 1,000,000  | 50                     | 1000 bytes         | 1.45 KB          | 1.45 GB        | 1.45 |
    | 5,000,000  | 100                    | 15,000 bytes       | 15.9 KB          | 79.5 GB        | 79.5 |
    | 10,000,000 | 50                     | 1000 bytes         | 1.45 KB          | 14.5 GB        | 14.5 |
  </Tab>

  <Tab title="Hybrid index">
    | Records    | Dense dimension | Sparse non-zero values | Avg. metadata size | Avg. record size | Namespace size | RUs  |
    | :--------- | :-------------- | :--------------------- | :----------------- | :--------------- | :------------- | :--- |
    | 500,000    | 768             | 10                     | 500 bytes          | 3.67 KB          | 1.83 GB        | 1.83 |
    | 1,000,000  | 1536            | 50                     | 1000 bytes         | 7.34 KB          | 7.34 GB        | 7.34 |
    | 5,000,000  | 1024            | 100                    | 15,000 bytes       | 19.44 KB         | 97.2 GB        | 97.2 |
    | 10,000,000 | 1536            | 50                     | 1000 bytes         | 7.34 KB          | 73.4 GB        | 73.4 |
  </Tab>
</Tabs>

<Note>
  Parameters that affect the size of the query response, such as `top_k`, `include_metadata`, and `include_values`, are not relevant for query cost; only the size of the namespace determines the number of RUs used.
</Note>

#### Fetch

A fetch request uses 1 RU for every 10 records fetched, for example:

| Fetched records | RUs |
| --------------- | --- |
| 10              | 1   |
| 50              | 5   |
| 107             | 11  |

Specifying a non-existent ID or adding the same ID more than once does not increase the number of RUs used. However, a fetch request will always use at least 1 RU.

<Note>
  [Fetching records by metadata](/guides/manage-data/fetch-data#fetch-records-by-metadata) uses the same cost model as fetching by ID: 1 RU for every 10 records fetched.
</Note>

#### List

List has a fixed cost of 1 RU per call, with up to 100 records per call.

### Write units

Write units (WUs) measure the storage and compute resources used by the following write requests:

* [Upsert](#upsert)
* [Update](#update)
* [Delete](#delete)

#### Upsert

An upsert request uses 1 WU for each 1 KB of the request, with a minimum of 5 WUs per request. When an upsert modifies an existing record, the request uses 1 WU for each 1 KB of the existing record as well.

For example, the following table shows the WUs used by upsert requests at different batch sizes and record sizes, assuming all records are new:

| Records per batch | Dimension | Avg. metadata size | Avg. record size | WUs  |
| :---------------- | :-------- | :----------------- | :--------------- | :--- |
| 1                 | 768       | 100 bytes          | 3.2 KB           | 5    |
| 2                 | 768       | 100 bytes          | 3.2 KB           | 7    |
| 10                | 1024      | 15,000 bytes       | 19.10 KB         | 191  |
| 100               | 768       | 500 bytes          | 3.57 KB          | 357  |
| 1000              | 1536      | 1000 bytes         | 7.14 KB          | 7140 |

#### Update

An update request uses 1 WU for each 1 KB of the new and existing record, with a minimum of 5 WUs per request.

For example, the following table shows the WUs used by an update at different record sizes:

| New record size | Previous record size | WUs |
| :-------------- | :------------------- | :-- |
| 6.24 KB         | 6.50 KB              | 13  |
| 19.10 KB        | 15 KB                | 25  |
| 3.57 KB         | 5 KB                 | 9   |
| 7.14 KB         | 10 KB                | 18  |
| 3.17 KB         | 3.17 KB              | 7   |

<Note>
  [Updating records by metadata](/guides/manage-data/update-data#update-by-metadata) uses the same cost model as updating by ID: 1 WU for each 1 KB of the new and existing record.
</Note>

#### Delete

A delete request uses 1 WU for each 1 KB of records deleted, with a minimum of 5 WUs per request.

For example, the following table shows the WUs used by delete requests at different batch sizes and record sizes:

| Records per batch | Dimension | Avg. metadata size | Avg. record size | WUs  |
| :---------------- | :-------- | :----------------- | :--------------- | :--- |
| 1                 | 768       | 100 bytes          | 3.2 KB           | 5    |
| 2                 | 768       | 100 bytes          | 3.2 KB           | 7    |
| 10                | 1024      | 15,000 bytes       | 19.10 KB         | 191  |
| 100               | 768       | 500 bytes          | 3.57 KB          | 357  |
| 1000              | 1536      | 1000 bytes         | 7.14 KB          | 7140 |

Specifying a non-existent ID or adding the same ID more than once does not increase WU use.

[Deleting a namespace](/guides/manage-data/manage-namespaces#delete-a-namespace) or [deleting all records in a namespace using `deleteAll`](/guides/manage-data/delete-data#delete-all-records-in-a-namespace) uses 5 WUs.

<Note>
  [Deleting records by metadata](/guides/manage-data/delete-data#delete-records-by-metadata) uses the same cost model as deleting by ID: 1 WU for each 1 KB of records deleted.
</Note>

### Storage

Storage costs are based on the size of an index on a per-Gigabyte (GB) monthly rate. For the latest storage pricing rates, see [Pricing](https://www.pinecone.io/pricing/?plan=standard\&provider=aws\&plans=database\&scrollTo=product-pricing-modal-section).

* The size of an index is defined as the total size of its records across all namespaces.

* The size of a single record is defined as the sum of the following components:

  * ID size
  * Dense vector size (equal to 4 \* the dense dimensions)
  * Sparse vector size (equal to 9 \* each non-zero sparse value)
  * Total metadata size (equal to the total size of all metadata fields)

  Sparse vector size is relevant only for [sparse indexes](/guides/index-data/indexing-overview#sparse-indexes) and [hybrid indexes](/guides/search/hybrid-search#use-a-single-hybrid-index).

The following tables demonstrate index sizes at different record counts:

<Tabs>
  <Tab title="Dense index">
    | Records    | Dense dimension | Avg. metadata size | Avg. record size | Namespace size |
    | :--------- | :-------------- | :----------------- | :--------------- | :------------- |
    | 500,000    | 768             | 500 bytes          | 3.57 KB          | 1.78 GB        |
    | 1,000,000  | 1536            | 1000 bytes         | 7.14 KB          | 7.14 GB        |
    | 5,000,000  | 1024            | 15,000 bytes       | 19.10 KB         | 95.5 GB        |
    | 10,000,000 | 1536            | 1000 bytes         | 7.14 KB          | 71.4 GB        |
  </Tab>

  <Tab title="Sparse index">
    | Records    | Sparse non-zero values | Avg. metadata size | Avg. record size | Namespace size |
    | :--------- | :--------------------- | :----------------- | :--------------- | :------------- |
    | 500,000    | 10                     | 500 bytes          | 0.09 KB          | 0.045 GB       |
    | 1,000,000  | 50                     | 1000 bytes         | 1.45 KB          | 1.45 GB        |
    | 5,000,000  | 100                    | 15,000 bytes       | 15.9 KB          | 79.5 GB        |
    | 10,000,000 | 50                     | 1000 bytes         | 1.45 KB          | 14.5 GB        |
  </Tab>

  <Tab title="Hybrid index">
    | Records    | Dense dimension | Sparse non-zero values | Avg. metadata size | Avg. record size | Namespace size |
    | :--------- | :-------------- | :--------------------- | :----------------- | :--------------- | :------------- |
    | 500,000    | 768             | 10                     | 500 bytes          | 3.67 KB          | 1.83 GB        |
    | 1,000,000  | 1536            | 50                     | 1000 bytes         | 7.34 KB          | 7.34 GB        |
    | 5,000,000  | 1024            | 100                    | 15,000 bytes       | 19.44 KB         | 97.2 GB        |
    | 10,000,000 | 1536            | 50                     | 1000 bytes         | 7.34 KB          | 73.4 GB        |
  </Tab>
</Tabs>

## Imports

[Importing from object storage](/guides/index-data/import-data) is the most efficient and cost-effective method to load large numbers of records into an index. The cost of an import is based on the size of the records read, whether the records were imported successfully or not.

If the import operation fails (e.g., after encountering a vector of the wrong dimension in an import with `on_error="abort"`), you will still be charged for the records read. However, if the import fails because of an internal system error, you will not incur charges. In this case, the import will return the error message `"We were unable to process your request. If the problem persists, please contact us at https://support.pinecone.io"`.

For the latest import pricing rates, see [Pricing](https://www.pinecone.io/pricing/).

## Backups and restores

A [backup](/guides/manage-data/backups-overview) is a static copy of a serverless index. Both the cost of storing a backup and [restoring an index](/guides/manage-data/restore-an-index) from a backup is based on the size of the index. For the latest backup and restore pricing rates, see [Pricing](https://www.pinecone.io/pricing/?plan=standard\&provider=aws\&plans=database\&scrollTo=product-pricing-modal-section).

## Embedding

Pinecone hosts several [embedding models](/guides/index-data/create-an-index#embedding-models) so it's easy to manage your vector storage and search process on a single platform. You can use a hosted model to embed your data as an integrated part of upserting and querying, or you can use a hosted model to embed your data as a standalone operation.

Embedding costs are determined by how many [tokens](https://www.pinecone.io/learn/tokenization/) are in a request. In general, the more words contained in your passage or query, the more tokens you generate.

For example, if you generate embeddings for the query, "What is the maximum diameter of a red pine?", Pinecone Inference generates 10 tokens, then converts them into an embedding. If the price per token for your billing plan is \$.08 per million tokens, then this API call costs \$.00001.

To learn more about tokenization, see [Choosing an embedding model](https://www.pinecone.io/learn/series/rag/embedding-models-rundown/). For the latest embed pricing rates, see [Pricing](https://www.pinecone.io/pricing/?plan=standard\&provider=aws\&plans=inference\&scrollTo=product-pricing-modal-section).

<Tip>
  Embedding requests returns the total tokens generated. You can use this information to [monitor and manage embedding costs](/guides/manage-cost/monitor-usage-and-costs#embedding-tokens).
</Tip>

## Reranking

Pinecone hosts several [reranking models](/guides/search/rerank-results#reranking-models) so it's easy to manage two-stage vector retrieval on a single platform. You can use a hosted model to rerank results as an integrated part of a query, or you can use a hosted model to rerank results as a standalone operation.

Reranking costs are determined by the number of requests to the reranking model. For the latest rerank pricing rates, see [Pricing](https://www.pinecone.io/pricing/?plan=standard\&provider=aws\&plans=inference\&scrollTo=product-pricing-modal-section).

## Assistant

For details on how costs are incurred in Pinecone Assistant, see [Assistant pricing](/guides/assistant/pricing-and-limits).

## See also

* [Manage cost](/guides/manage-cost/manage-cost)
* [Monitor usage](/guides/manage-cost/monitor-usage-and-costs)
* [Pricing](https://www.pinecone.io/pricing/)
