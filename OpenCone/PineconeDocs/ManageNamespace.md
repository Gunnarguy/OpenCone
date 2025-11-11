# Manage namespaces

> Create and manage namespaces in serverless indexes.

## Create a namespace

<Warning>
  This feature is in [early access](/release-notes/feature-availability) and available only on the `2025-10` version of the API.
</Warning>

Namespaces are created automatically during [upsert](/guides/index-data/upsert-data). However, you can also create namespaces ahead of time using the [`create_namespace`](/reference/api/2025-10/data-plane/createnamespace) operation. Specify a name for the namespace and, optionally, the [metadata fields to index](/guides/index-data/create-an-index#metadata-indexing).

```shell curl theme={null}
# To get the unique host for an index,
# see https://docs.pinecone.io/guides/manage-data/target-an-index
PINECONE_API_KEY="YOUR_API_KEY"
INDEX_HOST="INDEX_HOST"

curl "https://$INDEX_HOST/namespaces" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -H "Api-Key: $PINECONE_API_KEY" \
  -H "X-Pinecone-API-Version: 2025-10" \
  -d '{
        "name": "example-namespace",
        "schema": {
		  "fields": { 
            "document_id": {"filterable": true},
            "document_title": {"filterable": true},
            "chunk_number": {"filterable": true},
            "document_url": {"filterable": true},
            "created_at": {"filterable": true}
          }
        }
      }'
```

The response will look like the following:

```json curl theme={null}
{
    "name": "example-namespace",
    "record_count": "0",
    "schema": {
        "fields": {
            "document_title": {
                "filterable": true
            },
            "document_url": {
                "filterable": true
            },
            "chunk_number": {
                "filterable": true
            },
            "document_id": {
                "filterable": true
            },
            "created_at": {
                "filterable": true
            }
        }
    }
}
```

## List all namespaces in an index

Use the [`list_namespaces`](/reference/api/latest/data-plane/listnamespaces) operation to list all namespaces in a serverless index.

Up to 100 namespaces are returned at a time by default, in sorted order (bitwise “C” collation). If the `limit` parameter is set, up to that number of namespaces are returned instead. Whenever there are additional namespaces to return, the response also includes a `pagination_token` that you can use to get the next batch of namespaces. When the response does not include a `pagination_token`, there are no more namespaces to return.

<CodeGroup>
  ```python Python theme={null}
  # Not supported with pinecone["grpc"] extras installed
  from pinecone import Pinecone

  pc = Pinecone(api_key="YOUR_API_KEY")

  index = pc.Index(host="INDEX_HOST")

  # Implicit pagination using a generator function
  for namespace in index.list_namespaces():
      print(namespace.name, ":", namespace.record_count)

  # Manual pagination
  namespaces = index.list_namespaces_paginated(
      limit=2,
      pagination_token="eyJza2lwX3Bhc3QiOiIxMDEwMy0="
  )

  print(namespaces)
  ```

  ```javascript JavaScript theme={null}
  import { Pinecone } from '@pinecone-database/pinecone';

  const pc = new Pinecone({ apiKey: 'YOUR_API_KEY' })

  // To get the unique host for an index, 
  // see https://docs.pinecone.io/guides/manage-data/target-an-index
  var index = pinecone.Index(host: "INDEX_HOST");

  const namespaceList = await index.listNamespaces();

  console.log(namespaceList);
  ```

  ```java Java theme={null}
  import io.pinecone.clients.AsyncIndex;
  import io.pinecone.clients.Index;
  import io.pinecone.configs.PineconeConfig;
  import io.pinecone.configs.PineconeConnection;
  import io.pinecone.proto.ListNamespacesResponse;
  import org.openapitools.db_data.client.ApiException;

  public class Namespaces {
      public static void main(String[] args) throws ApiException {
          PineconeConfig config = new PineconeConfig("YOUR_API_KEY");
          // To get the unique host for an index, 
          // see https://docs.pinecone.io/guides/manage-data/target-an-index
          config.setHost("INDEX_HOST");
          PineconeConnection connection = new PineconeConnection(config);

          Index index = new Index(config, connection, "docs-example");

          // List all namespaces with default pagination limit (100)
          ListNamespacesResponse listNamespacesResponse = index.listNamespaces(null, null);

          // List all namespaces with pagination limit of 2
          ListNamespacesResponse listNamespacesResponseWithLimit = index.listNamespaces(2);

          // List all namespaces with pagination limit and token
          ListNamespacesResponse listNamespacesResponsePaginated = index.listNamespaces(5, "eyJza2lwX3Bhc3QiOiIxMDEwMy0=");

          System.out.println(listNamespacesResponseWithLimit);
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
      idxConnection, err := pc.Index(pinecone.NewIndexConnParams{Host: "INDEX_HOST"})
      if err != nil {
          log.Fatalf("Failed to create IndexConnection for Host: %v", err)
      } 

      limit := uint32(10)
      namespaces, err := idxConnection.ListNamespaces(ctx, &pinecone.ListNamespacesParams{
          Limit: &limit,
      })
      if err != nil {
          log.Fatalf("Failed to list namespaces: %v", err)
      }
      fmt.Printf(prettifyStruct(namespaces))
  }
  ```

  ```csharp C# theme={null}
  using Pinecone;

  var pinecone = new PineconeClient("PINECONE_API_KEY");

  // To get the unique host for an index, 
  // see https://docs.pinecone.io/guides/manage-data/target-an-index
  var index = pinecone.Index(host: "INDEX_HOST");

  var namespaces = await index.ListNamespacesAsync(new ListNamespacesRequest());

  Console.WriteLine(namespaces);
  ```

  ```shell curl theme={null}
  PINECONE_API_KEY="YOUR_API_KEY"
  INDEX_HOST="INDEX_HOST"

  curl -X GET "https://$INDEX_HOST/namespaces" \
      -H "Api-Key: $PINECONE_API_KEY" \
      -H "X-Pinecone-API-Version: 2025-04"
  ```
</CodeGroup>

The response will look like the following:

<CodeGroup>
  ```python Python theme={null}
  # Implicit pagination
  example-namespace : 20000
  example-namespace2 : 10500
  example-namespace3 : 10000
  ...

  # Manual pagination
  {
      "namespaces": [
          {
              "name": "example-namespace",
              "record_count": "20000"
          },
          {
              "name": "example-namespace2",
              "record_count": "10500"
          }
      ],
      "pagination": {
          "next": "Tm90aGluZyB0byBzZWUgaGVyZQo="
      }
  }
  ```

  ```javascript JavaScript theme={null}
  {
    namespaces: [
      { name: 'example-namespace', recordCount: '20000' },
      { name: 'example-namespace2', recordCount: '10500' },
      ...
    ],
    pagination: "Tm90aGluZyB0byBzZWUgaGVyZQo="
  }
  ```

  ```java Java theme={null}
  namespaces {
    name: "example-namespace"
    record_count: 20000
  }
  namespaces {
    name: "example-namespace2"
    record_count: 10500
  }
  pagination {
    next: "eyJza2lwX3Bhc3QiOiJlZDVhYzFiNi1kMDFiLTQ2NTgtYWVhZS1hYjJkMGI2YzBiZjQiLCJwcmVmaXgiOm51bGx9"
  }
  ```

  ```go Go theme={null}
  {
    "Namespaces": [
      {
        "name": "example-namespace",
        "record_count": 20000
      },
      {
        "name": "example-namespace2",
        "record_count": 10500
      },
      ...
    ],
    "Pagination": {
      "next": "eyJza2lwX3Bhc3QiOiIyNzQ5YTU1YS0zZTQ2LTQ4MDItOGFlNi1hZTJjZGNkMTE5N2IiLCJwcmVmaXgiOm51bGx9"
    }
  }
  ```

  ```csharp C# theme={null}
  {
    "namespaces":[
      {"name":"example-namespace","recordCount":20000},
      {"name":"example-namespace2","recordCount":10500},
      ...
    ],
    "pagination":"Tm90aGluZyB0byBzZWUgaGVyZQo="
  }
  ```

  ```json curl theme={null}
  {
    "namespaces": [
      {
        "name": "example-namespace",
        "record_count": 20000
      },
      {
        "name": "example-namespace2",
        "record_count": 10500
      },
      ...
    ],
    "pagination": {
      "next": "Tm90aGluZyB0byBzZWUgaGVyZQo="
    }
  }
  ```
</CodeGroup>

## Describe a namespace

Use the [`describe_namespace`](/reference/api/latest/data-plane/describenamespace) operation to get details about a namespace in a serverless index, including the total number of vectors in the namespace.

<CodeGroup>
  ```python Python theme={null}
  # Not supported with pinecone["grpc"] extras installed
  from pinecone import Pinecone

  pc = Pinecone(api_key="YOUR_API_KEY")

  index = pc.Index(host="INDEX_HOST")

  namespace = index.describe_namespace(namespace="example-namespace")

  print(namespace)
  ```

  ```javascript JavaScript theme={null}
  import { Pinecone } from '@pinecone-database/pinecone';

  const pc = new Pinecone({ apiKey: 'YOUR_API_KEY' })

  const index = pc.index('docs-example');

  const namespace = await index.describeNamespace('example-namespace');

  console.log(namespace);
  ```

  ```java Java theme={null}
  import io.pinecone.clients.Index;
  import io.pinecone.configs.PineconeConfig;
  import io.pinecone.configs.PineconeConnection;
  import io.pinecone.proto.NamespaceDescription;

  import org.openapitools.db_data.client.ApiException;

  public class Namespaces {
      public static void main(String[] args) throws ApiException {
          PineconeConfig config = new PineconeConfig("YOUR_API_KEY");
          // To get the unique host for an index, 
          // see https://docs.pinecone.io/guides/manage-data/target-an-index
          config.setHost("INDEX_HOST");
          PineconeConnection connection = new PineconeConnection(config);

          Index index = new Index(config, connection, "docs-example");

          NamespaceDescription namespaceDescription = index.describeNamespace("example-namespace");

          System.out.println(namespaceDescription);
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
      idxConnection, err := pc.Index(pinecone.NewIndexConnParams{Host: "INDEX_HOST"})
      if err != nil {
          log.Fatalf("Failed to create IndexConnection for Host: %v", err)
      } 

      namespace, err := idxConnection.DescribeNamespace(ctx, "example-namespace")
      if err != nil {
          log.Fatalf("Failed to describe namespace: %v", err)
      }
      fmt.Printf(prettifyStruct(namespace))
  }
  ```

  ```csharp C# theme={null}
  using Pinecone;

  var pinecone = new PineconeClient("PINECONE_API_KEY");

  // To get the unique host for an index, 
  // see https://docs.pinecone.io/guides/manage-data/target-an-index
  var index = pinecone.Index(host: "INDEX_HOST");

  var @namespace = await index.DescribeNamespaceAsync("example-namespace");

  Console.WriteLine(@namespace);
  ```

  ```shell curl theme={null}
  PINECONE_API_KEY="YOUR_API_KEY"
  INDEX_HOST="INDEX_HOST"
  NAMESPACE="NAMESPACE_NAME"  # To target the default namespace, use "__default__".

  curl -X GET "https://$INDEX_HOST/namespaces/$NAMESPACE" \
      -H "Api-Key: $PINECONE_API_KEY" \
      -H "X-Pinecone-API-Version: 2025-04"
  ```
</CodeGroup>

The response will look like the following:

<CodeGroup>
  ```python Python theme={null}
  {
      "name": "example-namespace",
      "record_count": "20000"
  }
  ```

  ```javascript JavaScript theme={null}
  { name: 'example-namespace', recordCount: '20000' }
  ```

  ```java Java theme={null}
  name: "example-namespace"
  record_count: 20000
  ```

  ```go Go theme={null}
  {
    "name": "example-namespace",
    "record_count": 20000
  }
  ```

  ```csharp C# theme={null}
  {"name":"example-namespace","recordCount":20000}
  ```

  ```json curl theme={null}
  {
    "name": "example-namespace",
    "record_count": 20000
  }
  ```
</CodeGroup>

## Delete a namespace

Use the [`delete_namespace`](/reference/api/latest/data-plane/deletenamespace) operation to delete a namespace in a serverless index.

<Warning>
  Deleting a namespace is irreversible. All data in the namespace is permanently deleted.
</Warning>

<CodeGroup>
  ```python Python theme={null}
  # Not supported with pinecone["grpc"] extras installed
  from pinecone import Pinecone

  pc = Pinecone(api_key="YOUR_API_KEY")

  index = pc.Index(host="INDEX_HOST")

  index.delete_namespace(namespace="example-namespace")
  ```

  ```javascript JavaScript theme={null}
  import { Pinecone } from '@pinecone-database/pinecone';

  const pc = new Pinecone({ apiKey: 'YOUR_API_KEY' })

  const index = pc.index('INDEX_NAME', 'INDEX_HOST');

  const namespace = await index.deleteNamespace('example-namespace');

  console.log(namespace);
  ```

  ```java Java theme={null}
  import io.pinecone.clients.Index;
  import io.pinecone.configs.PineconeConfig;
  import io.pinecone.configs.PineconeConnection;

  import java.util.concurrent.ExecutionException;

  public class DeleteNamespace {
      public static void main(String[] args) throws ExecutionException, InterruptedException {
          PineconeConfig config = new PineconeConfig("YOUR_API_KEY");
        // To get the unique host for an index, 
        // see https://docs.pinecone.io/guides/manage-data/target-an-index
          config.setHost("INDEX_HOST");
          PineconeConnection connection = new PineconeConnection(config);

          Index index = new Index(config, connection, "docs-example");

          index.deleteNamespace("example-namespace");
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
      idxConnection, err := pc.Index(pinecone.NewIndexConnParams{Host: "INDEX_HOST"})
      if err != nil {
          log.Fatalf("Failed to create IndexConnection for Host: %v", err)
      } 

      err := idxConnection.DeleteNamespace(ctx, "example-namespace")
      if err != nil {
          log.Fatalf("Failed to delete namespace: %v", err)
      }
  }
  ```

  ```csharp C# theme={null}
  using Pinecone;

  const pinecone = new PineconeClient("PINECONE_API_KEY");

  // To get the unique host for an index, 
  // see https://docs.pinecone.io/guides/manage-data/target-an-index
  const index = pinecone.Index(host: "INDEX_HOST");

  await index.DeleteNamespaceAsync("example-namespace");
  ```

  ```shell curl theme={null}
  PINECONE_API_KEY="YOUR_API_KEY"
  INDEX_HOST="INDEX_HOST"
  NAMESPACE="NAMESPACE_NAME" # To target the default namespace, use "__default__".

  curl -X DELETE "https://$INDEX_HOST/namespaces/$NAMESPACE" \
      -H "Api-Key: $PINECONE_API_KEY" \
      -H "X-Pinecone-API-Version: 2025-04"
  ```
</CodeGroup>

## Rename a namespace

Pinecone does not support renaming namespaces directly. Instead, you must [delete the records](/guides/manage-data/delete-data) in the namespace and [upsert the records](/guides/index-data/upsert-data) to a new namespace.

## Move records to a new namespace

Pinecone does not support moving records between namespaces directly. Instead, you must [delete the records](/guides/manage-data/delete-data) in the old namespace and [upsert the records](/guides/index-data/upsert-data) to the new namespace.

## Use the default namespace

To use the default namespace for upserts, queries, or other data operations, set the `namespace` parameter to `__default__`, for example:

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
          "inputs": {"text": "Disease prevention"}, 
          "top_k": 2
      },
      fields=["category", "chunk_text"]
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
      topK: 2,
      inputs: { text: 'Disease prevention' },
    },
    fields: ['chunk_text', 'category'],
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

          Index index = new Index(config, connection, "integrated-dense-java");

          String query = "Disease prevention";
          List<String> fields = new ArrayList<>();
          fields.add("category");
          fields.add("chunk_text");

          // Search the dense index
          SearchRecordsResponse recordsResponse = index.searchRecordsByText(query,  "example-namespace", fields, 2, null, null);

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
              TopK: 2,
              Inputs: &map[string]interface{}{
                  "text": "Disease prevention",
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
              TopK = 4,
              Inputs = new Dictionary<string, object?> { { "text", "Disease prevention" } },
          },
          Fields = ["category", "chunk_text"],
      }
  );

  Console.WriteLine(response);
  ```

  ```shell curl theme={null}
  INDEX_HOST="INDEX_HOST"
  NAMESPACE="NAMESPACE_NAME"
  PINECONE_API_KEY="YOUR_API_KEY"

  curl "https://$INDEX_HOST/records/namespaces/$NAMESPACE/search" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "Api-Key: $PINECONE_API_KEY" \
    -H "X-Pinecone-API-Version: unstable" \
    -d '{
          "query": {
              "inputs": {"text": "Disease prevention"},
              "top_k": 2
          },
          "fields": ["category", "chunk_text"]
       }'
  ```
</CodeGroup>
