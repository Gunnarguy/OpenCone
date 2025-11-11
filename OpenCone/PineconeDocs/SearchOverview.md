# Search overview

> Explore semantic, lexical, and hybrid search options.

## Search types

* [Semantic search](/guides/search/semantic-search)
* [Lexical search](/guides/search/lexical-search)
* [Hybrid search](/guides/search/hybrid-search)

## Optimization

* [Filter by metadata](/guides/search/filter-by-metadata)
* [Rerank results](/guides/search/rerank-results)
* [Parallel queries](/guides/search/semantic-search#parallel-queries)

## Limits

| Metric            | Limit  |
| :---------------- | :----- |
| Max `top_k` value | 10,000 |
| Max result size   | 4MB    |

The query result size is affected by the dimension of the dense vectors and whether or not dense vector values and metadata are included in the result.

<Tip>
  If a query fails due to exceeding the 4MB result size limit, choose a lower `top_k` value, or use `include_metadata=False` or `include_values=False` to exclude metadata or values from the result.
</Tip>

## Cost

* To understand how cost is calculated for queries, see [Understanding cost](/guides/manage-cost/understanding-cost#query).
* For up-to-date pricing information, see [Pricing](https://www.pinecone.io/pricing/).

## Data freshness

Pinecone is eventually consistent, so there can be a slight delay before new or changed records are visible to queries. You can view index stats to [check data freshness](/guides/index-data/check-data-freshness).
