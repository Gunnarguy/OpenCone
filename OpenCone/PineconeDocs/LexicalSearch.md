# Lexical search

> Perform keyword-based search on sparse indexes

This page shows you how to search a [sparse index](/guides/index-data/indexing-overview#sparse-indexes) for records that most exactly match the words or phrases in a query. This is often called lexical search or keyword search.

Lexical search uses [sparse vectors](https://www.pinecone.io/learn/sparse-retrieval/), which have a very large number of dimensions, where only a small proportion of values are non-zero. The dimensions represent words from a dictionary, and the values represent the importance of these words in the document. Words are scored independently and then summed, with the most similar records scored highest.

## Search with text

<Note>
  Searching with text is supported only for [indexes with integrated embedding](/guides/index-data/indexing-overview#integrated-embedding).
</Note>

To search a sparse index with a query text, use the [`search_records`](/reference/api/latest/data-plane/search_records) operation with the following parameters:

* `namespace`: The [namespace](/guides/index-data/indexing-overview#namespaces) to query. To use the default namespace, set to `"__default__"`.
* `query.inputs.text`:  The query text. Pinecone uses the [embedding model](/guides/index-data/create-an-index#embedding-models) integrated with the index to convert the text to a sparse vector automatically.
* `query.top_k`:  The number of records to return.
* `query.match_terms`: (Optional) A list of terms that must be present in each search result. For more details, see [Filter by required terms](#filter-by-required-terms).
* `fields`: (Optional) The fields to return in the response. If not specified, the response includes all fields.

For example, the following code converts the query “What is AAPL's outlook, considering both product launches and market conditions?” to a sparse vector and then searches for the 3 most similar vectors in the `example-namespace` namespace:

<CodeGroup>
  ```python Python theme={null}
  from pinecone import Pinecone

  pc = Pinecone(api_key="YOUR_API_KEY")

  # To get the unique host for an index, 
  # see https://docs.pinecone.io/guides/manage-data/target-an-index
  index = pc.Index(host="INDEX_HOST")

  results = index.search(
      namespace="example-namespace", 
      query={
          "inputs": {"text": "What is AAPL's outlook, considering both product launches and market conditions?"}, 
          "top_k": 3
      },
      fields=["chunk_text", "quarter"]
  )

  print(results)
  ```

  ```javascript JavaScript theme={null}
  import { Pinecone } from '@pinecone-database/pinecone'

  const pc = new Pinecone({ apiKey: "YOUR_API_KEY" })

  // To get the unique host for an index, 
  // see https://docs.pinecone.io/guides/manage-data/target-an-index
  const namespace = pc.index("INDEX_NAME", "INDEX_HOST").namespace("example-namespace");

  const response = await namespace.searchRecords({
    query: {
      topK: 3,
      inputs: { text: "What is AAPL's outlook, considering both product launches and market conditions?" },
    },
    fields: ['chunk_text', 'quarter']
  });

  console.log(response);
  ```

  ```java Java theme={null}
  import io.pinecone.clients.Index;
  import io.pinecone.configs.PineconeConfig;
  import io.pinecone.configs.PineconeConnection;
  import org.openapitools.db_data.client.ApiException;
  import org.openapitools.db_data.client.model.SearchRecordsResponse;

  import java.util.*;

  public class SearchText {
      public static void main(String[] args) throws ApiException {
          PineconeConfig config = new PineconeConfig("YOUR_API_KEY");
          // To get the unique host for an index, 
          // see https://docs.pinecone.io/guides/manage-data/target-an-index
          config.setHost("INDEX_HOST");
          PineconeConnection connection = new PineconeConnection(config);

          Index index = new Index(config, connection, "integrated-sparse-java");

          String query = "What is AAPL's outlook, considering both product launches and market conditions?";
          List<String> fields = new ArrayList<>();
          fields.add("category");
          fields.add("chunk_text");

          // Search the sparse index
          SearchRecordsResponse recordsResponse = index.searchRecordsByText(query,  "example-namespace", fields, 3, null, null);

          // Print the results
          System.out.println(recordsResponse);
      }
  }
  ```

  ```go Go theme={null}
  package main

  import (
      "context"
      "encoding/json"
      "fmt"
      "log"

      "github.com/pinecone-io/go-pinecone/v4/pinecone"
  )

  func prettifyStruct(obj interface{}) string {
    	bytes, _ := json.MarshalIndent(obj, "", "  ")
      return string(bytes)
  }

  func main() {
      ctx := context.Background()

      pc, err := pinecone.NewClient(pinecone.NewClientParams{
          ApiKey: "YOUR_API_KEY",
      })
      if err != nil {
          log.Fatalf("Failed to create Client: %v", err)
      }

      // To get the unique host for an index, 
      // see https://docs.pinecone.io/guides/manage-data/target-an-index
      idxConnection, err := pc.Index(pinecone.NewIndexConnParams{Host: "INDEX_HOST", Namespace: "example-namespace"})
      if err != nil {
          log.Fatalf("Failed to create IndexConnection for Host: %v", err)
      } 

      res, err := idxConnection.SearchRecords(ctx, &pinecone.SearchRecordsRequest{
          Query: pinecone.SearchRecordsQuery{
              TopK: 3,
              Inputs: &map[string]interface{}{
                  "text": "What is AAPL's outlook, considering both product launches and market conditions?",
              },
          },
          Fields: &[]string{"chunk_text", "category"},
      })
      if err != nil {
          log.Fatalf("Failed to search records: %v", err)
      }
      fmt.Printf(prettifyStruct(res))
  }
  ```

  ```csharp C# theme={null}
  using Pinecone;

  var pinecone = new PineconeClient("YOUR_API_KEY");

  // To get the unique host for an index, 
  // see https://docs.pinecone.io/guides/manage-data/target-an-index
  var index = pinecone.Index(host: "INDEX_HOST");

  var response = await index.SearchRecordsAsync(
      "example-namespace",
      new SearchRecordsRequest
      {
          Query = new SearchRecordsRequestQuery
          {
              TopK = 3,
              Inputs = new Dictionary<string, object?> { { "text", "What is AAPL's outlook, considering both product launches and market conditions?" } },
          },
          Fields = ["category", "chunk_text"],
      }
  );

  Console.WriteLine(response);
  ```

  ```shell curl theme={null}
  PINECONE_API_KEY="YOUR_API_KEY"
  INDEX_HOST="INDEX_HOST"

  curl "https://$INDEX_HOST/records/namespaces/example-namespace/search" \
    -H "Content-Type: application/json" \
    -H "Api-Key: $PINECONE_API_KEY" \
    -H "X-Pinecone-API-Version: 2025-04" \
    -d '{
          "query": {
            "inputs": { "text": "What is AAPL'\''s outlook, considering both product launches and market conditions?" },
            "top_k": 3
          },
          "fields": ["chunk_text", "quarter"]
      }'
  ```
</CodeGroup>

The results will look as follows. The most similar records are scored highest.

<CodeGroup>
  ```python Python theme={null}
  {'result': {'hits': [{'_id': 'vec2',
                        '_score': 10.77734375,
                        'fields': {'chunk_text': "Analysts suggest that AAPL'''s "
                                                 'upcoming Q4 product launch '
                                                 'event might solidify its '
                                                 'position in the premium '
                                                 'smartphone market.',
                                   'quarter': 'Q4'}},
                       {'_id': 'vec3',
                        '_score': 6.49066162109375,
                        'fields': {'chunk_text': "AAPL'''s strategic Q3 "
                                                 'partnerships with '
                                                 'semiconductor suppliers could '
                                                 'mitigate component risks and '
                                                 'stabilize iPhone production.',
                                   'quarter': 'Q3'}},
                       {'_id': 'vec1',
                        '_score': 5.3671875,
                        'fields': {'chunk_text': 'AAPL reported a year-over-year '
                                                 'revenue increase, expecting '
                                                 'stronger Q3 demand for its '
                                                 'flagship phones.',
                                   'quarter': 'Q3'}}]},
   'usage': {'embed_total_tokens': 18, 'read_units': 1}}
  ```

  ```javascript JavaScript theme={null}
  {
    result: { 
      hits: [ 
        {
          _id: "vec2",
          _score: 10.82421875,
          fields: {
            chunk_text: "Analysts suggest that AAPL'''s upcoming Q4 product launch event might solidify its position in the premium smartphone market.",
            quarter: "Q4"
          }
        },
        {
          _id: "vec3",
          _score: 6.49066162109375,
          fields: {
            chunk_text: "AAPL'''s strategic Q3 partnerships with semiconductor suppliers could mitigate component risks and stabilize iPhone production.",
            quarter: "Q3"
          }
        },
        {
          _id: "vec1",
          _score: 5.3671875,
          fields: {
            chunk_text: "AAPL reported a year-over-year revenue increase, expecting stronger Q3 demand for its flagship phones.",
            quarter: "Q3"
          }
        }
      ]
    },
    usage: { 
      readUnits: 1, 
      embedTotalTokens: 18 
    }
  }
  ```

  ```java Java theme={null}
  class SearchRecordsResponse {
      result: class SearchRecordsResponseResult {
          hits: [class Hit {
              id: vec2
              score: 10.82421875
              fields: {chunk_text=Analysts suggest that AAPL's upcoming Q4 product launch event might solidify its position in the premium smartphone market., quarter=Q4}
              additionalProperties: null
          }, class Hit {
              id: vec3
              score: 6.49066162109375
              fields: {chunk_text=AAAPL'''s strategic Q3 partnerships with semiconductor suppliers could mitigate component risks and stabilize iPhone production., quarter=Q3}
              additionalProperties: null
          }, class Hit {
              id: vec1
              score: 5.3671875
              fields: {chunk_text=AAPL reported a year-over-year revenue increase, expecting stronger Q3 demand for its flagship phones., quarter=Q3}
              additionalProperties: null
          }]
          additionalProperties: null
      }
      usage: class SearchUsage {
          readUnits: 1
          embedTotalTokens: 18
      }
      additionalProperties: null
  }
  ```

  ```go Go theme={null}
  {
    "result": {
      "hits": [
        {
          "_id": "vec2",
          "_score": 10.833984,
          "fields": {
            "chunk_text": "Analysts suggest that AAPL's upcoming Q4 product launch event might solidify its position in the premium smartphone market.",
            "quarter": "Q4"
          }
        },
        {
          "_id": "vec3",
          "_score": 6.473572,
          "fields": {
            "chunk_text": "AAPL's strategic Q3 partnerships with semiconductor suppliers could mitigate component risks and stabilize iPhone production.",
            "quarter": "Q3"
          }
        },
        {
          "_id": "vec1",
          "_score": 5.3710938,
          "fields": {
            "chunk_text": "AAPL reported a year-over-year revenue increase, expecting stronger Q3 demand for its flagship phones.",
            "quarter": "Q3"
          }
        }
      ]
    },
    "usage": {
      "read_units": 6,
      "embed_total_tokens": 18
    }
  }
  ```

  ```csharp C# theme={null}
  {
      "result": {
          "hits": [
              {
                  "_id": "vec2",
                  "_score": 10.833984,
                  "fields": {
                      "chunk_text": "Analysts suggest that AAPL's upcoming Q4 product launch event might solidify its position in the premium smartphone market.",
                      "quarter": "Q4"
                  }
              },
              {
                  "_id": "vec3",
                  "_score": 6.473572,
                  "fields": {
                      "chunk_text": "AAPL's strategic Q3 partnerships with semiconductor suppliers could mitigate component risks and stabilize iPhone production.",
                      "quarter": "Q3"
                  }
              },
              {
                  "_id": "vec1",
                  "_score": 5.3710938,
                  "fields": {
                      "chunk_text": "AAPL reported a year-over-year revenue increase, expecting stronger Q3 demand for its flagship phones.",
                      "quarter": "Q3"
                  }
              }
          ]
      },
      "usage": {
          "read_units": 6,
          "embed_total_tokens": 18
      }
  }
  ```

  ```json curl theme={null}
  {
    "result": {
      "hits": [
        {
          "_id": "vec2",
          "_score": 10.82421875,
          "fields": {
            "chunk_text": "Analysts suggest that AAPL'''s upcoming Q4 product launch event might solidify its position in the premium smartphone market.",
            "quarter": "Q4"
          }
        },
        {
          "_id": "vec3",
          "_score": 6.49066162109375,
          "fields": {
            "chunk_text": "AAPL'''s strategic Q3 partnerships with semiconductor suppliers could mitigate component risks and stabilize iPhone production.",
            "quarter": "Q3"
          }
        },
        {
          "_id": "vec1",
          "_score": 5.3671875,
          "fields": {
            "chunk_text": "AAPL reported a year-over-year revenue increase, expecting stronger Q3 demand for its flagship phones.",
            "quarter": "Q3"
          }
        }
      ]
    },
    "usage": {
      "embed_total_tokens": 18,
      "read_units": 1
    }
  }
  ```
</CodeGroup>

## Search with a sparse vector

To search a sparse index with a sparse vector representation of a query, use the [`query`](/reference/api/latest/data-plane/query) operation with the following parameters:

* `namespace`: The [namespace](/guides/index-data/indexing-overview#namespaces) to query. To use the default namespace, set to `"__default__"`.
* `sparse_vector`: The sparse vector values and indices.
* `top_k`: The number of results to return.
* `include_values`: Whether to include the vector values of the matching records in the response. Defaults to `false`.
* `include_metadata`: Whether to include the metadata of the matching records in the response. Defaults to `false`.
  <Note>
    When querying with `top_k` over 1000, avoid returning vector data or metadata for optimal performance.
  </Note>

For example, the following code uses a sparse vector representation of the query "What is AAPL's outlook, considering both product launches and market conditions?" to search for the 3 most similar vectors in the `example-namespace` namespace:

<CodeGroup>
  ```python Python theme={null}
  from pinecone import Pinecone

  pc = Pinecone(api_key="YOUR_API_KEY")

  # To get the unique host for an index, 
  # see https://docs.pinecone.io/guides/manage-data/target-an-index
  index = pc.Index(host="INDEX_HOST")

  results = index.query(
      namespace="example-namespace",
      sparse_vector={
        "values": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
        "indices": [767227209, 1640781426, 1690623792, 2021799277, 2152645940, 2295025838, 2443437770, 2779594451, 2956155693, 3476647774, 3818127854, 4283091697]
      }, 
      top_k=3,
      include_metadata=True,
      include_values=False
  )

  print(results)
  ```

  ```javascript JavaScript theme={null}
  import { Pinecone } from '@pinecone-database/pinecone'

  const pc = new Pinecone({ apiKey: "YOUR_API_KEY" })

  // To get the unique host for an index, 
  // see https://docs.pinecone.io/guides/manage-data/target-an-index
  const index = pc.index("INDEX_NAME", "INDEX_HOST")

  const queryResponse = await index.namespace('example-namespace').query({
      sparseVector: {
          indices: [767227209, 1640781426, 1690623792, 2021799277, 2152645940, 2295025838, 2443437770, 2779594451, 2956155693, 3476647774, 3818127854, 4283091697],
          values: [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
      },
      topK: 3,
      includeValues: false,
      includeMetadata: true
  });

  console.log(queryResponse);
  ```

  ```java Java theme={null}
  import io.pinecone.clients.Pinecone;
  import io.pinecone.unsigned_indices_model.QueryResponseWithUnsignedIndices;
  import io.pinecone.clients.Index;

  import java.util.*;

  public class SearchSparseIndex {
      public static void main(String[] args) throws InterruptedException {
          // Instantiate Pinecone class
          Pinecone pinecone = new Pinecone.Builder("YOUR_API_KEY").build();

          String indexName = "docs-example";

          Index index = pinecone.getIndexConnection(indexName);

          List<Long> sparseIndices = Arrays.asList(
                  767227209L, 1640781426L, 1690623792L, 2021799277L, 2152645940L,
                  2295025838L, 2443437770L, 2779594451L, 2956155693L, 3476647774L,
                  3818127854L, 428309169L);
          List<Float> sparseValues = Arrays.asList(
                  1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f,
                  1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f);

          QueryResponseWithUnsignedIndices queryResponse = index.query(3, null, sparseIndices, sparseValues, null, "example-namespace", null, false, true);
          System.out.println(queryResponse);
      }
  }
  ```

  ```go Go theme={null}
  package main

  import (
  	"context"
  	"encoding/json"
  	"fmt"
  	"log"

  	"github.com/pinecone-io/go-pinecone/v4/pinecone"
  )

  func prettifyStruct(obj interface{}) string {
  	bytes, _ := json.MarshalIndent(obj, "", "  ")
  	return string(bytes)
  }

  func main() {
  	ctx := context.Background()

  	pc, err := pinecone.NewClient(pinecone.NewClientParams{
  		ApiKey: "YOUR_API_KEY",
  	})
  	if err != nil {
  		log.Fatalf("Failed to create Client: %v", err)
  	}

  	// To get the unique host for an index,
  	// see https://docs.pinecone.io/guides/manage-data/target-an-index
  	idxConnection, err := pc.Index(pinecone.NewIndexConnParams{Host: "INDEX_HOST", Namespace: "example-namespace"})
  	if err != nil {
  		log.Fatalf("Failed to create IndexConnection for Host: %v", err)
  	}

  	sparseValues := pinecone.SparseValues{
  		Indices: []uint32{767227209, 1640781426, 1690623792, 2021799277, 2152645940, 2295025838, 2443437770, 2779594451, 2956155693, 3476647774, 3818127854, 4283091697},
  		Values:  []float32{1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0},
  	}

  	res, err := idxConnection.QueryByVectorValues(ctx, &pinecone.QueryByVectorValuesRequest{
  		SparseValues:    &sparseValues,
  		TopK:            3,
  		IncludeValues:   false,
  		IncludeMetadata: true,
  	})
  	if err != nil {
  		log.Fatalf("Error encountered when querying by vector: %v", err)
  	} else {
  		fmt.Printf(prettifyStruct(res))
  	}
  }
  ```

  ```csharp C# theme={null}
  using Pinecone;

  var pinecone = new PineconeClient("YOUR_API_KEY");

  var index = pinecone.Index("docs-example");

  var queryResponse = await index.QueryAsync(new QueryRequest {
      Namespace = "example-namespace",
      TopK = 4,
      SparseVector = new SparseValues
      {
          Indices = [767227209, 1640781426, 1690623792, 2021799277, 2152645940, 2295025838, 2443437770, 2779594451, 2956155693, 3476647774, 3818127854, 4283091697],
          Values = new[] { 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f },
      },
      IncludeValues = false,
      IncludeMetadata = true
  });

  Console.WriteLine(queryResponse);
  ```

  ```shell curl theme={null}
  PINECONE_API_KEY="YOUR_API_KEY"
  INDEX_HOST="INDEX_HOST"

  curl "https://$INDEX_HOST/query" \
    -H "Content-Type: application/json" \
    -H "Api-Key: $PINECONE_API_KEY" \
    -H "X-Pinecone-API-Version: 2025-04" \
    -d '{
          "sparseVector": {
              "values": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
              "indices": [767227209, 1640781426, 1690623792, 2021799277, 2152645940, 2295025838, 2443437770, 2779594451, 2956155693, 3476647774, 3818127854, 4283091697]
          },
          "namespace": "example-namespace",
          "topK": 4,
          "includeMetadata": true,
          "includeValues": false
      }'
  ```
</CodeGroup>

The results will look as follows. The most similar records are scored highest.

<CodeGroup>
  ```python Python theme={null}
  {'matches': [{'id': 'vec2',
                'metadata': {'category': 'technology',
                             'quarter': 'Q4',
                             'chunk_text': "Analysts suggest that AAPL'''s "
                                            'upcoming Q4 product launch event '
                                            'might solidify its position in the '
                                            'premium smartphone market.'},
                'score': 10.9042969,
                'values': []},
               {'id': 'vec3',
                'metadata': {'category': 'technology',
                             'quarter': 'Q3',
                             'chunk_text': "AAPL'''s strategic Q3 partnerships "
                                            'with semiconductor suppliers could '
                                            'mitigate component risks and '
                                            'stabilize iPhone production'},
                'score': 6.48010254,
                'values': []},
               {'id': 'vec1',
                'metadata': {'category': 'technology',
                             'quarter': 'Q3',
                             'chunk_text': 'AAPL reported a year-over-year '
                                            'revenue increase, expecting '
                                            'stronger Q3 demand for its flagship '
                                            'phones.'},
                'score': 5.3671875,
                'values': []}],
   'namespace': 'example-namespace',
   'usage': {'read_units': 1}}
  ```

  ```javascript JavaScript theme={null}
  { 
    matches: [
              { 
                id: 'vec2',
                score: 10.9042969,
                values: [],
                metadata: {
                  chunk_text: "Analysts suggest that AAPL'''s upcoming Q4 product launch event might solidify its position in the premium smartphone market.",
                  category: 'technology',
                  quarter: 'Q4'
                }
              },
              {
                id: 'vec3',
                score: 6.48010254,
                values: [],
                metadata: {
                  chunk_text: "AAPL'''s strategic Q3 partnerships with semiconductor suppliers could mitigate component risks and stabilize iPhone production.",
                  category: 'technology',
                  quarter: 'Q3'
                }
              },
              {
                id: 'vec1',
                score: 5.3671875,
                values: [],
                metadata: {
                    chunk_text: 'AAPL reported a year-over-year revenue increase, expecting stronger Q3 demand for its flagship phones.',
                    category: 'technology',
                    quarter: 'Q3'
                }
              }
            ],
    namespace: 'example-namespace',
    usage: {readUnits: 1}
  }
  ```

  ```java Java theme={null}
  class QueryResponseWithUnsignedIndices {
      matches: [ScoredVectorWithUnsignedIndices {
          score: 10.34375
          id: vec2
          values: []
          metadata: fields {
            key: "category"
            value {
              string_value: "technology"
            }
          }
          fields {
            key: "chunk_text"
            value {
              string_value: "Analysts suggest that AAPL\'\\\'\'s upcoming Q4 product launch event might solidify its position in the premium smartphone market."
            }
          }
          fields {
            key: "quarter"
            value {
              string_value: "Q4"
            }
          }
          
          sparseValuesWithUnsignedIndices: SparseValuesWithUnsignedIndices {
              indicesWithUnsigned32Int: []
              values: []
          }
      }, ScoredVectorWithUnsignedIndices {
          score: 5.8638916
          id: vec3
          values: []
          metadata: fields {
            key: "category"
            value {
              string_value: "technology"
            }
          }
          fields {
            key: "chunk_text"
            value {
              string_value: "AAPL\'\\\'\'s strategic Q3 partnerships with semiconductor suppliers could mitigate component risks and stabilize iPhone production"
            }
          }
          fields {
            key: "quarter"
            value {
              string_value: "Q3"
            }
          }
          
          sparseValuesWithUnsignedIndices: SparseValuesWithUnsignedIndices {
              indicesWithUnsigned32Int: []
              values: []
          }
      }, ScoredVectorWithUnsignedIndices {
          score: 5.3671875
          id: vec1
          values: []
          metadata: fields {
            key: "category"
            value {
              string_value: "technology"
            }
          }
          fields {
            key: "chunk_text"
            value {
              string_value: "AAPL reported a year-over-year revenue increase, expecting stronger Q3 demand for its flagship phones."
            }
          }
          fields {
            key: "quarter"
            value {
              string_value: "Q3"
            }
          }
          
          sparseValuesWithUnsignedIndices: SparseValuesWithUnsignedIndices {
              indicesWithUnsigned32Int: []
              values: []
          }
      }]
      namespace: example-namespace
      usage: read_units: 1

  }
  ```

  ```go Go theme={null}
  {
    "matches": [
      {
        "vector": {
          "id": "vec2",
          "metadata": {
            "category": "technology",
            "quarter": "Q4",
            "chunk_text": "Analysts suggest that AAPL's upcoming Q4 product launch event might solidify its position in the premium smartphone market."
          }
        },
        "score": 10.904296
      },
      {
        "vector": {
          "id": "vec3",
          "metadata": {
            "category": "technology",
            "quarter": "Q3",
            "chunk_text": "AAPL's strategic Q3 partnerships with semiconductor suppliers could mitigate component risks and stabilize iPhone production"
          }
        },
        "score": 6.4801025
      },
      {
        "vector": {
          "id": "vec1",
          "metadata": {
            "category": "technology",
            "quarter": "Q3",
            "chunk_text": "AAPL reported a year-over-year revenue increase, expecting stronger Q3 demand for its flagship phones"
          }
        },
        "score": 5.3671875
      }
    ],
    "usage": {
      "read_units": 1
    },
    "namespace": "example-namespace"
  }
  ```

  ```csharp C# theme={null}
  {
    "results": [],
    "matches": [
      {
        "id": "vec2",
        "score": 10.904297,
        "values": [],
        "metadata": {
          "category": "technology",
          "chunk_text": "Analysts suggest that AAPL\u0027\u0027\u0027s upcoming Q4 product launch event might solidify its position in the premium smartphone market.",
          "quarter": "Q4"
        }
      },
      {
        "id": "vec3",
        "score": 6.4801025,
        "values": [],
        "metadata": {
          "category": "technology",
          "chunk_text": "AAPL\u0027\u0027\u0027s strategic Q3 partnerships with semiconductor suppliers could mitigate component risks and stabilize iPhone production",
          "quarter": "Q3"
        }
      },
      {
        "id": "vec1",
        "score": 5.3671875,
        "values": [],
        "metadata": {
          "category": "technology",
          "chunk_text": "AAPL reported a year-over-year revenue increase, expecting stronger Q3 demand for its flagship phones.",
          "quarter": "Q3"
        }
      }
    ],
    "namespace": "example-namespace",
    "usage": {
      "readUnits": 1
    }
  }
  ```

  ```json curl theme={null}
  {
    "results": [],
    "matches": [
      {
        "id": "vec2",
        "score": 10.9042969,
        "values": [],
        "metadata": {
          "chunk_text": "Analysts suggest that AAPL'''s upcoming Q4 product launch event might solidify its position in the premium smartphone market.",
          "category": "technology",
          "quarter": "Q4"
        }
      },
      {
        "id": "vec3",
        "score": 6.48010254,
        "values": [],
        "metadata": {
          "chunk_text": "AAPL'''s strategic Q3 partnerships with semiconductor suppliers could mitigate component risks and stabilize iPhone production.",
          "category": "technology",
          "quarter": "Q3"
        }
      },
      {
        "id": "vec1",
        "score": 5.3671875,
        "values": [],
        "metadata": {
            "chunk_text": "AAPL reported a year-over-year revenue increase, expecting stronger Q3 demand for its flagship phones.",
            "category": "technology",
            "quarter": "Q3"
        }
      }
    ],
    "namespace": "example-namespace",
    "usage": {
      "readUnits": 1
    }
  }
  ```
</CodeGroup>

## Search with a record ID

When you search with a record ID, Pinecone uses the sparse vector associated with the record as the query. To search a sparse index with a record ID, use the [`query`](/reference/api/latest/data-plane/query) operation with the following parameters:

* `namespace`: The [namespace](/guides/index-data/indexing-overview#namespaces) to query. To use the default namespace, set to `"__default__"`.
* `id`: The unique record ID containing the sparse vector to use as the query.
* `top_k`: The number of results to return.
* `include_values`: Whether to include the vector values of the matching records in the response. Defaults to `false`.
* `include_metadata`: Whether to include the metadata of the matching records in the response. Defaults to `false`.
  <Note>
    When querying with `top_k` over 1000, avoid returning vector data or metadata for optimal performance.
  </Note>

For example, the following code uses an ID to search for the 3 records in the `example-namespace` namespace that best match the sparse vector in the record:

<CodeGroup>
  ```Python Python theme={null}
  from pinecone.grpc import PineconeGRPC as Pinecone

  pc = Pinecone(api_key="YOUR_API_KEY")

  # To get the unique host for an index, 
  # see https://docs.pinecone.io/guides/manage-data/target-an-index
  index = pc.Index(host="INDEX_HOST")

  index.query(
      namespace="example-namespace",
      id="rec2", 
      top_k=3,
      include_metadata=True,
      include_values=False
  )
  ```

  ```JavaScript JavaScript theme={null}
  import { Pinecone } from '@pinecone-database/pinecone'

  const pc = new Pinecone({ apiKey: "YOUR_API_KEY" })

  // To get the unique host for an index, 
  // see https://docs.pinecone.io/guides/manage-data/target-an-index
  const index = pc.index("INDEX_NAME", "INDEX_HOST")

  const queryResponse = await index.namespace('example-namespace').query({
      id: 'rec2',
      topK: 3,
      includeValues: false,
      includeMetadata: true,
  });
  ```

  ```java Java theme={null}
  import io.pinecone.clients.Index;
  import io.pinecone.configs.PineconeConfig;
  import io.pinecone.configs.PineconeConnection;
  import io.pinecone.unsigned_indices_model.QueryResponseWithUnsignedIndices;

  public class QueryExample {
      public static void main(String[] args) {
          PineconeConfig config = new PineconeConfig("YOUR_API_KEY");
          // To get the unique host for an index, 
          // see https://docs.pinecone.io/guides/manage-data/target-an-index
          config.setHost("INDEX_HOST");
          PineconeConnection connection = new PineconeConnection(config);
          Index index = new Index(connection, "INDEX_NAME");
          QueryResponseWithUnsignedIndices queryRespone = index.queryByVectorId(3, "rec2", "example-namespace", null, false, true);
          System.out.println(queryResponse);
      }
  }
  ```

  ```go Go theme={null}
  package main

  import (
      "context"
      "encoding/json"
      "fmt"
      "log"

      "github.com/pinecone-io/go-pinecone/v4/pinecone"
  )

  func prettifyStruct(obj interface{}) string {
  	bytes, _ := json.MarshalIndent(obj, "", "  ")
  	return string(bytes)
  }

  func main() {
      ctx := context.Background()

      pc, err := pinecone.NewClient(pinecone.NewClientParams{
          ApiKey: "YOUR_API_KEY",
      })
      if err != nil {
          log.Fatalf("Failed to create Client: %v", err)
      }

      // To get the unique host for an index, 
      // see https://docs.pinecone.io/guides/manage-data/target-an-index
      idxConnection, err := pc.Index(pinecone.NewIndexConnParams{Host: "INDEX_HOST", Namespace: "example-namespace"})
      if err != nil {
          log.Fatalf("Failed to create IndexConnection for Host: %v", err)
    	}

      vectorId := "rec2"
      res, err := idxConnection.QueryByVectorId(ctx, &pinecone.QueryByVectorIdRequest{
          VectorId:      vectorId,
          TopK:          3,
          IncludeValues: false,
          IncludeMetadata: true,
      })
      if err != nil {
          log.Fatalf("Error encountered when querying by vector ID `%v`: %v", vectorId, err)
      } else {
          fmt.Printf(prettifyStruct(res.Matches))
      }
  }
  ```

  ```csharp C# theme={null}
  using Pinecone;

  var pinecone = new PineconeClient("YOUR_API_KEY");

  // To get the unique host for an index, 
  // see https://docs.pinecone.io/guides/manage-data/target-an-index
  var index = pinecone.Index(host: "INDEX_HOST");

  var queryResponse = await index.QueryAsync(new QueryRequest {
      Id = "rec2",
      Namespace = "example-namespace",
      TopK = 3,
      IncludeValues = false,
      IncludeMetadata = true
  });

  Console.WriteLine(queryResponse);
  ```

  ```bash curl theme={null}
  # To get the unique host for an index,
  # see https://docs.pinecone.io/guides/manage-data/target-an-index
  PINECONE_API_KEY="YOUR_API_KEY"
  INDEX_HOST="INDEX_HOST"

  curl "https://$INDEX_HOST/query" \
    -H "Api-Key: $PINECONE_API_KEY" \
    -H 'Content-Type: application/json' \
    -H "X-Pinecone-API-Version: 2025-04" \
    -d '{
          "id": "rec2",
          "namespace": "example-namespace",
          "topK": 3,
          "includeMetadata": true,
          "includeValues": false
      }'
  ```
</CodeGroup>

## Filter by required terms

<Note>
  This feature is in [public preview](/release-notes/feature-availability) and is available only on the `2025-10` version of the API. See [limitations](#limitations) for details.
</Note>

When [searching with text](#search-with-text), you can specify a list of terms that must be present in each lexical search result. This is especially useful for:

* **Precision filtering**: Ensuring specific entities or concepts appear in results
* **Quality control**: Filtering out results that don't contain essential keywords
* **Domain-specific searches**: Requiring domain-specific terminology in results
* **Entity-based filtering**: Ensuring specific people, places, or things are mentioned

To filter by required terms, add `match_terms` to your query, specifying the `terms` to require and the `strategy` to use. Currently, `all` is the only strategy supported (all terms must be present).

For example, the following request searches for records about Tesla's stock performance while ensuring both "Tesla" and "stock" appear in each result:

```bash curl theme={null}
PINECONE_API_KEY="YOUR_API_KEY"
INDEX_HOST="INDEX_HOST"

curl "https://$INDEX_HOST/records/namespaces/example-namespace/search" \
  -H "Content-Type: application/json" \
  -H "Api-Key: $PINECONE_API_KEY" \
  -H "X-Pinecone-API-Version: unstable" \
  -d '{
        "query": {
          "inputs": { "text": "What is the current outlook for Tesla stock performance?" },
          "top_k": 3,
          "match_terms": {
            "terms": ["Tesla", "stock"],
            "strategy": "all"
          }
        },
        "fields": ["chunk_text"]
    }'
```

The response includes only records that contain both "Tesla" and "stock":

```json  theme={null}
{
  "result": {
    "hits": [
      {
        "_id": "tesla_q4_earnings",
        "_score": 9.82421875,
        "fields": {
          "chunk_text": "Tesla stock surged 8% in after-hours trading following strong Q4 earnings that exceeded analyst expectations. The company reported record vehicle deliveries and improved profit margins."
        }
      },
      {
        "_id": "tesla_competition_analysis",
        "_score": 7.49066162109375,
        "fields": {
          "chunk_text": "Tesla stock faces increasing competition from traditional automakers entering the electric vehicle market. However, analysts maintain that Tesla's technological lead and brand recognition provide significant advantages."
        }
      },
      {
        "_id": "tesla_production_update",
        "_score": 6.3671875,
        "fields": {
          "chunk_text": "Tesla stock performance is closely tied to production capacity at its Gigafactories. Recent expansion announcements suggest the company is positioning for continued growth in global markets."
        }
      }
    ]
  },
  "usage": {
    "embed_total_tokens": 18,
    "read_units": 1
  }
}
```

Without the `match_terms` filter, you might get results like:

* "Tesla cars are popular in California" (mentions Tesla but not stock)
* "Stock market volatility affects tech companies" (mentions stock but not Tesla)
* "Electric vehicle sales are growing" (neither Tesla nor stock)

### Limitations

* **Integrated indexes only**: Filtering by required terms is supported only for [indexes with integrated embedding](/guides/index-data/indexing-overview#integrated-embedding).
* **Post-processing filter**: The filtering happens after the initial query, so potential matches that weren't included in the initial `top_k` results won't appear in the final results
* **No phrase matching**: Terms are matched individually in any order and location.
* **No case-sensitivity**: Terms are normalized during processing.
