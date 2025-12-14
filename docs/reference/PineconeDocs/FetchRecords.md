# Fetch records

> Retrieve complete records by ID or metadata filter.

<Tip>
  You can fetch data using the [Pinecone console](https://app.pinecone.io/organizations/-/projects/-/indexes/-/browser).
</Tip>

## Fetch records by ID

To fetch records from a namespace based on their IDs, use the `fetch` operation with the following parameters:

* `namespace`: The [namespace](/guides/index-data/indexing-overview#namespaces) containing the records to fetch. To use the default namespace, set this to `"__default__"`.
* `ids`: The IDs of the records to fetch. Maximum of 1000.

<CodeGroup>
  ```Python Python theme={null}
  from pinecone.grpc import PineconeGRPC as Pinecone

  pc = Pinecone(api_key="YOUR_API_KEY")

  # To get the unique host for an index, 
  # see https://docs.pinecone.io/guides/manage-data/target-an-index
  index = pc.Index(host="INDEX_HOST")

  index.fetch(ids=["id-1", "id-2"], namespace="example-namespace")
  ```

  ```JavaScript JavaScript theme={null}
  import { Pinecone } from '@pinecone-database/pinecone'

  const pc = new Pinecone({ apiKey: "YOUR_API_KEY" })

  // To get the unique host for an index, 
  // see https://docs.pinecone.io/guides/manage-data/target-an-index
  const index = pc.index("INDEX_NAME", "INDEX_HOST")

  const fetchResult = await index.namespace('example-namespace').fetch(['id-1', 'id-2']);
  ```

  ```java Java theme={null}
  import io.pinecone.clients.Index;
  import io.pinecone.configs.PineconeConfig;
  import io.pinecone.configs.PineconeConnection;
  import io.pinecone.proto.FetchResponse;

  import java.util.Arrays;
  import java.util.List;

  public class FetchExample {
      public static void main(String[] args) {
          PineconeConfig config = new PineconeConfig("YOUR_API_KEY");
          // To get the unique host for an index, 
          // see https://docs.pinecone.io/guides/manage-data/target-an-index
          config.setHost("INDEX_HOST");
          PineconeConnection connection = new PineconeConnection(config);
          Index index = new Index(connection, "INDEX_NAME");

          List<String> ids = Arrays.asList("id-1", "id-2");
          FetchResponse fetchResponse = index.fetch(ids, "example-namespace");
          System.out.println(fetchResponse);
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

      res, err := idxConnection.FetchVectors(ctx, []string{"id-1", "id-2"})
      if err != nil {
          log.Fatalf("Failed to fetch vectors: %v", err)
      } else {
          fmt.Printf(prettifyStruct(res))
      }
  }
  ```

  ```csharp C# theme={null}
  using Pinecone;

  var pinecone = new PineconeClient("YOUR_API_KEY");

  // To get the unique host for an index, 
  // see https://docs.pinecone.io/guides/manage-data/target-an-index
  var index = pinecone.Index(host: "INDEX_HOST");

  var fetchResponse = await index.FetchAsync(new FetchRequest {
      Ids = new List<string> { "id-1", "id-2" },
      Namespace = "example-namespace"
  });
  ```

  ```bash curl theme={null}
  # To get the unique host for an index,
  # see https://docs.pinecone.io/guides/manage-data/target-an-index
  PINECONE_API_KEY="YOUR_API_KEY"
  INDEX_HOST="INDEX_HOST"

  curl -X GET "https://$INDEX_HOST/vectors/fetch?ids=id-1&ids=id-2&namespace=example-namespace" \
    -H "Api-Key: $PINECONE_API_KEY" \
    -H "X-Pinecone-API-Version: 2025-04"
  ```
</CodeGroup>

The response looks like this:

<CodeGroup>
  ```Python Python theme={null}
  {'namespace': 'example-namespace',
   'usage': {'readUnits': 1},
   'vectors': {'id-1': {'id': 'id-1',
                        'values': [0.568879, 0.632687092, 0.856837332, ...]},
               'id-2': {'id': 'id-2',
                        'values': [0.00891787093, 0.581895, 0.315718859, ...]}}}
  ```

  ```JavaScript JavaScript theme={null}
  {'namespace': 'example-namespace',
   'usage': {'readUnits': 1},
   'records': {'id-1': {'id': 'id-1',
                        'values': [0.568879, 0.632687092, 0.856837332, ...]},
               'id-2': {'id': 'id-2',
                        'values': [0.00891787093, 0.581895, 0.315718859, ...]}}}
  ```

  ```java Java theme={null}
  namespace: "example-namespace"
  vectors {
    key: "id-1"
    value {
      id: "id-1"
      values: 0.568879
      values: 0.632687092
      values: 0.856837332
      ...
    }
  }
  vectors {
    key: "id-2"
    value {
      id: "id-2"
      values: 0.00891787093
      values: 0.581895
      values: 0.315718859
      ...
    }
  }
  usage {
    read_units: 1
  }
  ```

  ```go Go theme={null}
  {
    "vectors": {
      "id-1": {
        "id": "id-1",
        "values": [
          -0.0089730695,
          -0.020010853,
          -0.0042787646,
          ...
        ]
      },
      "id-2": {
        "id": "id-2",
        "values": [
          -0.005380766,
          0.00215196,
          -0.014833462,
          ...
        ]
      }
    },
    "usage": {
      "read_units": 1
    }
  }
  ```

  ```csharp C# theme={null}
  {
    "vectors": {
      "id-1": {
        "id": "id-1",
        "values": [
          -0.0089730695,
          -0.020010853,
          -0.0042787646,
          ...
        ],
        "sparseValues": null,
        "metadata": null
      },
      "vec1": {
        "id": "id-2",
        "values": [
          -0.005380766,
          0.00215196,
          -0.014833462,
          ...
        ],
        "sparseValues": null,
        "metadata": null
      }
    },
    "namespace": "example-namespace",
    "usage": {
      "readUnits": 1
    }
  ```

  ```json curl theme={null}
  {
    "vectors": {
      "id-1": {
        "id": "id-1",
        "values": [0.568879, 0.632687092, 0.856837332, ...]
      },
      "id-2": {
        "id": "id-2",
        "values": [0.00891787093, 0.581895, 0.315718859, ...]
      }
    },
    "namespace": "example-namespace",
    "usage": {"readUnits": 1},
  }
  ```
</CodeGroup>

## Fetch records by metadata

<Warning>
  This feature is in [early access](/release-notes/feature-availability) and is available only on the `2025-10` version of the API.
</Warning>

To fetch records from a namespace based on their metadata values, use the `fetch_by_metadata` operation with the following parameters:

* `namespace`: The [namespace](/guides/index-data/indexing-overview#namespaces) containing the records to fetch. To use the default namespace, set this to `"__default__"`.
* `filter`: A [metadata filter expression](/guides/index-data/indexing-overview#metadata-filter-expressions) to match the records to fetch.
* `limit`: The number of matching records to return. Defaults to 100. Maximum of 10,000.

For example, the following code fetches 200 records with a `genre` field set to `documentary` from namespace `example-namespace`:

```shell curl theme={null}
# To get the unique host for an index,
# see https://docs.pinecone.io/guides/manage-data/target-an-index
PINECONE_API_KEY="YOUR_API_KEY"
INDEX_HOST="INDEX_HOST"

curl -X POST "https://$INDEX_HOST/vectors/fetch_by_metadata" \
  -H 'Api-Key: $PINECONE_API_KEY' \
  -H 'Content-Type: application/json' \
  -H "X-Pinecone-API-Version: 2025-10" \
  -d '{
    "namespace": "example-namespace",
    "filter": {"rating": {"$lt": 5}},
    "limit": 2
  }'
```

The response looks like this:

```json curl theme={null}
{
  "vectors": {
    "id-1": {
      "id": "id-1",
      "values": [
        -0.0273742676,
        -0.000517368317,
        ...
      ],
      "metadata": {
        "main_category": "Books",
        "rating": 4,
        "review": "Identical twins have only one purpose in movies and plays: to cause mass confusion...",
        "title": "A comedy of twin-switching"
      }
    },
    "id-2": {
      "id": "id-2",
      "values": [
        -0.00305938721,
        0.0234375,
        ...
      ],
      "metadata": {
        "main_category": "Automotive",
        "rating": 1,
        "review": "If I could rate this 1/2 a star I would! These both broke within 10 minutes  of using it. The only upside is the cloth is removable so it can be used with good old fashioned  elbow grease. Epic waste!",
        "title": "Dont waste your money!"
      }
    }
  },
  "namespace": "example-namespace",
  "usage": {
    "readUnits": 1
  }
}
```

## Fetch limits

**Fetch by ID limits:**

| Metric              | Limit                             |
| :------------------ | :-------------------------------- |
| Max IDs per request | 1000 IDs                          |
| Max request size    | N/A                               |
| Max request rate    | 100 requests per second per index |

**Fetch by metadata limits:**

| Metric                   | Limit                                |
| :----------------------- | :----------------------------------- |
| Max records per response | 10,000 records                       |
| Max response size        | 4MB                                  |
| Max response rate        | 10 requests per second per namespace |

## Data freshness

Pinecone is eventually consistent, so there can be a slight delay before new or changed records are visible to queries. You can view index stats to [check data freshness](/guides/index-data/check-data-freshness).
