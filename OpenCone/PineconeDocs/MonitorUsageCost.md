# Monitor usage and costs

> Monitor usage and costs for your Pinecone organization and indexes.

## Monitor organization-level usage and costs

<Note>
  To view usage and costs across your Pinecone organization, you must be an [organization owner](/guides/organizations/understanding-organizations#organization-owners). Also, this feature is available only to organizations on the Standard or Enterprise plans.
</Note>

The **Usage** dashboard in the Pinecone console gives you a detailed report of usage and costs across your organization, broken down by each billable SKU or aggregated by project or service. You can view the report in the console or download it as a CSV file for more detailed analysis.

1. Go to [**Settings > Usage**](https://app.pinecone.io/organizations/-/settings/usage) in the Pinecone console.
2. Select the time range to report on. This defaults to the last 30 days.
3. Select the scope for your report:
   * **SKU:** The usage and cost for each billable SKU, for example, read units per cloud region, storage size per cloud region, or tokens per embedding model.
   * **Project:** The aggregated cost for each project in your organization.
   * **Service:** The aggregated cost for each service your organization uses, for example, database (includes serverless back up and restore), assistants, inference (embedding and reranking), and collections.
4. Choose the specific SKUs, projects, or services you want to report on. This defaults to all.
5. To download the report as a CSV file, click **Download**.

   <Tip>
     The CSV download provides more granular detail than the console view, including breakdowns by individual index as well as project and index tags.
   </Tip>

Dates are shown in UTC to match billing invoices. Cost data is delayed up to three days from the actual usage date.

## Monitor index-level usage

You can monitor index-level usage directly in the Pinecone console, or you can pull them into [Prometheus](https://prometheus.io/). For more details, see [Monitoring](/guides/production/monitoring).

## Monitor operation-level usage

### Read units

[Query](/guides/search/search-overview), [fetch](/guides/manage-data/fetch-data), and [list by ID](/guides/manage-data/list-record-ids) requests return a `usage` parameter with the [read unit](/guides/manage-cost/understanding-cost#read-units) consumption of each request that is made.

<Warning>
  While Pinecone tracks read unit usage with decimal precision, the Pinecone API and SDKs round these values up to the nearest whole number in query, fetch, and list responses. For example, if a query uses 0.45 read units, the API and SDKs will report it as 1 read unit.

  For precise read unit reporting, see [index-level metrics](/guides/production/monitoring) or the organization-wide [Usage dashboard](/guides/manage-cost/monitor-usage-and-costs#monitor-organization-level-usage-and-costs).
</Warning>

Example query request:

<CodeGroup>
  ```Python Python theme={null}
  from pinecone.grpc import PineconeGRPC as Pinecone

  pc = Pinecone(api_key="YOUR_API_KEY")
  index = pc.Index("example-index")

  response = index.query(
      vector=[0.22,0.43,0.16,1,...], 
      namespace='example-namespace', 
      top_k=3,
      include_values=False,
      include_metadata=False
  )

  print(response)
  ```

  ```JavaScript JavaScript theme={null}
  import { Pinecone } from '@pinecone-database/pinecone'

  const pc = new Pinecone({ apiKey: "YOUR_API_KEY" })
  const index = pc.index("example-index")

  const queryResponse = await index.namespace('example-namespace').query({
      vector: [0.22,0.43,0.16,1,...],
      topK: 3,
      includeValues: false,
      includeMetadata: false,
  });

  console.log(queryResponse);
  ```

  ```java Java theme={null}
  import io.pinecone.clients.Index;
  import io.pinecone.configs.PineconeConfig;
  import io.pinecone.configs.PineconeConnection;
  import io.pinecone.unsigned_indices_model.QueryResponseWithUnsignedIndices;

  import java.util.Arrays;
  import java.util.List;

  public class QueryByVector {
      public static void main(String[] args) {
          PineconeConfig config = new PineconeConfig("YOUR_API_KEY");
          // To get the unique host for an index,
          // see https://docs.pinecone.io/guides/manage-data/target-an-index
          config.setHost("INDEX_HOST");
          PineconeConnection connection = new PineconeConnection(config);
          Index index = new Index(config, connection, "example-index");

          List<Float> query = Arrays.asList(0.22f,0.43f,0.16f,1f,...);
          QueryResponseWithUnsignedIndices queryResponse = index.query(3, query, null, null, null, "example-namespace", null, false, false);
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

  	queryVector := []float32{0.22, 0.43, 0.16, 1, ...}

  	res, err := idxConnection.QueryByVectorValues(ctx, &pinecone.QueryByVectorValuesRequest{
  		Vector:        queryVector,
  		TopK:          3,
  		IncludeValues: false,
  	})
  	if err != nil {
  		log.Fatalf("Error encountered when querying by vector: %v", err)
  	} else {
  		fmt.Printf(prettifyStruct(res))
  	}
  ```

  ```csharp C# theme={null}
  using Pinecone;

  var pinecone = new PineconeClient("YOUR_API_KEY");

  // To get the unique host for an index, 
  // see https://docs.pinecone.io/guides/manage-data/target-an-index
  var index = pinecone.Index(host: "INDEX_HOST");

  var queryResponse = await index.QueryAsync(new QueryRequest {
      Vector = new[] { 0.22f,0.43f,0.16f,1f,... },
      Namespace = "example-namespace",
      TopK = 3,
      IncludeMetadata = false,
  });
  ```
</CodeGroup>

The response looks like this:

<CodeGroup>
  ```python Python theme={null}
  {'matches': [{'id': 'record_193027', 'score': 0.00405937387, 'values': []},
               {'id': 'record_137452', 'score': 0.00405937387, 'values': []},
               {'id': 'record_132264', 'score': 0.00405937387, 'values': []}],
   'namespace': 'example-namespace',
   'usage': {'read_units': 1}}
  ```

  ```javascript JavaScript theme={null}
  {
    matches: [
      {
        id: 'record_186225',
        score: 0.00405937387,
        values: [],
        sparseValues: undefined,
        metadata: undefined
      },
      {
        id: 'record_164994',
        score: 0.00405937387,
        values: [],
        sparseValues: undefined,
        metadata: undefined
      },
      {
        id: 'record_186333',
        score: 0.00405937387,
        values: [],
        sparseValues: undefined,
        metadata: undefined
      }
    ],
    namespace: 'example-namespace',
    usage: { readUnits: 1 }
  }
  ```

  ```java Java theme={null}
  class QueryResponseWithUnsignedIndices {
      matches: [ScoredVectorWithUnsignedIndices {
          score: 0.004059374
          id: record_170370
          values: []
          metadata: 
          sparseValuesWithUnsignedIndices: SparseValuesWithUnsignedIndices {
              indicesWithUnsigned32Int: []
              values: []
          }
      }, ScoredVectorWithUnsignedIndices {
          score: 0.004059374
          id: record_107423
          values: []
          metadata: 
          sparseValuesWithUnsignedIndices: SparseValuesWithUnsignedIndices {
              indicesWithUnsigned32Int: []
              values: []
          }
      }, ScoredVectorWithUnsignedIndices {
          score: 0.004059374
          id: record_171426
          values: []
          metadata: 
          sparseValuesWithUnsignedIndices: SparseValuesWithUnsignedIndices {
              indicesWithUnsigned32Int: []
              values: []
          }
      }]
      namespace: example-index
      usage: read_units: 1
  }
  ```

  ```go Go theme={null}
  {
    "matches": [
      {
        "vector": {
          "id": "record_193027"
        },
        "score": 0.004059374
      },
      {
        "vector": {
          "id": "record_137452"
        },
        "score": 0.004059374
      },
      {
        "vector": {
          "id": "record_132264"
        },
        "score": 0.004059374
      }
    ],
    "usage": {
      "read_units": 1
    },
    "namespace": "example-index"
  }
  ```

  ```csharp C# theme={null}
  {
    "results": [],
    "matches": [
      {
        "id": "record_193027",
        "score": 0.004059374,
        "values": []
      },
      {
        "id": "record_137452",
        "score": 0.004059374,
        "values": []
      },
      {
        "id": "record_132264",
        "score": 0.004059374,
        "values": []
      }
    ],
    "namespace": "example-namespace",
    "usage": {
      "readUnits": 1
    }
  }
  ```
</CodeGroup>

For a more in-depth demonstration of how to use read units to inspect read costs, see [this notebook](https://github.com/pinecone-io/examples/blob/master/docs/read-units-demonstrated.ipynb).

### Embedding tokens

Requests to one of [Pinecone's hosted embedding models](/guides/index-data/create-an-index#embedding-models), either directly via the [`embed` operation](/reference/api/latest/inference/generate-embeddings) or automatically when upserting or querying an [index with integrated embedding](/guides/index-data/indexing-overview#integrated-embedding), return a `usage` parameter with the total tokens generated.

For example, the following request to use the `multilingual-e5-large` model to generate embeddings for sentences related to the word “apple” might return this request and summary of embedding tokens generated:

<CodeGroup>
  ```python Python theme={null}
  # Import the Pinecone library
  from pinecone.grpc import PineconeGRPC as Pinecone
  from pinecone import ServerlessSpec
  import time

  # Initialize a Pinecone client with your API key
  pc = Pinecone(api_key="YOUR_API_KEY")

  # Define a sample dataset where each item has a unique ID and piece of text
  data = [
      {"id": "vec1", "text": "Apple is a popular fruit known for its sweetness and crisp texture."},
      {"id": "vec2", "text": "The tech company Apple is known for its innovative products like the iPhone."},
      {"id": "vec3", "text": "Many people enjoy eating apples as a healthy snack."},
      {"id": "vec4", "text": "Apple Inc. has revolutionized the tech industry with its sleek designs and user-friendly interfaces."},
      {"id": "vec5", "text": "An apple a day keeps the doctor away, as the saying goes."},
      {"id": "vec6", "text": "Apple Computer Company was founded on April 1, 1976, by Steve Jobs, Steve Wozniak, and Ronald Wayne as a partnership."}
  ]

  # Convert the text into numerical vectors that Pinecone can index
  embeddings = pc.inference.embed(
      model="llama-text-embed-v2",
      inputs=[d['text'] for d in data],
      parameters={"input_type": "passage", "truncate": "END"}
  )

  print(embeddings)
  ```

  ```javascript JavaScript theme={null}
  // Import the Pinecone library
  import { Pinecone } from '@pinecone-database/pinecone';

  // Initialize a Pinecone client with your API key
  const pc = new Pinecone({ apiKey: 'YOUR_API_KEY' });

  // Define a sample dataset where each item has a unique ID and piece of text
  const data = [
    { id: 'vec1', text: 'Apple is a popular fruit known for its sweetness and crisp texture.' },
    { id: 'vec2', text: 'The tech company Apple is known for its innovative products like the iPhone.' },
    { id: 'vec3', text: 'Many people enjoy eating apples as a healthy snack.' },
    { id: 'vec4', text: 'Apple Inc. has revolutionized the tech industry with its sleek designs and user-friendly interfaces.' },
    { id: 'vec5', text: 'An apple a day keeps the doctor away, as the saying goes.' },
    { id: 'vec6', text: 'Apple Computer Company was founded on April 1, 1976, by Steve Jobs, Steve Wozniak, and Ronald Wayne as a partnership.' }
  ];

  // Convert the text into numerical vectors that Pinecone can index
  const model = 'llama-text-embed-v2';

  const embeddings = await pc.inference.embed(
    model,
    data.map(d => d.text),
    { inputType: 'passage', truncate: 'END' }
  );

  console.log(embeddings);
  ```

  ```java Java theme={null}
  // Import the required classes
  import io.pinecone.clients.Index;
  import io.pinecone.clients.Inference;
  import io.pinecone.clients.Pinecone;
  import org.openapitools.inference.client.ApiException;
  import org.openapitools.inference.client.model.Embedding;
  import org.openapitools.inference.client.model.EmbeddingsList;

  import java.math.BigDecimal;
  import java.util.*;
  import java.util.stream.Collectors;

  public class GenerateEmbeddings {
      public static void main(String[] args) throws ApiException {
          // Initialize a Pinecone client with your API key
          Pinecone pc = new Pinecone.Builder("YOUR_API_KEY").build();
          Inference inference = pc.getInferenceClient();

          // Prepare input sentences to be embedded
          List<DataObject> data = Arrays.asList(
              new DataObject("vec1", "Apple is a popular fruit known for its sweetness and crisp texture."),
              new DataObject("vec2", "The tech company Apple is known for its innovative products like the iPhone."),
              new DataObject("vec3", "Many people enjoy eating apples as a healthy snack."),
              new DataObject("vec4", "Apple Inc. has revolutionized the tech industry with its sleek designs and user-friendly interfaces."),
              new DataObject("vec5", "An apple a day keeps the doctor away, as the saying goes."),
              new DataObject("vec6", "Apple Computer Company was founded on April 1, 1976, by Steve Jobs, Steve Wozniak, and Ronald Wayne as a partnership.")
          );

          List<String> inputs = data.stream()
              .map(DataObject::getText)
              .collect(Collectors.toList());

          // Specify the embedding model and parameters
          String embeddingModel = "llama-text-embed-v2";

          Map<String, Object> parameters = new HashMap<>();
          parameters.put("input_type", "passage");
          parameters.put("truncate", "END");

          // Generate embeddings for the input data
          EmbeddingsList embeddings = inference.embed(embeddingModel, parameters, inputs);

          // Get embedded data
          List<Embedding> embeddedData = embeddings.getData();
      }

      private static List<Float> convertBigDecimalToFloat(List<BigDecimal> bigDecimalValues) {
          return bigDecimalValues.stream()
              .map(BigDecimal::floatValue)
              .collect(Collectors.toList());
      }
  }

  class DataObject {
      private String id;
      private String text;

      public DataObject(String id, String text) {
          this.id = id;
          this.text = text;
      }

      public String getId() {
          return id;
      }
      public String getText() {
          return text;
      }
  }
  ```

  ```go Go theme={null}
  package main

  // Import the required packages
  import (
      "context"
     	"encoding/json"
      "fmt"
      "log"

      "github.com/pinecone-io/go-pinecone/v4/pinecone"
  )

  type Data struct {
      ID   string
      Text string
  }

  type Query struct {
  	Text string
  }

  func prettifyStruct(obj interface{}) string {
      bytes, _ := json.MarshalIndent(obj, "", "  ")
      return string(bytes)
  }

  func main() {
      ctx := context.Background()

      // Initialize a Pinecone client with your API key
      pc, err := pinecone.NewClient(pinecone.NewClientParams{
          ApiKey: "YOUR_API_KEY",
      })
      if err != nil {
          log.Fatalf("Failed to create Client: %v", err)
      }

      // Define a sample dataset where each item has a unique ID and piece of text
      data := []Data{
          {ID: "vec1", Text: "Apple is a popular fruit known for its sweetness and crisp texture."},
          {ID: "vec2", Text: "The tech company Apple is known for its innovative products like the iPhone."},
          {ID: "vec3", Text: "Many people enjoy eating apples as a healthy snack."},
          {ID: "vec4", Text: "Apple Inc. has revolutionized the tech industry with its sleek designs and user-friendly interfaces."},
          {ID: "vec5", Text: "An apple a day keeps the doctor away, as the saying goes."},
          {ID: "vec6", Text: "Apple Computer Company was founded on April 1, 1976, by Steve Jobs, Steve Wozniak, and Ronald Wayne as a partnership."},
      }

      // Specify the embedding model and parameters
      embeddingModel := "llama-text-embed-v2"

      docParameters := pinecone.EmbedParameters{
          InputType: "passage",
          Truncate:  "END",
      }

      // Convert the text into numerical vectors that Pinecone can index
      var documents []string
      for _, d := range data {
          documents = append(documents, d.Text)
      }

      docEmbeddingsResponse, err := pc.Inference.Embed(ctx, &pinecone.EmbedRequest{
          Model:      embeddingModel,
          TextInputs: documents,
          Parameters: docParameters,
      }) 
      if err != nil {
          log.Fatalf("Failed to embed documents: %v", err)
      } else {
          fmt.Printf(prettifyStruct(docEmbeddingsResponse))
      }
  }
  ```

  ```csharp C# theme={null}
  using Pinecone;
  using System;
  using System.Collections.Generic;

  // Initialize a Pinecone client with your API key
  var pinecone = new PineconeClient("YOUR_API_KEY");

  // Prepare input sentences to be embedded
  var data = new[]
  {
      new
      {
          Id = "vec1",
          Text = "Apple is a popular fruit known for its sweetness and crisp texture."
      },
      new
      {
          Id = "vec2",
          Text = "The tech company Apple is known for its innovative products like the iPhone."
      },
      new
      {
          Id = "vec3",
          Text = "Many people enjoy eating apples as a healthy snack."
      },
      new
      {
          Id = "vec4",
          Text = "Apple Inc. has revolutionized the tech industry with its sleek designs and user-friendly interfaces."
      },
      new
      {
          Id = "vec5",
          Text = "An apple a day keeps the doctor away, as the saying goes."
      },
      new
      {
          Id = "vec6",
          Text = "Apple Computer Company was founded on April 1, 1976, by Steve Jobs, Steve Wozniak, and Ronald Wayne as a partnership."
      }
  };

  // Specify the embedding model and parameters
  var embeddingModel = "llama-text-embed-v2";

  // Generate embeddings for the input data
  var embeddings = await pinecone.Inference.EmbedAsync(new EmbedRequest
  {
      Model = embeddingModel,
      Inputs = data.Select(item => new EmbedRequestInputsItem { Text = item.Text }),
      Parameters = new Dictionary<string, object?>
      {
          ["input_type"] = "passage",
          ["truncate"] = "END"
      }
  });

  Console.WriteLine(embeddings);
  ```

  ```shell curl theme={null}
  PINECONE_API_KEY="YOUR_API_KEY"

  curl https://api.pinecone.io/embed \
    -H "Api-Key: $PINECONE_API_KEY" \
    -H "Content-Type: application/json" \
    -H "X-Pinecone-API-Version: 2025-04" \
    -d '{
        "model": "llama-text-embed-v2",
        "parameters": {
          "input_type": "passage",
          "truncate": "END"
        },
        "inputs": [
          {"text": "Apple is a popular fruit known for its sweetness and crisp texture."},
          {"text": "The tech company Apple is known for its innovative products like the iPhone."},
          {"text": "Many people enjoy eating apples as a healthy snack."},
          {"text": "Apple Inc. has revolutionized the tech industry with its sleek designs and user-friendly interfaces."},
          {"text": "An apple a day keeps the doctor away, as the saying goes."},
          {"text": "Apple Computer Company was founded on April 1, 1976, by Steve Jobs, Steve Wozniak, and Ronald Wayne as a partnership."}
        ]
    }'
  ```
</CodeGroup>

The returned object looks like this:

<CodeGroup>
  ```python Python theme={null}
  EmbeddingsList(
      model='llama-text-embed-v2',
      data=[
          {'values': [0.04925537109375, -0.01313018798828125, -0.0112762451171875, ...]},
          ...
      ],
      usage={'total_tokens': 130}
  )
  ```

  ```javascript JavaScript theme={null}
  EmbeddingsList(1) [
    {
      values: [
        0.04925537109375, 
        -0.01313018798828125, 
        -0.0112762451171875,
        ...
      ]
    },
    ...
    model: 'llama-text-embed-v2',
    data: [ { values: [Array] } ],
    usage: { totalTokens: 130 }
  ]
  ```

  ```java Java theme={null}
  class EmbeddingsList {
      model: llama-text-embed-v2
      data: [class Embedding {
          values: [0.04925537109375, -0.01313018798828125, -0.0112762451171875, ...]
          additionalProperties: null
      }, ...]
      usage: class EmbeddingsListUsage {
          totalTokens: 130
          additionalProperties: null
      }
      additionalProperties: null
  }
  ```

  ```go Go theme={null}
  {
    "data": [
      {
        "values": [
          0.03942871,
          -0.010177612,
          -0.046051025,
          ...
        ]
      },
      ...
    ], 
    "model": "llama-text-embed-v2",
    "usage": {
      "total_tokens": 130
    }
  }
  ```

  ```csharp C# theme={null}
  {
    "model": "llama-text-embed-v2",
    "data": [
      {
        "values": [
          0.04913330078125,
          -0.01306915283203125,
          -0.01116180419921875,
          ...
        ]
      },
      ...
    ],
    "usage": {
      "total_tokens": 130
    }
  }
  ```

  ```json curl theme={null}
  {
    "data": [
      {
        "values": [
          0.04925537109375,
          -0.01313018798828125,
          -0.0112762451171875,
          ...
        ]
      }, 
      ...
    ],
    "model": "llama-text-embed-v2",
    "usage": {
      "total_tokens": 130
    }
  }
  ```
</CodeGroup>

## See also

* [Understanding cost](/guides/manage-cost/understanding-cost)
* [Manage cost](/guides/manage-cost/manage-cost)
