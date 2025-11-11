# Target an index

> Target an index by host or name for data operations such as upsert and query.

<Warning>
  **Do not target an index by name in production.**

  When you target an index by name for data operations such as `upsert` and `query`, the SDK gets the unique DNS host for the index using the `describe_index` operation. This is convenient for testing but should be avoided in production because `describe_index` uses a different API than data operations and therefore adds an additional network call and point of failure. Instead, you should get an index host once and cache it for reuse or specify the host directly.
</Warning>

## Target by index host (recommended)

This method is recommended for production:

<Note>
  When using Private Endpoints for private connectivity between your application and Pinecone, you must target the index using the [Private Endpoint URL](/guides/production/connect-to-aws-privatelink#run-data-plane-commands) for the host.
</Note>

<CodeGroup>
  ```Python Python {5} theme={null}
  from pinecone.grpc import PineconeGRPC as Pinecone

  pc = Pinecone(api_key="YOUR_API_KEY")

  index = pc.Index(host="INDEX_HOST")
  ```

  ```javascript JavaScript {6} theme={null}
  import { Pinecone } from '@pinecone-database/pinecone';

  const pc = new Pinecone({ apiKey: 'YOUR_API_KEY' });

  // For the Node.js SDK, you must specify both the index host and name.
  const index = pc.index("INDEX_NAME", "INDEX_HOST");
  ```

  ```java Java {11} theme={null}
  import io.pinecone.clients.Index;
  import io.pinecone.configs.PineconeConfig;
  import io.pinecone.configs.PineconeConnection;

  public class TargetIndexByHostExample {
      public static void main(String[] args) {
          PineconeConfig config = new PineconeConfig("YOUR_API_KEY");
          config.setHost("INDEX_HOST");
          PineconeConnection connection = new PineconeConnection(config);
          // For the Java SDK, you must specify both the index host and name.
          Index index = new Index(connection, "INDEX_NAME");
      }
  }
  ```

  ```go Go {21} theme={null}
  package main

  import (
      "context"
      "fmt"
      "log"

      "github.com/pinecone-io/go-pinecone/v4/pinecone"
  )

  func main() {
      ctx := context.Background()

      pc, err := pinecone.NewClient(pinecone.NewClientParams{
          ApiKey: "YOUR_API_KEY",
      })
      if err != nil {
          log.Fatalf("Failed to create Client: %v", err)
      }

      // This creates a new gRPC index connection, targeting the namespace "example-namespace"
      idxConnectionNs1, err := pc.Index(pinecone.NewIndexConnParams{Host: "INDEX_HOST", Namespace: "example-namespace"})
      if err != nil {
          log.Fatalf("Failed to create IndexConnection for Host %v: %v", idx.Host, err)
      }

      // This reuses the gRPC index connection, targeting a different namespace
  	idxConnectionNs2 := idxConnectionNs1.WithNamespace("example-namespace2")
  }
  ```

  ```csharp C# {5} theme={null}
  using Pinecone;

  var pinecone = new PineconeClient("YOUR_API_KEY");

  var index = pinecone.Index(host: "INDEX_HOST");
  ```
</CodeGroup>

### Get an index host

You can get the unique DNS host for an index from the Pinecone console or the Pinecone API.

To get an index host from the Pinecone console:

1. Open the [Pinecone console](https://app.pinecone.io/organizations/-/projects).
2. Select the project containing the index.
3. Select the index.
4. Copy the URL under **HOST**.

To get an index host from the Pinecone API, use the [`describe_index`](/reference/api/latest/control-plane/describe_index) operation, which returns the index host as the `host` value:

<CodeGroup>
  ```Python Python theme={null}
  from pinecone.grpc import PineconeGRPC as Pinecone

  pc = Pinecone(api_key="YOUR_API_KEY")

  pc.describe_index(name="docs-example")

  # Response:
  # {'deletion_protection': 'disabled',
  #  'dimension': 1536,
  #  'host': 'docs-example-4zo0ijk.svc.us-east1-aws.pinecone.io',
  #  'metric': 'cosine',
  #  'name': 'docs-example',
  #  'spec': {'serverless': {'cloud': 'aws', 'region': 'us-east-1'}},
  #  'status': {'ready': True, 'state': 'Ready'}}
  ```

  ```JavaScript JavaScript theme={null}
  import { Pinecone } from '@pinecone-database/pinecone';

  const pc = new Pinecone({ apiKey: 'YOUR_API_KEY' });

  await pc.describeIndex('docs-example');

  // Response:
  // {
  //    "name": "docs-example",
  //    "dimension": 1536,
  //    "metric": "cosine",
  //    "host": "docs-example-4zo0ijk.svc.us-east1-aws.pinecone.io",
  //    "deletionProtection": "disabled",
  //    "spec": {
  //       "serverless": {
  //          "cloud": "aws",
  //          "region": "us-east-1"
  //       }
  //    },
  //    "status": {
  //       "ready": true,
  //       "state": "Ready"
  //    }
  // }
  ```

  ```java Java theme={null}
  import io.pinecone.clients.Pinecone;
  import org.openapitools.db_control.client.model.*;

  public class DescribeIndexExample {
      public static void main(String[] args) {
          Pinecone pc = new Pinecone.Builder("YOUR_API_KEY").build();
          IndexModel indexModel = pc.describeIndex("docs-example");
          System.out.println(indexModel);
      }
  }

  // Response:
  // class IndexModel {
  //     name: docs-example-java
  //     dimension: 1536
  //     metric: cosine
  //     host: docs-example-4zo0ijk.svc.us-west2-aws.pinecone.io
  //     deletionProtection: enabled
  //     spec: class IndexModelSpec {
  //         pod: null
  //         serverless: class ServerlessSpec {
  //             cloud: aws
  //             region: us-east-1
  //         }
  //     }
  //     status: class IndexModelStatus {
  //         ready: true
  //         state: Ready
  //     }
  // }
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

      idx, err := pc.DescribeIndex(ctx, "docs-example")
      if err != nil {
          log.Fatalf("Failed to describe index \"%v\": %v", idx.Name, err)
      } else {
          fmt.Printf("index: %v\n", prettifyStruct(idx))
      }
  }

  // Response:
  // index: {
  // 	"name": "docs-example",
  // 	"dimension": 1536,
  // 	"host": "docs-example-govk0nt.svc.apw5-4e34-81fa.pinecone.io",
  // 	"metric": "cosine",
  //  "deletion_protection": "disabled",
  // 	"spec": {
  // 	  "serverless": {
  // 		"cloud": "aws",
  // 		"region": "us-east-1"
  // 	  }
  // 	},
  // 	"status": {
  // 	  "ready": true,
  // 	  "state": "Ready"
  // 	}
  // }
  ```

  ```csharp C# theme={null}
  using Pinecone;

  var pinecone = new PineconeClient("YOUR_API_KEY");

  var indexModel = await pinecone.DescribeIndexAsync("docs-example");

  Console.WriteLine(indexModel);

  // Response:
  // {
  //   "name": "docs-example",
  //   "dimension": 1536,
  //   "metric": "cosine",
  //   "host": "docs-example-govk0nt.svc.aped-4627-b74a.pinecone.io",
  //   "deletion_protection": "disabled",
  //   "spec": {
  //     "pod": null,
  //     "serverless": {
  //       "cloud": "aws",
  //       "region": "us-east-1"
  //     }
  //   },
  //   "status": {
  //     "ready": true,
  //     "state": "Ready"
  //   }
  // }
  ```

  ```bash curl theme={null}
  PINECONE_API_KEY="YOUR_API_KEY"

  curl -i -X GET "https://api.pinecone.io/indexes/docs-example-curl" \
      -H "Api-Key: $PINECONE_API_KEY" \
      -H "X-Pinecone-API-Version: 2025-04"

  # Response:
  # {
  #    "name": "docs-example",
  #    "metric": "cosine",
  #    "dimension": 1536,
  #    "status": {
  #       "ready": true,
  #       "state": "Ready"
  #    },
  #    "host": "docs-example-4zo0ijk.svc.us-east1-aws.pinecone.io",
  #    "spec": {
  #       "serverless": {
  #          "region": "us-east-1",
  #          "cloud": "aws"
  #       }
  #    }
  # }
  ```
</CodeGroup>

## Target by index name

This method is convenient for testing but is not recommended for production:

<CodeGroup>
  ```Python Python theme={null}
  from pinecone.grpc import PineconeGRPC as Pinecone

  pc = Pinecone(api_key="YOUR_API_KEY")

  index = pc.Index("docs-example")
  ```

  ```javascript JavaScript theme={null}
  import { Pinecone } from '@pinecone-database/pinecone';

  const pc = new Pinecone({ apiKey: 'YOUR_API_KEY' });

  // For the Node.js SDK, you must specify both the index host and name.
  const index = pc.index('docs-example');
  ```

  ```java Java theme={null}
  import io.pinecone.clients.Index;
  import io.pinecone.clients.Pinecone;

  public class GenerateEmbeddings {
      public static void main(String[] args) throws ApiException {
          Pinecone pc = new Pinecone.Builder("YOUR_API_KEY").build();
          Index index = pc.getIndexConnection("docs-example");
      }
  }
  ```

  ```go Go theme={null}
  // It is not possible to target an index by name in the Go SDK. 
  // You must target an index by host.
  ```

  ```csharp C# theme={null}
  using Pinecone;

  var pinecone = new PineconeClient("YOUR_API_KEY");

  var index = pinecone.Index("docs-example");
  ```
</CodeGroup>
