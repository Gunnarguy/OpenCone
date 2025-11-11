# Upsert records

> Add or update records in Pinecone indexes and manage data with namespaces.

This page shows you how to upsert records into a namespace in an index. [Namespaces](/guides/index-data/indexing-overview#namespaces) let you partition records within an index and are essential for [implementing multitenancy](/guides/index-data/implement-multitenancy) when you need to isolate the data of each customer/user.

If a record ID already exists, upserting overwrites the entire record. To change only part of a record, [update ](/guides/manage-data/update-data) the record.

<Tip>
  To control costs when ingesting large datasets (10,000,000+ records), use [import](/guides/index-data/import-data) instead of upsert.
</Tip>

## Upsert dense vectors

<Tabs>
  <Tab title="Upsert text">
    <Note>
      Upserting text is supported only for [indexes with integrated embedding](/guides/index-data/indexing-overview#integrated-embedding).
    </Note>

    To upsert source text into a [dense index with integrated embedding](/guides/index-data/create-an-index#create-a-dense-index), use the [`upsert_records`](/reference/api/latest/data-plane/upsert_records) operation. Pinecone converts the text to dense vectors automatically using the hosted dense embedding model associated with the index.

    * Specify the [`namespace`](/guides/index-data/indexing-overview#namespaces) to upsert into. If the namespace doesn't exist, it is created. To use the default namespace, set the namespace to `"__default__"`.
    * Format your input data as records, each with the following:
      * An `_id` field with a unique record identifier for the index namespace. `id` can be used as an alias for `_id`.
      * A field with the source text to convert to a vector. This field must match the `field_map` specified in the index.
      * Additional fields are stored as record [metadata](/guides/index-data/indexing-overview#metadata) and can be returned in search results or used to [filter search results](/guides/search/filter-by-metadata).

    For example, the following code converts the sentences in the `chunk_text` fields to dense vectors and then upserts them into `example-namespace` in an example index. The additional `category` field is stored as metadata.

    <CodeGroup>
      ```python Python theme={null}
      from pinecone import Pinecone

      pc = Pinecone(api_key="YOUR_API_KEY")

      # To get the unique host for an index, 
      # see https://docs.pinecone.io/guides/manage-data/target-an-index
      index = pc.Index(host="INDEX_HOST")

      # Upsert records into a namespace
      # `chunk_text` fields are converted to dense vectors
      # `category` fields are stored as metadata
      index.upsert_records(
          "example-namespace",
          [
              {
                  "_id": "rec1",
                  "chunk_text": "Apples are a great source of dietary fiber, which supports digestion and helps maintain a healthy gut.",
                  "category": "digestive system", 
              },
              {
                  "_id": "rec2",
                  "chunk_text": "Apples originated in Central Asia and have been cultivated for thousands of years, with over 7,500 varieties available today.",
                  "category": "cultivation",
              },
              {
                  "_id": "rec3",
                  "chunk_text": "Rich in vitamin C and other antioxidants, apples contribute to immune health and may reduce the risk of chronic diseases.",
                  "category": "immune system",
              },
              {
                  "_id": "rec4",
                  "chunk_text": "The high fiber content in apples can also help regulate blood sugar levels, making them a favorable snack for people with diabetes.",
                  "category": "endocrine system",
              },
          ]
      ) 
      ```

      ```javascript JavaScript theme={null}
      import { Pinecone } from '@pinecone-database/pinecone'

      const pc = new Pinecone({ apiKey: "YOUR_API_KEY" })

      // To get the unique host for an index, 
      // see https://docs.pinecone.io/guides/manage-data/target-an-index
      const namespace = pc.index("INDEX_NAME", "INDEX_HOST").namespace("example-namespace");

      // Upsert records into a namespace
      // `chunk_text` fields are converted to dense vectors
      // `category` is stored as metadata
      await namespace.upsertRecords([
              {
                  "_id": "rec1",
                  "chunk_text": "Apples are a great source of dietary fiber, which supports digestion and helps maintain a healthy gut.",
                  "category": "digestive system", 
              },
              {
                  "_id": "rec2",
                  "chunk_text": "Apples originated in Central Asia and have been cultivated for thousands of years, with over 7,500 varieties available today.",
                  "category": "cultivation",
              },
              {
                  "_id": "rec3",
                  "chunk_text": "Rich in vitamin C and other antioxidants, apples contribute to immune health and may reduce the risk of chronic diseases.",
                  "category": "immune system",
              },
              {
                  "_id": "rec4",
                  "chunk_text": "The high fiber content in apples can also help regulate blood sugar levels, making them a favorable snack for people with diabetes.",
                  "category": "endocrine system",
              }
      ]);
      ```

      ```java Java theme={null}
      import io.pinecone.clients.Index;
      import io.pinecone.configs.PineconeConfig;
      import io.pinecone.configs.PineconeConnection;
      import org.openapitools.db_data.client.ApiException;

      import java.util.*;

      public class UpsertText {
          public static void main(String[] args) throws ApiException {
              PineconeConfig config = new PineconeConfig("YOUR_API_KEY");
              config.setHost("INDEX_HOST");
              PineconeConnection connection = new PineconeConnection(config);

              Index index = new Index(config, connection, "integrated-dense-java");
              ArrayList<Map<String, String>> upsertRecords = new ArrayList<>();

              HashMap<String, String> record1 = new HashMap<>();
              record1.put("_id", "rec1");
              record1.put("category", "digestive system");
              record1.put("chunk_text", "Apples are a great source of dietary fiber, which supports digestion and helps maintain a healthy gut.");

              HashMap<String, String> record2 = new HashMap<>();
              record2.put("_id", "rec2");
              record2.put("category", "cultivation");
              record2.put("chunk_text", "Apples originated in Central Asia and have been cultivated for thousands of years, with over 7,500 varieties available today.");

              HashMap<String, String> record3 = new HashMap<>();
              record3.put("_id", "rec3");
              record3.put("category", "immune system");
              record3.put("chunk_text", "Rich in vitamin C and other antioxidants, apples contribute to immune health and may reduce the risk of chronic diseases.");

              HashMap<String, String> record4 = new HashMap<>();
              record4.put("_id", "rec4");
              record4.put("category", "endocrine system");
              record4.put("chunk_text", "The high fiber content in apples can also help regulate blood sugar levels, making them a favorable snack for people with diabetes.");

              upsertRecords.add(record1);
              upsertRecords.add(record2);
              upsertRecords.add(record3);
              upsertRecords.add(record4);

              index.upsertRecords("example-namespace", upsertRecords);
          }
      }
      ```

      ```go Go theme={null}
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

          // To get the unique host for an index, 
          // see https://docs.pinecone.io/guides/manage-data/target-an-index
          idxConnection, err := pc.Index(pinecone.NewIndexConnParams{Host: "INDEX_HOST", Namespace: "example-namespace"})
          if err != nil {
              log.Fatalf("Failed to create IndexConnection for Host: %v", err)
      	  }

          // Upsert records into a namespace
          // `chunk_text` fields are converted to dense vectors
          // `category` is stored as metadata
      	records := []*pinecone.IntegratedRecord{
              {
                  "_id": "rec1",
                  "chunk_text": "Apples are a great source of dietary fiber, which supports digestion and helps maintain a healthy gut.",
                  "category": "digestive system", 
              },
              {
                  "_id": "rec2",
                  "chunk_text": "Apples originated in Central Asia and have been cultivated for thousands of years, with over 7,500 varieties available today.",
                  "category": "cultivation",
              },
              {
                  "_id": "rec3",
                  "chunk_text": "Rich in vitamin C and other antioxidants, apples contribute to immune health and may reduce the risk of chronic diseases.",
                  "category": "immune system",
              },
              {
                  "_id": "rec4",
                  "chunk_text": "The high fiber content in apples can also help regulate blood sugar levels, making them a favorable snack for people with diabetes.",
                  "category": "endocrine system",
              },
      	}

      	err = idxConnection.UpsertRecords(ctx, records)
      	if err != nil {
      		log.Fatalf("Failed to upsert vectors: %v", err)
      	}
      }
      ```

      ```csharp C# theme={null}
      using Pinecone;

      var pinecone = new PineconeClient("YOUR_API_KEY");

      var index = pinecone.Index(host: "INDEX_HOST");

      await index.UpsertRecordsAsync(
          "example-namespace",
          [
              new UpsertRecord
              {
                  Id = "rec1",
                  AdditionalProperties =
                  {
                      ["chunk_text"] = "AAPL reported a year-over-year revenue increase, expecting stronger Q3 demand for its flagship phones.",
                      ["category"] = "technology",
                      ["quarter"] = "Q3",
                  },
              },
              new UpsertRecord
              {
                  Id = "rec2",
                  AdditionalProperties =
                  {
                      ["chunk_text"] = "AAPL may consider healthcare integrations in Q4 to compete with tech rivals entering the consumer wellness space.",
                      ["category"] = "technology",
                      ["quarter"] = "Q4",
                  },
              },  
              new UpsertRecord
              {
                  Id = "rec3",
                  AdditionalProperties =
                  {
                      ["chunk_text"] = "AAPL may consider healthcare integrations in Q4 to compete with tech rivals entering the consumer wellness space.",
                      ["category"] = "technology",
                      ["quarter"] = "Q4",
                  },
              },
              new UpsertRecord
              {
                  Id = "rec4",
                  AdditionalProperties =
                  {
                      ["chunk_text"] = "AAPL's strategic Q3 partnerships with semiconductor suppliers could mitigate component risks and stabilize iPhone production",
                      ["category"] = "technology",
                      ["quarter"] = "Q3",
                  },
              },
          ]
      );
      ```

      ```shell curl theme={null}
      # To get the unique host for an index,
      # see https://docs.pinecone.io/guides/manage-data/target-an-index
      INDEX_HOST="INDEX_HOST"
      NAMESPACE="YOUR_NAMESPACE"
      PINECONE_API_KEY="YOUR_API_KEY"

      # Upsert records into a namespace
      # `chunk_text` fields are converted to dense vectors
      # `category` is stored as metadata
      curl "https://$INDEX_HOST/records/namespaces/$NAMESPACE/upsert" \
        -H "Content-Type: application/x-ndjson" \
        -H "Api-Key: $PINECONE_API_KEY" \
        -H "X-Pinecone-API-Version: 2025-04" \
        -d '{"_id": "rec1", "chunk_text": "Apples are a great source of dietary fiber, which supports digestion and helps maintain a healthy gut.", "category": "digestive system"}
            {"_id": "rec2", "chunk_text": "Apples originated in Central Asia and have been cultivated for thousands of years, with over 7,500 varieties available today.", "category": "cultivation"}
            {"_id": "rec3", "chunk_text": "Rich in vitamin C and other antioxidants, apples contribute to immune health and may reduce the risk of chronic diseases.", "category": "immune system"}
            {"_id": "rec4", "chunk_text": "The high fiber content in apples can also help regulate blood sugar levels, making them a favorable snack for people with diabetes.", "category": "endocrine system"}'
      ```
    </CodeGroup>
  </Tab>

  <Tab title="Upsert vectors">
    To upsert dense vectors into a [dense index](/guides/index-data/create-an-index#create-a-dense-index), use the [`upsert`](/reference/api/latest/data-plane/upsert) operation as follows:

    * Specify the [`namespace`](/guides/index-data/indexing-overview#namespaces) to upsert into. If the namespace doesn't exist, it is created. To use the default namespace, set the namespace to `"__default__"`.
    * Format your input data as records, each with the following:
      * An `id` field with a unique record identifier for the index namespace.
      * A `values` field with the dense vector values.
      * Optionally, a `metadata` field with [key-value pairs](/guides/index-data/indexing-overview#metadata) to store additional information or context. When you query the index, you can use metadata to [filter search results](/guides/search/filter-by-metadata).

    <CodeGroup>
      ```Python Python theme={null}
      from pinecone.grpc import PineconeGRPC as Pinecone

      pc = Pinecone(api_key="YOUR_API_KEY")

      # To get the unique host for an index, 
      # see https://docs.pinecone.io/guides/manage-data/target-an-index
      index = pc.Index(host="INDEX_HOST")

      index.upsert(
        vectors=[
          {
            "id": "A", 
            "values": [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1], 
            "metadata": {"genre": "comedy", "year": 2020}
          },
          {
            "id": "B", 
            "values": [0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2],
            "metadata": {"genre": "documentary", "year": 2019}
          },
          {
            "id": "C", 
            "values": [0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3],
            "metadata": {"genre": "comedy", "year": 2019}
          },
          {
            "id": "D", 
            "values": [0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4],
            "metadata": {"genre": "drama"}
          }
        ],
        namespace="example-namespace"
      )
      ```

      ```javascript JavaScript theme={null}
      import { Pinecone } from '@pinecone-database/pinecone'

      const pc = new Pinecone({ apiKey: "YOUR_API_KEY" })

      // To get the unique host for an index, 
      // see https://docs.pinecone.io/guides/manage-data/target-an-index
      const index = pc.index("INDEX_NAME", "INDEX_HOST")

      const records = [
          {
            id: 'A',
            values: [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1],
            metadata: { genre: "comedy", year: 2020 },
          },
          {
            id: 'B',
            values: [0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2],
            metadata: { genre: "documentary", year: 2019 },
          },
          {
            id: 'C',
            values: [0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3],
            metadata: { genre: "comedy", year: 2019 },
          },
          {
            id: 'D',
            values: [0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4],
            metadata: { genre: "drama" },
          }
      ]

      await index.('example-namespace').upsert(records);
      ```

      ```java Java theme={null}
      import com.google.protobuf.Struct;
      import com.google.protobuf.Value;
      import io.pinecone.clients.Index;
      import io.pinecone.configs.PineconeConfig;
      import io.pinecone.configs.PineconeConnection;

      import java.util.Arrays;
      import java.util.List;

      public class UpsertExample {
          public static void main(String[] args) {
              PineconeConfig config = new PineconeConfig("YOUR_API_KEY");
              // To get the unique host for an index, 
              // see https://docs.pinecone.io/guides/manage-data/target-an-index
              config.setHost("INDEX_HOST");
              PineconeConnection connection = new PineconeConnection(config);
              Index index = new Index(connection, "INDEX_NAME");
              List<Float> values1 = Arrays.asList(0.1f, 0.1f, 0.1f, 0.1f, 0.1f, 0.1f, 0.1f, 0.1f);
              List<Float> values2 = Arrays.asList(0.2f, 0.2f, 0.2f, 0.2f, 0.2f, 0.2f, 0.2f, 0.2f);
              List<Float> values3 = Arrays.asList(0.3f, 0.3f, 0.3f, 0.3f, 0.3f, 0.3f, 0.3f, 0.3f);
              List<Float> values4 = Arrays.asList(0.4f, 0.4f, 0.4f, 0.4f, 0.4f, 0.4f, 0.4f, 0.4f);
              Struct metaData1 = Struct.newBuilder()
                      .putFields("genre", Value.newBuilder().setStringValue("comedy").build())
                      .putFields("year", Value.newBuilder().setNumberValue(2020).build())
                      .build();
              Struct metaData2 = Struct.newBuilder()
                      .putFields("genre", Value.newBuilder().setStringValue("documentary").build())
                      .putFields("year", Value.newBuilder().setNumberValue(2019).build())
                      .build();
              Struct metaData3 = Struct.newBuilder()
                      .putFields("genre", Value.newBuilder().setStringValue("comedy").build())
                      .putFields("year", Value.newBuilder().setNumberValue(2019).build())
                      .build();
              Struct metaData4 = Struct.newBuilder()
                      .putFields("genre", Value.newBuilder().setStringValue("drama").build())
                      .build();

              index.upsert("A", values1, null, null, metaData1, 'example-namespace');
              index.upsert("B", values2, null, null, metaData2, 'example-namespace');
              index.upsert("C", values3, null, null, metaData3, 'example-namespace');
              index.upsert("D", values4, null, null, metaData4, 'example-namespace');
          }
      }
      ```

      ```go Go theme={null}
      package main

      import (
          "context"
          "fmt"
          "log"

          "github.com/pinecone-io/go-pinecone/v4/pinecone"
          "google.golang.org/protobuf/types/known/structpb"
      )

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

          metadataMap1 := map[string]interface{}{
              "genre": "comedy",
              "year": 2020,
          }

          metadata1, err := structpb.NewStruct(metadataMap1)
          if err != nil {
              log.Fatalf("Failed to create metadata map: %v", err)
          }

          metadataMap2 := map[string]interface{}{
              "genre": "documentary",
              "year": 2019,
          }

          metadata2, err := structpb.NewStruct(metadataMap2)
          if err != nil {
              log.Fatalf("Failed to create metadata map: %v", err)
          }

          metadataMap3 := map[string]interface{}{
              "genre": "comedy",
              "year": 2019,
          }

          metadata3, err := structpb.NewStruct(metadataMap3)
          if err != nil {
              log.Fatalf("Failed to create metadata map: %v", err)
          }

          metadataMap4 := map[string]interface{}{
              "genre": "drama",
          }

          metadata4, err := structpb.NewStruct(metadataMap4)
          if err != nil {
              log.Fatalf("Failed to create metadata map: %v", err)
          }

          vectors := []*pinecone.Vector{
              {
                  Id:     "A",
                  Values: []float32{0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1},
                  Metadata: metadata1,
              },
              {
                  Id:     "B",
                  Values: []float32{0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2},
                  Metadata: metadata2,
              },
              {
                  Id:     "C",
                  Values: []float32{0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3},
                  Metadata: metadata3,
              },   
              {
                  Id:     "D",
                  Values: []float32{0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4},
                  Metadata: metadata4,
              },   
          }

          count, err := idxConnection.UpsertVectors(ctx, vectors)
          if err != nil {
              log.Fatalf("Failed to upsert vectors: %v", err)
          } else {
              fmt.Printf("Successfully upserted %d vector(s)!\n", count)
          }
      }
      ```

      ```csharp C# theme={null}
      using Pinecone;

      var pinecone = new PineconeClient("YOUR_API_KEY");

      // To get the unique host for an index, 
      // see https://docs.pinecone.io/guides/manage-data/target-an-index
      var index = pinecone.Index(host: "INDEX_HOST");

      var upsertResponse = await index.UpsertAsync(new UpsertRequest {
          Vectors = new[]
          {
              new Vector
              {
                  Id = "A",
                  Values = new[] { 0.1f, 0.1f, 0.1f, 0.1f, 0.1f, 0.1f, 0.1f, 0.1f },
                  Metadata = new Metadata {
                      ["genre"] = new("comedy"),
                      ["year"] = new(2020),
                  },
              },
              new Vector
              {
                  Id = "B",
                  Values = new[] { 0.2f, 0.2f, 0.2f, 0.2f, 0.2f, 0.2f, 0.2f, 0.2f },
                  Metadata = new Metadata {
                      ["genre"] = new("documentary"),
                      ["year"] = new(2019),
                  },
              },
              new Vector
              {
                  Id = "C",
                  Values = new[] { 0.3f, 0.3f, 0.3f, 0.3f, 0.3f, 0.3f, 0.3f, 0.3f },
                  Metadata = new Metadata {
                      ["genre"] = new("comedy"),
                      ["year"] = new(2019),
                  },
              },
              new Vector
              {
                  Id = "D",
                  Values = new[] { 0.4f, 0.4f, 0.4f, 0.4f, 0.4f, 0.4f, 0.4f, 0.4f },
                  Metadata = new Metadata {
                      ["genre"] = new("drama"),
                  },
              }
          },
          Namespace = "example-namespace",
      });
      ```

      ```bash curl theme={null}
      # To get the unique host for an index,
      # see https://docs.pinecone.io/guides/manage-data/target-an-index
      PINECONE_API_KEY="YOUR_API_KEY"
      INDEX_HOST="INDEX_HOST"

      curl "https://$INDEX_HOST/vectors/upsert" \
        -H "Api-Key: $PINECONE_API_KEY" \
        -H 'Content-Type: application/json' \
        -H "X-Pinecone-API-Version: 2025-04" \
        -d '{
          "vectors": [
            {
              "id": "A",
              "values": [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1],
              "metadata": {"genre": "comedy", "year": 2020}
            },
            {
              "id": "B",
              "values": [0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2],
              "metadata": {"genre": "documentary", "year": 2019}
            },
            {
              "id": "C",
              "values": [0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3],
              "metadata": {"genre": "comedy", "year": 2019}
            },
            {
              "id": "D",
              "values": [0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4],
              "metadata": {"genre": "drama"}
            }
          ],
          "namespace": "example-namespace"
        }'
      ```
    </CodeGroup>
  </Tab>
</Tabs>

## Upsert sparse vectors

<Tabs>
  <Tab title="Upsert text">
    <Note>
      Upserting text is supported only for [indexes with integrated embedding](/guides/index-data/indexing-overview#integrated-embedding).
    </Note>

    To upsert source text into a [sparse index with integrated embedding](/guides/index-data/create-an-index#create-a-sparse-index), use the [`upsert_records`](/reference/api/latest/data-plane/upsert_records) operation. Pinecone converts the text to sparse vectors automatically using the hosted sparse embedding model associated with the index.

    * Specify the [`namespace`](/guides/index-data/indexing-overview#namespaces) to upsert into. If the namespace doesn't exist, it is created. To use the default namespace, set the namespace to `"__default__"`.
    * Format your input data as records, each with the following:
      * An `_id` field with a unique record identifier for the index namespace. `id` can be used as an alias for `_id`.
      * A field with the source text to convert to a vector. This field must match the `field_map` specified in the index.
      * Additional fields are stored as record [metadata](/guides/index-data/indexing-overview#metadata) and can be returned in search results or used to [filter search results](/guides/search/filter-by-metadata).

    For example, the following code converts the sentences in the `chunk_text` fields to sparse vectors and then upserts them into `example-namespace` in an example index. The additional `category` and `quarter` fields are stored as metadata.

    <CodeGroup>
      ```python Python theme={null}
      from pinecone import Pinecone

      pc = Pinecone(api_key="YOUR_API_KEY")

      # To get the unique host for an index, 
      # see https://docs.pinecone.io/guides/manage-data/target-an-index
      index = pc.Index(host="INDEX_HOST")

      # Upsert records into a namespace
      # `chunk_text` fields are converted to sparse vectors
      # `category` and `quarter` fields are stored as metadata
      index.upsert_records(
          "example-namespace",
          [
              { 
                  "_id": "vec1", 
                  "chunk_text": "AAPL reported a year-over-year revenue increase, expecting stronger Q3 demand for its flagship phones.", 
                  "category": "technology",
                  "quarter": "Q3"
              },
              { 
                  "_id": "vec2", 
                  "chunk_text": "Analysts suggest that AAPL'\''s upcoming Q4 product launch event might solidify its position in the premium smartphone market.", 
                  "category": "technology",
                  "quarter": "Q4"
              },
              { 
                  "_id": "vec3", 
                  "chunk_text": "AAPL'\''s strategic Q3 partnerships with semiconductor suppliers could mitigate component risks and stabilize iPhone production.",
                  "category": "technology",
                  "quarter": "Q3"
              },
              { 
                  "_id": "vec4", 
                  "chunk_text": "AAPL may consider healthcare integrations in Q4 to compete with tech rivals entering the consumer wellness space.", 
                  "category": "technology",
                  "quarter": "Q4"
              }
          ]
      )

      time.sleep(10) # Wait for the upserted vectors to be indexed
      ```

      ```javascript JavaScript theme={null}
      import { Pinecone } from '@pinecone-database/pinecone'

      const pc = new Pinecone({ apiKey: "YOUR_API_KEY" })

      // To get the unique host for an index, 
      // see https://docs.pinecone.io/guides/manage-data/target-an-index
      const namespace = pc.index("INDEX_NAME", "INDEX_HOST").namespace("example-namespace");

      // Upsert records into a namespace
      // `chunk_text` fields are converted to sparse vectors
      // `category` and `quarter` fields are stored as metadata
      await namespace.upsertRecords([
          { 
              "_id": "vec1", 
              "chunk_text": "AAPL reported a year-over-year revenue increase, expecting stronger Q3 demand for its flagship phones.", 
              "category": "technology",
              "quarter": "Q3"
          },
          { 
              "_id": "vec2", 
              "chunk_text": "Analysts suggest that AAPL'\''s upcoming Q4 product launch event might solidify its position in the premium smartphone market.", 
              "category": "technology",
              "quarter": "Q4"
          },
          { 
              "_id": "vec3", 
              "chunk_text": "AAPL'\''s strategic Q3 partnerships with semiconductor suppliers could mitigate component risks and stabilize iPhone production.",
              "category": "technology",
              "quarter": "Q3"
          },
          { 
              "_id": "vec4", 
              "chunk_text": "AAPL may consider healthcare integrations in Q4 to compete with tech rivals entering the consumer wellness space.", 
              "category": "technology",
              "quarter": "Q4"
          }
      ]);
      ```

      ```java Java theme={null}
      import io.pinecone.clients.Index;
      import io.pinecone.configs.PineconeConfig;
      import io.pinecone.configs.PineconeConnection;
      import org.openapitools.db_data.client.ApiException;

      import java.util.*;

      public class UpsertText {
          public static void main(String[] args) throws ApiException {
              PineconeConfig config = new PineconeConfig("YOUR_API_KEY");
              config.setHost("INDEX_HOST");
              PineconeConnection connection = new PineconeConnection(config);

              Index index = new Index(config, connection, "integrated-sparse-java");
              ArrayList<Map<String, String>> upsertRecords = new ArrayList<>();

              HashMap<String, String> record1 = new HashMap<>();
              record1.put("_id", "rec1");
              record1.put("category", "digestive system");
              record1.put("chunk_text", "Apples are a great source of dietary fiber, which supports digestion and helps maintain a healthy gut.");

              HashMap<String, String> record2 = new HashMap<>();
              record2.put("_id", "rec2");
              record2.put("category", "cultivation");
              record2.put("chunk_text", "Apples originated in Central Asia and have been cultivated for thousands of years, with over 7,500 varieties available today.");

              HashMap<String, String> record3 = new HashMap<>();
              record3.put("_id", "rec3");
              record3.put("category", "immune system");
              record3.put("chunk_text", "Rich in vitamin C and other antioxidants, apples contribute to immune health and may reduce the risk of chronic diseases.");

              HashMap<String, String> record4 = new HashMap<>();
              record4.put("_id", "rec4");
              record4.put("category", "endocrine system");
              record4.put("chunk_text", "The high fiber content in apples can also help regulate blood sugar levels, making them a favorable snack for people with diabetes.");

              upsertRecords.add(record1);
              upsertRecords.add(record2);
              upsertRecords.add(record3);
              upsertRecords.add(record4);

              index.upsertRecords("example-namespace", upsertRecords);
          }
      }
      ```

      ```go Go theme={null}
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

          // To get the unique host for an index, 
          // see https://docs.pinecone.io/guides/manage-data/target-an-index
          idxConnection, err := pc.Index(pinecone.NewIndexConnParams{Host: "INDEX_HOST", Namespace: "example-namespace"})
          if err != nil {
              log.Fatalf("Failed to create IndexConnection for Host: %v", err)
      	  }

          // Upsert records into a namespace
          // `chunk_text` fields are converted to sparse vectors
          // `category` and `quarter` fields are stored as metadata
      	records := []*pinecone.IntegratedRecord{
      		{
      			"_id":        "vec1",
      			"chunk_text": "AAPL reported a year-over-year revenue increase, expecting stronger Q3 demand for its flagship phones.",
      			"category":   "technology",
      			"quarter":    "Q3",
      		},
      		{
      			"_id":        "vec2",
      			"chunk_text": "Analysts suggest that AAPL's upcoming Q4 product launch event might solidify its position in the premium smartphone market.",
      			"category":   "technology",
      			"quarter":    "Q4",
      		},
      		{
      			"_id":        "vec3",
      			"chunk_text": "AAPL's strategic Q3 partnerships with semiconductor suppliers could mitigate component risks and stabilize iPhone production.",
      			"category":   "technology",
      			"quarter":    "Q3",
      		},
      		{
      			"_id":        "vec4",
      			"chunk_text": "AAPL may consider healthcare integrations in Q4 to compete with tech rivals entering the consumer wellness space.",
      			"category":   "technology",
      			"quarter":    "Q4",
      		},
      	}

      	err = idxConnection.UpsertRecords(ctx, records)
      	if err != nil {
      		log.Fatalf("Failed to upsert vectors: %v", err)
      	}
      }
      ```

      ```csharp C# theme={null}
      using Pinecone;

      var pinecone = new PineconeClient("YOUR_API_KEY");

      var index = pinecone.Index(host: "INDEX_HOST");

      await index.UpsertRecordsAsync(
          "example-namespace",
          [
              new UpsertRecord
              {
                  Id = "rec1",
                  AdditionalProperties =
                  {
                      ["chunk_text"] = "AAPL reported a year-over-year revenue increase, expecting stronger Q3 demand for its flagship phones.",
                      ["category"] = "technology",
                      ["quarter"] = "Q3",
                  },
              },
              new UpsertRecord
              {
                  Id = "rec2",
                  AdditionalProperties =
                  {
                      ["chunk_text"] = "AAPL may consider healthcare integrations in Q4 to compete with tech rivals entering the consumer wellness space.",
                      ["category"] = "technology",
                      ["quarter"] = "Q4",
                  },
              },  
              new UpsertRecord
              {
                  Id = "rec3",
                  AdditionalProperties =
                  {
                      ["chunk_text"] = "AAPL may consider healthcare integrations in Q4 to compete with tech rivals entering the consumer wellness space.",
                      ["category"] = "technology",
                      ["quarter"] = "Q4",
                  },
              },
              new UpsertRecord
              {
                  Id = "rec4",
                  AdditionalProperties =
                  {
                      ["chunk_text"] = "AAPL's strategic Q3 partnerships with semiconductor suppliers could mitigate component risks and stabilize iPhone production",
                      ["category"] = "technology",
                      ["quarter"] = "Q3",
                  },
              },
          ]
      );
      ```

      ```shell curl theme={null}
      INDEX_HOST="INDEX_HOST"
      NAMESPACE="YOUR_NAMESPACE"
      PINECONE_API_KEY="YOUR_API_KEY"

      curl  "https://$INDEX_HOST/records/namespaces/$NAMESPACE/upsert" \
          -H "Content-Type: application/x-ndjson" \
          -H "Api-Key: $PINECONE_API_KEY" \
          -H "X-Pinecone-API-Version: 2025-04" \
          -d '{ "_id": "vec1", "chunk_text": "AAPL reported a year-over-year revenue increase, expecting stronger Q3 demand for its flagship phones.", "category": "technology", "quarter": "Q3" }
            { "_id": "vec2", "chunk_text": "Analysts suggest that AAPL'\''s upcoming Q4 product launch event might solidify its position in the premium smartphone market.", "category": "technology", "quarter": "Q4" }
            { "_id": "vec3", "chunk_text": "AAPL'\''s strategic Q3 partnerships with semiconductor suppliers could mitigate component risks and stabilize iPhone production.", "category": "technology", "quarter": "Q3" }
            { "_id": "vec4", "chunk_text": "AAPL may consider healthcare integrations in Q4 to compete with tech rivals entering the consumer wellness space.", "category": "technology", "quarter": "Q4" }'
      ```
    </CodeGroup>
  </Tab>

  <Tab title="Upsert vectors">
    To upsert sparse vectors into a [sparse index](/guides/index-data/create-an-index#create-a-sparse-index), use the [`upsert`](/reference/api/latest/data-plane/upsert) operation as follows:

    * Specify the [`namespace`](/guides/index-data/indexing-overview#namespaces) to upsert into. If the namespace doesn't exist, it is created. To use the default namespace, set the namespace to `"__default__"`.
    * Format your input data as records, each with the following:
      * An `id` field with a unique record identifier for the index namespace.
      * A `sparse_values` field with the sparse vector values and indices.
      * Optionally, a `metadata` field with [key-value pairs](/guides/index-data/indexing-overview#metadata) to store additional information or context. When you query the index, you can use metadata to [filter search results](/guides/search/filter-by-metadata).

    For example, the following code upserts sparse vector representations of sentences related to the term "apple", with the source text and additional fields stored as metadata:

    <CodeGroup>
      ```python Python theme={null}
      from pinecone import Pinecone, SparseValues, Vector

      pc = Pinecone(api_key="YOUR_API_KEY")

      # To get the unique host for an index, 
      # see https://docs.pinecone.io/guides/manage-data/target-an-index
      index = pc.Index(host="INDEX_HOST")

      index.upsert(
          namespace="example-namespace",
          vectors=[
              {
                  "id": "vec1",
                  "sparse_values": {
                      "values": [1.7958984, 0.41577148, 2.828125, 2.8027344, 2.8691406, 1.6533203, 5.3671875, 1.3046875, 0.49780273, 0.5722656, 2.71875, 3.0820312, 2.5019531, 4.4414062, 3.3554688],
                      "indices": [822745112, 1009084850, 1221765879, 1408993854, 1504846510, 1596856843, 1640781426, 1656251611, 1807131503, 2543655733, 2902766088, 2909307736, 3246437992, 3517203014, 3590924191]
                  },
                  "metadata": {
                      "chunk_text": "AAPL reported a year-over-year revenue increase, expecting stronger Q3 demand for its flagship phones.",
                      "category": "technology",
                      "quarter": "Q3"
                  }
              },
              {
                  "id": "vec2",
                  "sparse_values": {
                      "values": [0.4362793, 3.3457031, 2.7714844, 3.0273438, 3.3164062, 5.6015625, 2.4863281, 0.38134766, 1.25, 2.9609375, 0.34179688, 1.4306641, 0.34375, 3.3613281, 1.4404297, 2.2558594, 2.2597656, 4.8710938, 0.5605469],
                      "indices": [131900689, 592326839, 710158994, 838729363, 1304885087, 1640781426, 1690623792, 1807131503, 2066971792, 2428553208, 2548600401, 2577534050, 3162218338, 3319279674, 3343062801, 3476647774, 3485013322, 3517203014, 4283091697]
                  },
                  "metadata": {
                      "chunk_text": "Analysts suggest that AAPL'\''s upcoming Q4 product launch event might solidify its position in the premium smartphone market.",
                      "category": "technology",
                      "quarter": "Q4"
                  }
              },
              {
                  "id": "vec3",
                  "sparse_values": {
                      "values": [2.6875, 4.2929688, 3.609375, 3.0722656, 2.1152344, 5.78125, 3.7460938, 3.7363281, 1.2695312, 3.4824219, 0.7207031, 0.0826416, 4.671875, 3.7011719, 2.796875, 0.61621094],
                      "indices": [8661920, 350356213, 391213188, 554637446, 1024951234, 1640781426, 1780689102, 1799010313, 2194093370, 2632344667, 2641553256, 2779594451, 3517203014, 3543799498, 3837503950, 4283091697]
                  },
                  "metadata": {
                      "chunk_text": "AAPL'\''s strategic Q3 partnerships with semiconductor suppliers could mitigate component risks and stabilize iPhone production",
                      "category": "technology",
                      "quarter": "Q3"
                  }
              },
              {
                  "id": "vec4",
                  "sparse_values": {
                      "values": [0.73046875, 0.46972656, 2.84375, 5.2265625, 3.3242188, 1.9863281, 0.9511719, 0.5019531, 4.4257812, 3.4277344, 0.41308594, 4.3242188, 2.4179688, 3.1757812, 1.0224609, 2.0585938, 2.5859375],
                      "indices": [131900689, 152217691, 441495248, 1640781426, 1851149807, 2263326288, 2502307765, 2641553256, 2684780967, 2966813704, 3162218338, 3283104238, 3488055477, 3530642888, 3888762515, 4152503047, 4177290673]
                  },
                  "metadata": {
                      "chunk_text": "AAPL may consider healthcare integrations in Q4 to compete with tech rivals entering the consumer wellness space.",
                      "category": "technology",
                      "quarter": "Q4"
                  }
              }
          ]
      )
      ```

      ```javascript JavaScript theme={null}
      import { Pinecone } from '@pinecone-database/pinecone'

      const pc = new Pinecone({ apiKey: 'YOUR_API_KEY' });

      // To get the unique host for an index, 
      // see https://docs.pinecone.io/guides/manage-data/target-an-index
      const index = pc.index("INDEX_NAME", "INDEX_HOST")

      await index.namespace('example-namespace').upsert([
        {
          id: 'vec1',
          sparseValues: {
            indices: [822745112, 1009084850, 1221765879, 1408993854, 1504846510, 1596856843, 1640781426, 1656251611, 1807131503, 2543655733, 2902766088, 2909307736, 3246437992, 3517203014, 3590924191],
            values: [1.7958984, 0.41577148, 2.828125, 2.8027344, 2.8691406, 1.6533203, 5.3671875, 1.3046875, 0.49780273, 0.5722656, 2.71875, 3.0820312, 2.5019531, 4.4414062, 3.3554688]
          },
          metadata: { 
            chunk_text: 'AAPL reported a year-over-year revenue increase, expecting stronger Q3 demand for its flagship phones.', 
            category: 'technology',
            quarter: 'Q3' 
          }
        },
        {
          id: 'vec2',
          sparseValues: {
            indices: [131900689, 592326839, 710158994, 838729363, 1304885087, 1640781426, 1690623792, 1807131503, 2066971792, 2428553208, 2548600401, 2577534050, 3162218338, 3319279674, 3343062801, 3476647774, 3485013322, 3517203014, 4283091697],
            values: [0.4362793, 3.3457031, 2.7714844, 3.0273438, 3.3164062, 5.6015625, 2.4863281, 0.38134766, 1.25, 2.9609375, 0.34179688, 1.4306641, 0.34375, 3.3613281, 1.4404297, 2.2558594, 2.2597656, 4.8710938, 0.5605469]
          },
          metadata: { 
            chunk_text: "Analysts suggest that AAPL's upcoming Q4 product launch event might solidify its position in the premium smartphone market.", 
            category: 'technology',
            quarter: 'Q4' 
          }
        },
        {
          id: 'vec3',
          sparseValues: {
            indices: [8661920, 350356213, 391213188, 554637446, 1024951234, 1640781426, 1780689102, 1799010313, 2194093370, 2632344667, 2641553256, 2779594451, 3517203014, 3543799498, 3837503950, 4283091697],
            values: [2.6875, 4.2929688, 3.609375, 3.0722656, 2.1152344, 5.78125, 3.7460938, 3.7363281, 1.2695312, 3.4824219, 0.7207031, 0.0826416, 4.671875, 3.7011719, 2.796875, 0.61621094]
          },
          metadata: { 
            chunk_text: "AAPL's strategic Q3 partnerships with semiconductor suppliers could mitigate component risks and stabilize iPhone production", 
            category: 'technology',
            quarter: 'Q3' 
          }
        },
        {
          id: 'vec4',
          sparseValues: {
            indices: [131900689, 152217691, 441495248, 1640781426, 1851149807, 2263326288, 2502307765, 2641553256, 2684780967, 2966813704, 3162218338, 3283104238, 3488055477, 3530642888, 3888762515, 4152503047, 4177290673],
            values: [0.73046875, 0.46972656, 2.84375, 5.2265625, 3.3242188, 1.9863281, 0.9511719, 0.5019531, 4.4257812, 3.4277344, 0.41308594, 4.3242188, 2.4179688, 3.1757812, 1.0224609, 2.0585938, 2.5859375]
          },
          metadata: { 
            chunk_text: 'AAPL may consider healthcare integrations in Q4 to compete with tech rivals entering the consumer wellness space.', 
            category: 'technology',
            quarter: 'Q4' 
          }
        }
      ]);
      ```

      ```java Java theme={null}
      import io.pinecone.clients.Pinecone;
      import io.pinecone.clients.Index;
      import com.google.protobuf.Struct;
      import com.google.protobuf.Value;

      import java.util.*;

      public class UpsertSparseVectors {
          public static void main(String[] args) throws InterruptedException {
              // Instantiate Pinecone class
              Pinecone pinecone = new Pinecone.Builder("YOUR_API)KEY").build();
              
              Index index = pinecone.getIndexConnection("docs-example");

              // Record 1
              ArrayList<Long> indices1 = new ArrayList<>(Arrays.asList(
                      822745112L, 1009084850L, 1221765879L, 1408993854L, 1504846510L,
                      1596856843L, 1640781426L, 1656251611L, 1807131503L, 2543655733L,
                      2902766088L, 2909307736L, 3246437992L, 3517203014L, 3590924191L
              ));

              ArrayList<Float> values1 = new ArrayList<>(Arrays.asList(
                      1.7958984f, 0.41577148f, 2.828125f, 2.8027344f, 2.8691406f,
                      1.6533203f, 5.3671875f, 1.3046875f, 0.49780273f, 0.5722656f,
                      2.71875f, 3.0820312f, 2.5019531f, 4.4414062f, 3.3554688f
              ));

              Struct metaData1 = Struct.newBuilder()
                      .putFields("chunk_text", Value.newBuilder().setStringValue("AAPL reported a year-over-year revenue increase, expecting stronger Q3 demand for its flagship phones.").build())
                      .putFields("category", Value.newBuilder().setStringValue("technology").build())
                      .putFields("quarter", Value.newBuilder().setStringValue("Q3").build())
                      .build();

              // Record 2
              ArrayList<Long> indices2 = new ArrayList<>(Arrays.asList(
                      131900689L, 592326839L, 710158994L, 838729363L, 1304885087L,
                      1640781426L, 1690623792L, 1807131503L, 2066971792L, 2428553208L,
                      2548600401L, 2577534050L, 3162218338L, 3319279674L, 3343062801L,
                      3476647774L, 3485013322L, 3517203014L, 4283091697L
              ));

              ArrayList<Float> values2 = new ArrayList<>(Arrays.asList(
                      0.4362793f, 3.3457031f, 2.7714844f, 3.0273438f, 3.3164062f,
                      5.6015625f, 2.4863281f, 0.38134766f, 1.25f, 2.9609375f,
                      0.34179688f, 1.4306641f, 0.34375f, 3.3613281f, 1.4404297f,
                      2.2558594f, 2.2597656f, 4.8710938f, 0.5605469f
              ));

              Struct metaData2 = Struct.newBuilder()
                      .putFields("chunk_text", Value.newBuilder().setStringValue("Analysts suggest that AAPL'\\''s upcoming Q4 product launch event might solidify its position in the premium smartphone market.").build())
                      .putFields("category", Value.newBuilder().setStringValue("technology").build())
                      .putFields("quarter", Value.newBuilder().setStringValue("Q4").build())
                      .build();

              // Record 3
              ArrayList<Long> indices3 = new ArrayList<>(Arrays.asList(
                      8661920L, 350356213L, 391213188L, 554637446L, 1024951234L,
                      1640781426L, 1780689102L, 1799010313L, 2194093370L, 2632344667L,
                      2641553256L, 2779594451L, 3517203014L, 3543799498L,
                      3837503950L, 4283091697L
              ));

              ArrayList<Float> values3 = new ArrayList<>(Arrays.asList(
                      2.6875f, 4.2929688f, 3.609375f, 3.0722656f, 2.1152344f,
                      5.78125f, 3.7460938f, 3.7363281f, 1.2695312f, 3.4824219f,
                      0.7207031f, 0.0826416f, 4.671875f, 3.7011719f, 2.796875f,
                      0.61621094f
              ));

              Struct metaData3 = Struct.newBuilder()
                      .putFields("chunk_text", Value.newBuilder().setStringValue("AAPL'\\''s strategic Q3 partnerships with semiconductor suppliers could mitigate component risks and stabilize iPhone production").build())
                      .putFields("category", Value.newBuilder().setStringValue("technology").build())
                      .putFields("quarter", Value.newBuilder().setStringValue("Q3").build())
                      .build();

              // Record 4
              ArrayList<Long> indices4 = new ArrayList<>(Arrays.asList(
                      131900689L, 152217691L, 441495248L, 1640781426L, 1851149807L,
                      2263326288L, 2502307765L, 2641553256L, 2684780967L, 2966813704L,
                      3162218338L, 3283104238L, 3488055477L, 3530642888L, 3888762515L,
                      4152503047L, 4177290673L
              ));

              ArrayList<Float> values4 = new ArrayList<>(Arrays.asList(
                      0.73046875f, 0.46972656f, 2.84375f, 5.2265625f, 3.3242188f,
                      1.9863281f, 0.9511719f, 0.5019531f, 4.4257812f, 3.4277344f,
                      0.41308594f, 4.3242188f, 2.4179688f, 3.1757812f, 1.0224609f,
                      2.0585938f, 2.5859375f
              ));

              Struct metaData4 = Struct.newBuilder()
                      .putFields("chunk_text", Value.newBuilder().setStringValue("AAPL may consider healthcare integrations in Q4 to compete with tech rivals entering the consumer wellness space").build())
                      .putFields("category", Value.newBuilder().setStringValue("technology").build())
                      .putFields("quarter", Value.newBuilder().setStringValue("Q4").build())
                      .build();

              index.upsert("vec1", Collections.emptyList(), indices1, values1, metaData1, "example-namespace");
              index.upsert("vec2", Collections.emptyList(), indices2, values2, metaData2, "example-namespace");
              index.upsert("vec3", Collections.emptyList(), indices3, values3, metaData3, "example-namespace");
              index.upsert("vec4", Collections.emptyList(), indices4, values4, metaData4, "example-namespace");
      ```

      ```go Go theme={null}
      package main

      import (
      	"context"
      	"fmt"
      	"log"

      	"github.com/pinecone-io/go-pinecone/v4/pinecone"
      	"google.golang.org/protobuf/types/known/structpb"
      )

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

      	sparseValues1 := pinecone.SparseValues{
      		Indices: []uint32{822745112, 1009084850, 1221765879, 1408993854, 1504846510, 1596856843, 1640781426, 1656251611, 1807131503, 2543655733, 2902766088, 2909307736, 3246437992, 3517203014, 3590924191},
      		Values:  []float32{1.7958984, 0.41577148, 2.828125, 2.8027344, 2.8691406, 1.6533203, 5.3671875, 1.3046875, 0.49780273, 0.5722656, 2.71875, 3.0820312, 2.5019531, 4.4414062, 3.3554688},
      	}

      	metadataMap1 := map[string]interface{}{
      		"chunk_text": "AAPL reported a year-over-year revenue increase, expecting stronger Q3 demand for its flagship phones",
      		"category":    "technology",
      		"quarter":     "Q3",
      	}

      	metadata1, err := structpb.NewStruct(metadataMap1)
      	if err != nil {
      		log.Fatalf("Failed to create metadata map: %v", err)
      	}

      	sparseValues2 := pinecone.SparseValues{
      		Indices: []uint32{131900689, 592326839, 710158994, 838729363, 1304885087, 1640781426, 1690623792, 1807131503, 2066971792, 2428553208, 2548600401, 2577534050, 3162218338, 3319279674, 3343062801, 3476647774, 3485013322, 3517203014, 4283091697},
      		Values:  []float32{0.4362793, 3.3457031, 2.7714844, 3.0273438, 3.3164062, 5.6015625, 2.4863281, 0.38134766, 1.25, 2.9609375, 0.34179688, 1.4306641, 0.34375, 3.3613281, 1.4404297, 2.2558594, 2.2597656, 4.8710938, 0.560546},
      	}

      	metadataMap2 := map[string]interface{}{
      		"chunk_text": "Analysts suggest that AAPL's upcoming Q4 product launch event might solidify its position in the premium smartphone market.",
      		"category":    "technology",
      		"quarter":     "Q4",
      	}

      	metadata2, err := structpb.NewStruct(metadataMap2)
      	if err != nil {
      		log.Fatalf("Failed to create metadata map: %v", err)
      	}

      	sparseValues3 := pinecone.SparseValues{
      		Indices: []uint32{8661920, 350356213, 391213188, 554637446, 1024951234, 1640781426, 1780689102, 1799010313, 2194093370, 2632344667, 2641553256, 2779594451, 3517203014, 3543799498, 3837503950, 4283091697},
      		Values:  []float32{2.6875, 4.2929688, 3.609375, 3.0722656, 2.1152344, 5.78125, 3.7460938, 3.7363281, 1.2695312, 3.4824219, 0.7207031, 0.0826416, 4.671875, 3.7011719, 2.796875, 0.61621094},
      	}

      	metadataMap3 := map[string]interface{}{
      		"chunk_text": "AAPL's strategic Q3 partnerships with semiconductor suppliers could mitigate component risks and stabilize iPhone production",
      		"category":    "technology",
      		"quarter":     "Q3",
      	}

      	metadata3, err := structpb.NewStruct(metadataMap3)
      	if err != nil {
      		log.Fatalf("Failed to create metadata map: %v", err)
      	}

      	sparseValues4 := pinecone.SparseValues{
      		Indices: []uint32{131900689, 152217691, 441495248, 1640781426, 1851149807, 2263326288, 2502307765, 2641553256, 2684780967, 2966813704, 3162218338, 3283104238, 3488055477, 3530642888, 3888762515, 4152503047, 4177290673},
      		Values:  []float32{0.73046875, 0.46972656, 2.84375, 5.2265625, 3.3242188, 1.9863281, 0.9511719, 0.5019531, 4.4257812, 3.4277344, 0.41308594, 4.3242188, 2.4179688, 3.1757812, 1.0224609, 2.0585938, 2.5859375},
      	}

      	metadataMap4 := map[string]interface{}{
      		"chunk_text": "AAPL may consider healthcare integrations in Q4 to compete with tech rivals entering the consumer wellness space.",
      		"category":    "technology",
      		"quarter":     "Q4",
      	}

      	metadata4, err := structpb.NewStruct(metadataMap4)
      	if err != nil {
      		log.Fatalf("Failed to create metadata map: %v", err)
      	}

      	vectors := []*pinecone.Vector{
      		{
      			Id:           "vec1",
      			SparseValues: &sparseValues1,
      			Metadata:     metadata1,
      		},
      		{
      			Id:           "vec2",
      			SparseValues: &sparseValues2,
      			Metadata:     metadata2,
      		},
      		{
      			Id:           "vec3",
      			SparseValues: &sparseValues3,
      			Metadata:     metadata3,
      		},
      		{
      			Id:           "vec4",
      			SparseValues: &sparseValues4,
      			Metadata:     metadata4,
      		},
      	}

      	count, err := idxConnection.UpsertVectors(ctx, vectors)
      	if err != nil {
      		log.Fatalf("Failed to upsert vectors: %v", err)
      	} else {
      		fmt.Printf("Successfully upserted %d vector(s)!\n", count)
      	}
      }
      ```

      ```csharp C# theme={null}
      using Pinecone;

      var pinecone = new PineconeClient("YOUR_API_KEY");

      var index = pinecone.Index("docs-example");

      var vector1 = new Vector
      {
          Id = "vec1",
          SparseValues = new SparseValues
          {
              Indices = new uint[] { 822745112, 1009084850, 1221765879, 1408993854, 1504846510, 1596856843, 1640781426, 1656251611, 1807131503, 2543655733, 2902766088, 2909307736, 3246437992, 3517203014, 3590924191 },
              Values = new ReadOnlyMemory<float>([1.7958984f, 0.41577148f, 2.828125f, 2.8027344f, 2.8691406f, 1.6533203f, 5.3671875f, 1.3046875f, 0.49780273f, 0.5722656f, 2.71875f, 3.0820312f, 2.5019531f, 4.4414062f, 3.3554688f])
          },
          Metadata = new Metadata {
              ["chunk_text"] = new("AAPL reported a year-over-year revenue increase, expecting stronger Q3 demand for its flagship phones."),
              ["category"] = new("technology"),
              ["quarter"] = new("Q3"),
          },
      };

      var vector2 = new Vector
      {
          Id = "vec2",
          SparseValues = new SparseValues
          {
              Indices = new uint[] { 131900689, 592326839, 710158994, 838729363, 1304885087, 1640781426, 1690623792, 1807131503, 2066971792, 2428553208, 2548600401, 2577534050, 3162218338, 3319279674, 3343062801, 3476647774, 3485013322, 3517203014, 4283091697 },
              Values = new ReadOnlyMemory<float>([0.4362793f, 3.3457031f, 2.7714844f, 3.0273438f, 3.3164062f, 5.6015625f, 2.4863281f, 0.38134766f, 1.25f, 2.9609375f, 0.34179688f, 1.4306641f, 0.34375f, 3.3613281f, 1.4404297f, 2.2558594f, 2.2597656f, 4.8710938f, 0.5605469f])
          },
          Metadata = new Metadata {
              ["chunk_text"] = new("Analysts suggest that AAPL'\''s upcoming Q4 product launch event might solidify its position in the premium smartphone market."),
              ["category"] = new("technology"),
              ["quarter"] = new("Q4"),
          },
      };

      var vector3 = new Vector
      {
          Id = "vec3",
          SparseValues = new SparseValues
          {
              Indices = new uint[] { 8661920, 350356213, 391213188, 554637446, 1024951234, 1640781426, 1780689102, 1799010313, 2194093370, 2632344667, 2641553256, 2779594451, 3517203014, 3543799498, 3837503950, 4283091697 },
              Values = new ReadOnlyMemory<float>([2.6875f, 4.2929688f, 3.609375f, 3.0722656f, 2.1152344f, 5.78125f, 3.7460938f, 3.7363281f, 1.2695312f, 3.4824219f, 0.7207031f, 0.0826416f, 4.671875f, 3.7011719f, 2.796875f, 0.61621094f])
          },
          Metadata = new Metadata {
              ["chunk_text"] = new("AAPL'\''s strategic Q3 partnerships with semiconductor suppliers could mitigate component risks and stabilize iPhone production"),
              ["category"] = new("technology"),
              ["quarter"] = new("Q3"),
          },    
      };

      var vector4 = new Vector
      {
          Id = "vec4",
          SparseValues = new SparseValues
          {
              Indices = new uint[] { 131900689, 152217691, 441495248, 1640781426, 1851149807, 2263326288, 2502307765, 2641553256, 2684780967, 2966813704, 3162218338, 3283104238, 3488055477, 3530642888, 3888762515, 4152503047, 4177290673 },
              Values = new ReadOnlyMemory<float>([0.73046875f, 0.46972656f, 2.84375f, 5.2265625f, 3.3242188f, 1.9863281f, 0.9511719f, 0.5019531f, 4.4257812f, 3.4277344f, 0.41308594f, 4.3242188f, 2.4179688f, 3.1757812f, 1.0224609f, 2.0585938f, 2.5859375f])
          },
          Metadata = new Metadata {
              ["chunk_text"] = new("AAPL may consider healthcare integrations in Q4 to compete with tech rivals entering the consumer wellness space."),
              ["category"] = new("technology"),
              ["quarter"] = new("Q4"),
          },
      };

      // Upsert vector
      Console.WriteLine("Upserting vector...");
      var upsertResponse = await index.UpsertAsync(new UpsertRequest
      {
          Vectors = new List<Vector> { vector1, vector2, vector3, vector4 },
          Namespace = "example-namespace"
      });
      Console.WriteLine($"Upserted {upsertResponse.UpsertedCount} vector");
      ```

      ```shell curl theme={null}
      INDEX_HOST="INDEX_HOST"
      PINECONE_API_KEY="YOUR_API_KEY"

      curl "http://$INDEX_HOST/vectors/upsert" \
        -H "Content-Type: application/json" \
        -H "Api-Key: $PINECONE_API_KEY" \
        -H "X-Pinecone-API-Version: 2025-04" \
        -d '{
              "namespace": "example-namespace",
              "vectors": [
                  {
                      "id": "vec1",
                      "sparseValues": {
                          "values": [1.7958984, 0.41577148, 2.828125, 2.8027344, 2.8691406, 1.6533203, 5.3671875, 1.3046875, 0.49780273, 0.5722656, 2.71875, 3.0820312, 2.5019531, 4.4414062, 3.3554688],
                          "indices": [822745112, 1009084850, 1221765879, 1408993854, 1504846510, 1596856843, 1640781426, 1656251611, 1807131503, 2543655733, 2902766088, 2909307736, 3246437992, 3517203014, 3590924191]
                      },
                      "metadata": {
                          "chunk_text": "AAPL reported a year-over-year revenue increase, expecting stronger Q3 demand for its flagship phones.",
                          "category": "technology",
                          "quarter": "Q3"
                      }
                  },
                  {
                      "id": "vec2",
                      "sparseValues": {
                          "values": [0.4362793, 3.3457031, 2.7714844, 3.0273438, 3.3164062, 5.6015625, 2.4863281, 0.38134766, 1.25, 2.9609375, 0.34179688, 1.4306641, 0.34375, 3.3613281, 1.4404297, 2.2558594, 2.2597656, 4.8710938, 0.5605469],
                          "indices": [131900689, 592326839, 710158994, 838729363, 1304885087, 1640781426, 1690623792, 1807131503, 2066971792, 2428553208, 2548600401, 2577534050, 3162218338, 3319279674, 3343062801, 3476647774, 3485013322, 3517203014, 4283091697]
                      },
                      "metadata": {
                          "chunk_text": "Analysts suggest that AAPL'\''s upcoming Q4 product launch event might solidify its position in the premium smartphone market.",
                          "category": "technology",
                          "quarter": "Q4"
                      }
                  },
                  {
                      "id": "vec3",
                      "sparseValues": {
                          "values": [2.6875, 4.2929688, 3.609375, 3.0722656, 2.1152344, 5.78125, 3.7460938, 3.7363281, 1.2695312, 3.4824219, 0.7207031, 0.0826416, 4.671875, 3.7011719, 2.796875, 0.61621094],
                          "indices": [8661920, 350356213, 391213188, 554637446, 1024951234, 1640781426, 1780689102, 1799010313, 2194093370, 2632344667, 2641553256, 2779594451, 3517203014, 3543799498, 3837503950, 4283091697]
                      },
                      "metadata": {
                          "chunk_text": "AAPL'\''s strategic Q3 partnerships with semiconductor suppliers could mitigate component risks and stabilize iPhone production",
                          "category": "technology",
                          "quarter": "Q3"
                      }
                  },
                  {
                      "id": "vec4",
                      "sparseValues": {
                          "values": [0.73046875, 0.46972656, 2.84375, 5.2265625, 3.3242188, 1.9863281, 0.9511719, 0.5019531, 4.4257812, 3.4277344, 0.41308594, 4.3242188, 2.4179688, 3.1757812, 1.0224609, 2.0585938, 2.5859375],
                          "indices": [131900689, 152217691, 441495248, 1640781426, 1851149807, 2263326288, 2502307765, 2641553256, 2684780967, 2966813704, 3162218338, 3283104238, 3488055477, 3530642888, 3888762515, 4152503047, 4177290673]
                      },
                      "metadata": {
                          "chunk_text": "AAPL may consider healthcare integrations in Q4 to compete with tech rivals entering the consumer wellness space.",
                          "category": "technology",
                          "quarter": "Q4"
                      }
                  },
              ]
          }'
      ```
    </CodeGroup>
  </Tab>
</Tabs>

## Upsert in batches

<Tip>
  To control costs when ingesting large datasets (10,000,000+ records), use [import](/guides/index-data/import-data) instead of upsert.
</Tip>

Send upserts in batches to help increase throughput.

* When upserting records with vectors, a batch should be as large as possible (up to 1000 records) without exceeding the [max request size of 2 MB](#upsert-limits).

  To understand the number of records you can fit into one batch based on the vector dimensions and metadata size, see the following table:

  | Dimension | Metadata (bytes) | Max batch size |
  | :-------- | :--------------- | :------------- |
  | 386       | 0                | 1000           |
  | 768       | 500              | 559            |
  | 1536      | 2000             | 245            |

* When upserting records with text, a batch can contain up to 96 records. This limit comes from the [hosted embedding models](/guides/index-data/create-an-index#embedding-models) used during integrated embedding rather than the batch size limit for upserting raw vectors.

<CodeGroup>
  ```Python Python theme={null}
  import random
  import itertools
  from pinecone.grpc import PineconeGRPC as Pinecone

  pc = Pinecone(api_key="YOUR_API_KEY")

  # To get the unique host for an index, 
  # see https://docs.pinecone.io/guides/manage-data/target-an-index
  index = pc.Index(host="INDEX_HOST")

  def chunks(iterable, batch_size=200):
      """A helper function to break an iterable into chunks of size batch_size."""
      it = iter(iterable)
      chunk = tuple(itertools.islice(it, batch_size))
      while chunk:
          yield chunk
          chunk = tuple(itertools.islice(it, batch_size))

  vector_dim = 128
  vector_count = 10000

  # Example generator that generates many (id, vector) pairs
  example_data_generator = map(lambda i: (f'id-{i}', [random.random() for _ in range(vector_dim)]), range(vector_count))

  # Upsert data with 200 vectors per upsert request
  for ids_vectors_chunk in chunks(example_data_generator, batch_size=200):
      index.upsert(vectors=ids_vectors_chunk) 
  ```

  ```JavaScript JavaScript theme={null}
  import { Pinecone } from "@pinecone-database/pinecone";

  const RECORD_COUNT = 10000;
  const RECORD_DIMENSION = 128;

  const client = new Pinecone({ apiKey: "YOUR_API_KEY" });
  const index = client.index("docs-example");

  // A helper function that breaks an array into chunks of size batchSize
  const chunks = (array, batchSize = 200) => {
    const chunks = [];

    for (let i = 0; i < array.length; i += batchSize) {
      chunks.push(array.slice(i, i + batchSize));
    }

    return chunks;
  };

  // Example data generation function, creates many (id, vector) pairs
  const generateExampleData = () =>
    Array.from({ length: RECORD_COUNT }, (_, i) => {
      return {
        id: `id-${i}`,
        values: Array.from({ length: RECORD_DIMENSION }, (_, i) => Math.random()),
      };
    });

  const exampleRecordData = generateExampleData();
  const recordChunks = chunks(exampleRecordData);

  // Upsert data with 200 records per upsert request
  for (const chunk of recordChunks) {
    await index.upsert(chunk)
  }
  ```

  ```java Java theme={null}
  import io.pinecone.clients.Index;
  import io.pinecone.configs.PineconeConfig;
  import io.pinecone.configs.PineconeConnection;
  import io.pinecone.unsigned_indices_model.VectorWithUnsignedIndices;

  import java.util.Arrays;
  import java.util.List;

  public class UpsertBatchExample  {
      public static void main(String[] args) {
          PineconeConfig config = new PineconeConfig("YOUR_API_KEY");
          // To get the unique host for an index, 
          // see https://docs.pinecone.io/guides/manage-data/target-an-index
          config.setHost("INDEX_HOST");
          PineconeConnection connection = new PineconeConnection(config);
          Index index = new Index(connection, "INDEX_NAME");

          ArrayList<VectorWithUnsignedIndices> vectors = generateVectors();
          ArrayList<ArrayList<VectorWithUnsignedIndices>> chunks = chunks(vectors, BATCH_SIZE);

          for (ArrayList<VectorWithUnsignedIndices> chunk : chunks) {
              index.upsert(chunk, "example-namespace");
          }
      }

      // A helper function that breaks an ArrayList into chunks of batchSize
      private static ArrayList<ArrayList<VectorWithUnsignedIndices>> chunks(ArrayList<VectorWithUnsignedIndices> vectors, int batchSize) {
          ArrayList<ArrayList<VectorWithUnsignedIndices>> chunks = new ArrayList<>();
          ArrayList<VectorWithUnsignedIndices> chunk = new ArrayList<>();

          for (int i = 0; i < vectors.size(); i++) {
              if (i % BATCH_SIZE == 0 && i != 0) {
                  chunks.add(chunk);
                  chunk = new ArrayList<>();
              }

              chunk.add(vectors.get(i));
          }

          return chunks;
      }

      // Example data generation function, creates many (id, vector) pairs
      private static ArrayList<VectorWithUnsignedIndices> generateVectors() {
          Random random = new Random();
          ArrayList<VectorWithUnsignedIndices> vectors = new ArrayList<>();


          for (int i = 0; i <= RECORD_COUNT; i++) {
              String id = "id-" + i;
              ArrayList<Float> values = new ArrayList<>();

              for (int j = 0; j < RECORD_DIMENSION; j++) {
                  values.add(random.nextFloat());
              }

              VectorWithUnsignedIndices vector = new VectorWithUnsignedIndices();
              vector.setId(id);
              vector.setValues(values);
              vectors.add(vector);
          }

          return vectors;
      }
  }
  ```

  ```go Go theme={null}
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

      // To get the unique host for an index, 
      // see https://docs.pinecone.io/guides/manage-data/target-an-index
      idxConnection, err := pc.Index(pinecone.NewIndexConnParams{Host: "INDEX_HOST"})
      if err != nil {
          log.Fatalf("Failed to create IndexConnection for Host: %v", err)
  	  }

      // Generate a large number of vectors to upsert
      vectorCount := 10000
      vectorDim := idx.Dimension

      vectors := make([]*pinecone.Vector, vectorCount)
      for i := 0; i < int(vectorCount); i++ {
          randomFloats := make([]float32, vectorDim)

          for i := int32(0); i < vectorDim; i++ {
              randomFloats[i] = rand.Float32()
          }

          vectors[i] = &pinecone.Vector{
              Id:     fmt.Sprintf("doc1#-vector%d", i),
              Values: randomFloats,
          }
      }

      // Break the vectors into batches of 200
      var batches [][]*pinecone.Vector
      batchSize := 200

      for len(vectors) > 0 {
          batchEnd := batchSize
          if len(vectors) < batchSize {
              batchEnd = len(vectors)
          }
          batches = append(batches, vectors[:batchEnd])
          vectors = vectors[batchEnd:]
      }

      // Upsert batches
      for i, batch := range batches {
          upsertResp, err := idxConn.UpsertVectors(context.Background(), batch)
          if err != nil {
              panic(err)
          }

          fmt.Printf("upserted %d vectors (%v of %v batches)\n", upsertResp, i+1, len(batches))
      }
  }
  ```
</CodeGroup>

## Upsert in parallel

<Tip>
  Python SDK v6.0.0 and later provide `async` methods for use with [asyncio](https://docs.python.org/3/library/asyncio.html). Asyncio support makes it possible to use Pinecone with modern async web frameworks such as FastAPI, Quart, and Sanic. For more details, see [Asyncio support](/reference/python-sdk#asyncio-support).
</Tip>

Send multiple upserts in parallel to help increase throughput. Vector operations block until the response has been received. However, they can be made asynchronously as follows:

<CodeGroup>
  ```Python Python theme={null}
  # This example uses `async_req=True` and multiple threads.
  # For a single-threaded approach compatible with modern async web frameworks, 
  # see https://docs.pinecone.io/reference/python-sdk#asyncio-support
  import random
  import itertools
  from pinecone import Pinecone

  # Initialize the client with pool_threads=30. This limits simultaneous requests to 30.
  pc = Pinecone(api_key="YOUR_API_KEY", pool_threads=30)

  # To get the unique host for an index, 
  # see https://docs.pinecone.io/guides/manage-data/target-an-index
  index = pc.Index(host="INDEX_HOST")

  def chunks(iterable, batch_size=200):
      """A helper function to break an iterable into chunks of size batch_size."""
      it = iter(iterable)
      chunk = tuple(itertools.islice(it, batch_size))
      while chunk:
          yield chunk
          chunk = tuple(itertools.islice(it, batch_size))

  vector_dim = 128
  vector_count = 10000

  example_data_generator = map(lambda i: (f'id-{i}', [random.random() for _ in range(vector_dim)]), range(vector_count))

  # Upsert data with 200 vectors per upsert request asynchronously
  # - Pass async_req=True to index.upsert()
  with pc.Index(host="INDEX_HOST", pool_threads=30) as index:
      # Send requests in parallel
      async_results = [
          index.upsert(vectors=ids_vectors_chunk, async_req=True)
          for ids_vectors_chunk in chunks(example_data_generator, batch_size=200)
      ]
      # Wait for and retrieve responses (this raises in case of error)
      [async_result.get() for async_result in async_results]
  ```

  ```JavaScript JavaScript theme={null}
  import { Pinecone } from "@pinecone-database/pinecone";

  const RECORD_COUNT = 10000;
  const RECORD_DIMENSION = 128;

  const client = new Pinecone({ apiKey: "YOUR_API_KEY" });

  // To get the unique host for an index, 
  // see https://docs.pinecone.io/guides/manage-data/target-an-index
  const index = pc.index("INDEX_NAME", "INDEX_HOST")

  // A helper function that breaks an array into chunks of size batchSize
  const chunks = (array, batchSize = 200) => {
    const chunks = [];

    for (let i = 0; i < array.length; i += batchSize) {
      chunks.push(array.slice(i, i + batchSize));
    }

    return chunks;
  };

  // Example data generation function, creates many (id, vector) pairs
  const generateExampleData = () =>
    Array.from({ length: RECORD_COUNT }, (_, i) => {
      return {
        id: `id-${i}`,
        values: Array.from({ length: RECORD_DIMENSION }, (_, i) => Math.random()),
      };
    });

  const exampleRecordData = generateExampleData();
  const recordChunks = chunks(exampleRecordData);

  // Upsert data with 200 records per request asynchronously using Promise.all()
  await Promise.all(recordChunks.map((chunk) => index.upsert(chunk)));
  ```

  ```java Java theme={null}
  import com.google.protobuf.Struct;
  import com.google.protobuf.Value;
  import io.pinecone.clients.Index;
  import io.pinecone.configs.PineconeConfig;
  import io.pinecone.configs.PineconeConnection;
  import io.pinecone.proto.UpsertResponse;
  import io.pinecone.unsigned_indices_model.VectorWithUnsignedIndices;

  import java.util.ArrayList;
  import java.util.Arrays;
  import java.util.concurrent.ExecutorService;
  import java.util.concurrent.Executors;
  import java.util.List;

  public class UpsertExample {
      public static void main(String[] args) {
          PineconeConfig config = new PineconeConfig("YOUR_API_KEY");
          // To get the unique host for an index, 
          // see https://docs.pinecone.io/guides/manage-data/target-an-index
          config.setHost("INDEX_HOST");
          PineconeConnection connection = new PineconeConnection(config);
          Index index = new Index(connection, "INDEX_NAME");

          // Run 5 threads concurrently and upsert data into pinecone
          int numberOfThreads = 5;

          // Create a fixed thread pool
          ExecutorService executor = Executors.newFixedThreadPool(numberOfThreads);

          // Submit tasks to the executor
          for (int i = 0; i < numberOfThreads; i++) {
              // upsertData
              int batchNumber = i+1;
              executor.submit(() -> upsertData(index, batchNumber));
          }

          // Shutdown the executor
          executor.shutdown();
      }

      private static void upsertData(Index index, int batchNumber) {
          // Vector ids to be upserted
          String prefix = "v" + batchNumber;
          List<String> upsertIds = Arrays.asList(prefix + "_1", prefix + "_2", prefix + "_3");

          // List of values to be upserted
          List<List<Float>> values = new ArrayList<>();
          values.add(Arrays.asList(1.0f, 2.0f, 3.0f));
          values.add(Arrays.asList(4.0f, 5.0f, 6.0f));
          values.add(Arrays.asList(7.0f, 8.0f, 9.0f));

          // List of sparse indices to be upserted
          List<List<Long>> sparseIndices = new ArrayList<>();
          sparseIndices.add(Arrays.asList(1L, 2L, 3L));
          sparseIndices.add(Arrays.asList(4L, 5L, 6L));
          sparseIndices.add(Arrays.asList(7L, 8L, 9L));

          // List of sparse values to be upserted
          List<List<Float>> sparseValues = new ArrayList<>();
          sparseValues.add(Arrays.asList(1000f, 2000f, 3000f));
          sparseValues.add(Arrays.asList(4000f, 5000f, 6000f));
          sparseValues.add(Arrays.asList(7000f, 8000f, 9000f));

          List<VectorWithUnsignedIndices> vectors = new ArrayList<>(3);

          // Metadata to be upserted
          Struct metadataStruct1 = Struct.newBuilder()
                  .putFields("genre", Value.newBuilder().setStringValue("action").build())
                  .putFields("year", Value.newBuilder().setNumberValue(2019).build())
                  .build();

          Struct metadataStruct2 = Struct.newBuilder()
                  .putFields("genre", Value.newBuilder().setStringValue("thriller").build())
                  .putFields("year", Value.newBuilder().setNumberValue(2020).build())
                  .build();

          Struct metadataStruct3 = Struct.newBuilder()
                  .putFields("genre", Value.newBuilder().setStringValue("comedy").build())
                  .putFields("year", Value.newBuilder().setNumberValue(2021).build())
                  .build();
          List<Struct> metadataStructList = Arrays.asList(metadataStruct1, metadataStruct2, metadataStruct3);

          // Upsert data
          for (int i = 0; i < metadataStructList.size(); i++) {
              vectors.add(buildUpsertVectorWithUnsignedIndices(upsertIds.get(i), values.get(i), sparseIndices.get(i), sparseValues.get(i), metadataStructList.get(i)));
          }

          UpsertResponse upsertResponse = index.upsert(vectors, "example-namespace");
      }
  }
  ```

  ```go Go theme={null}
  package main

  import (
      "context"
      "fmt"
      "log"
      "math/rand"
      "sync"
      
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

      // To get the unique host for an index, 
      // see https://docs.pinecone.io/guides/manage-data/target-an-index
      idxConn, err := pc.Index(pinecone.NewIndexConnParams{Host: "INDEX_HOST"})
      if err != nil {
          log.Fatalf("Failed to create IndexConnection for Host: %v", err)
  	  }

      // Generate a large number of vectors to upsert
      vectorCount := 10000
      vectorDim := idx.Dimension

      vectors := make([]*pinecone.Vector, vectorCount)
      for i := 0; i < int(vectorCount); i++ {
          randomFloats := make([]float32, vectorDim)

          for i := int32(0); i < vectorDim; i++ {
              randomFloats[i] = rand.Float32()
          }

          vectors[i] = &pinecone.Vector{
              Id:     fmt.Sprintf("doc1#-vector%d", i),
              Values: randomFloats,
          }
      }

      // Break the vectors into batches of 200
      var batches [][]*pinecone.Vector
      batchSize := 200

      for len(vectors) > 0 {
          batchEnd := batchSize
          if len(vectors) < batchSize {
              batchEnd = len(vectors)
          }
          batches = append(batches, vectors[:batchEnd])
          vectors = vectors[batchEnd:]
      }

      // Use channels to manage concurrency and possible errors
      maxConcurrency := 10
      errChan := make(chan error, len(batches))
      semaphore := make(chan struct{}, maxConcurrency)
      var wg sync.WaitGroup

      for i, batch := range batches {
          wg.Add(1)
          semaphore <- struct{}{}

          go func(batch []*pinecone.Vector, i int) {
              defer wg.Done()
              defer func() { <-semaphore }()

              upsertResp, err := idxConn.UpsertVectors(context.Background(), batch)
              if err != nil {
                  errChan <- fmt.Errorf("batch %d failed: %v", i, err)
                  return
              }

              fmt.Printf("upserted %d vectors (%v of %v batches)\n", upsertResp, i+1, len(batches))
          }(batch, i)
      }

      wg.Wait()
      close(errChan)

      for err := range errChan {
          if err != nil {
              fmt.Printf("Error while upserting batch: %v\n", err)
          }
      }
  }
  ```
</CodeGroup>

### Python SDK with gRPC

Using the Python SDK with gRPC extras can provide higher upsert speeds. Through multiplexing, gRPC is able to handle large amounts of requests in parallel without slowing down the rest of the system (HoL blocking), unlike REST. Moreover, you can pass various retry strategies to the gRPC SDK, including [exponential backoff](/guides/production/error-handling#implement-retry-logic).

To install the gRPC version of the SDK:

```Shell Shell theme={null}
pip install "pinecone[grpc]"
```

To use the gRPC SDK, import the `pinecone.grpc` subpackage and target an index as usual:

```Python Python theme={null}
from pinecone.grpc import PineconeGRPC as Pinecone

# This is gRPC client aliased as "Pinecone"
pc = Pinecone(api_key='YOUR_API_KEY')  

# To get the unique host for an index, 
# see https://docs.pinecone.io/guides/manage-data/target-an-index
index = pc.Index(host="INDEX_HOST")
```

To launch multiple read and write requests in parallel, pass `async_req` to the `upsert` operation:

```Python Python theme={null}
def chunker(seq, batch_size):
  return (seq[pos:pos + batch_size] for pos in range(0, len(seq), batch_size))

async_results = [
  index.upsert(vectors=chunk, async_req=True)
  for chunk in chunker(data, batch_size=200)
]

# Wait for and retrieve responses (in case of error)
[async_result.result() for async_result in async_results]
```

<Note>
  It is possible to get write-throttled faster when upserting using the gRPC SDK. If you see this often, [implement retry logic with exponential backoff](/guides/production/error-handling#implement-retry-logic) while upserting.

  The syntax for upsert, query, fetch, and delete with the gRPC SDK remain the same as the standard SDK.
</Note>

## Upsert limits

| Metric                                                             | Limit                                                         |
| :----------------------------------------------------------------- | :------------------------------------------------------------ |
| Max [batch size](/guides/index-data/upsert-data#upsert-in-batches) | 2 MB or 1000 records with vectors <br /> 96 records with text |
| Max metadata size per record                                       | 40 KB                                                         |
| Max length for a record ID                                         | 512 characters                                                |
| Max dimensionality for dense vectors                               | 20,000                                                        |
| Max non-zero values for sparse vectors                             | 2048                                                          |
| Max dimensionality for sparse vectors                              | 4.2 billion                                                   |
