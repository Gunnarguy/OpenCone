# Quickstart

> Get started with Pinecone manually, with AI assistance, or with no-code tools.

<Tabs>
  <Tab title="Manual">
    Use a Pinecone SDK to create an index, upsert data, and perform semantic search.

    <Tip>
      To get started in your browser, use the [Quickstart colab notebook](https://colab.research.google.com/github/pinecone-io/examples/blob/master/docs/pinecone-quickstart.ipynb).
    </Tip>

    ## 1. Sign up

    If you're new to Pinecone, sign up at [app.pinecone.io](https://app.pinecone.io) and choose a free plan:

    * [Starter plan](https://pinecone.io/pricing/): Free access to most features, but you're limited to one cloud region and need to stay under Starter plan [limits](/reference/api/database-limits).

    * [Standard plan trial](/guides/organizations/manage-billing/standard-trial): 21 days and \$300 in credits with access to Standard plan [features](https://www.pinecone.io/pricing/) and [higher limits](/reference/api/database-limits) that let you test Pinecone at scale.

    <Note>
      You cannot switch from the Starter plan to the Standard plan trial, so be sure to select the right plan for your needs.
    </Note>

    After signing up, you'll receive an API key in the console. Save this key. You'll need it to authenticate your requests to Pinecone.

    ## 2. Install an SDK

    [Pinecone SDKs](/reference/pinecone-sdks) provide convenient programmatic access to the [Pinecone APIs](/reference/api/introduction).

    Install the SDK for your preferred language:

    <CodeGroup>
      ```shell Python theme={null}
      pip install pinecone
      ```

      ```shell JavaScript theme={null}
      npm install @pinecone-database/pinecone
      ```

      ```shell Java theme={null} theme={null} theme={null} theme={null}
      # Maven
      <dependency>
        <groupId>io.pinecone</groupId>
        <artifactId>pinecone-client</artifactId>
        <version>5.0.0</version>
      </dependency>

      # Gradle
      implementation "io.pinecone:pinecone-client:5.0.0"
      ```

      ```shell Go theme={null}
      go get github.com/pinecone-io/go-pinecone/v4/pinecone
      ```

      ```shell C# theme={null}
      # .NET Core CLI
      dotnet add package Pinecone.Client 

      # NuGet CLI
      nuget install Pinecone.Client
      ```
    </CodeGroup>

    ## 3. Create an index

    In Pinecone, there are two types of indexes for storing vector data: [Dense indexes](/guides/index-data/indexing-overview#dense-indexes) store <Tooltip tip="Each number in a dense vector is a point in a multidimensional space. Vectors that are closer together in that space are semantically similar.">dense vectors</Tooltip> for semantic search, and [sparse indexes](/guides/index-data/indexing-overview#sparse-indexes) store <Tooltip tip="A sparse vector has a very large number of dimensions, where only a small proportion of values are non-zero. The dimensions represent words from a dictionary, and the values represent the importance of these words in the document.">sparse vectors</Tooltip> for lexical/keyword search.

    For this quickstart, [create a dense index](/guides/index-data/create-an-index#create-a-dense-index) that is integrated with an [embedding model hosted by Pinecone](/guides/index-data/create-an-index#embedding-models). With integrated models, you upsert and search with text and have Pinecone generate vectors automatically.

    <Note>
      If you prefer to use external embedding models, see [Bring your own vectors](/guides/index-data/indexing-overview#bring-your-own-vectors).
    </Note>

    <CodeGroup>
      ```python Python theme={null}
      # Import the Pinecone library
      from pinecone import Pinecone

      # Initialize a Pinecone client with your API key
      pc = Pinecone(api_key="{{YOUR_API_KEY}}")

      # Create a dense index with integrated embedding
      index_name = "quickstart-py"
      if not pc.has_index(index_name):
          pc.create_index_for_model(
              name=index_name,
              cloud="aws",
              region="us-east-1",
              embed={
                  "model":"llama-text-embed-v2",
                  "field_map":{"text": "chunk_text"}
              }
          )
      ```

      ```javascript JavaScript theme={null}
      // Import the Pinecone library
      import { Pinecone } from '@pinecone-database/pinecone'

      // Initialize a Pinecone client with your API key
      const pc = new Pinecone({ apiKey: '{{YOUR_API_KEY}}' });

      // Create a dense index with integrated embedding
      const indexName = 'quickstart-js';
      await pc.createIndexForModel({
        name: indexName,
        cloud: 'aws',
        region: 'us-east-1',
        embed: {
          model: 'llama-text-embed-v2',
          fieldMap: { text: 'chunk_text' },
        },
        waitUntilReady: true,
      });
      ```

      ```java Java theme={null}
      import io.pinecone.clients.Index;
      import io.pinecone.clients.Pinecone;
      import org.openapitools.db_control.client.ApiException;
      import org.openapitools.db_control.client.model.CreateIndexForModelRequest;
      import org.openapitools.db_control.client.model.CreateIndexForModelRequestEmbed;
      import org.openapitools.db_control.client.model.DeletionProtection;
      import org.openapitools.db_control.client.model.IndexModel;
      import org.openapitools.db_data.client.model.SearchRecordsRequestQuery;
      import org.openapitools.db_data.client.model.SearchRecordsResponse;
      import io.pinecone.proto.DescribeIndexStatsResponse;

      import java.util.*;

      public class Quickstart {
          public static void main(String[] args) throws ApiException {
              Pinecone pc = new Pinecone.Builder("{{YOUR_API_KEY}}").build();
              String indexName = "quickstart-java";
              String region = "us-east-1";
              HashMap<String, String> fieldMap = new HashMap<>();
              fieldMap.put("text", "chunk_text");
              CreateIndexForModelRequestEmbed embed = new CreateIndexForModelRequestEmbed()
                      .model("llama-text-embed-v2")
                      .fieldMap(fieldMap);
              IndexModel index = pc.createIndexForModel(
                      indexName,
                      CreateIndexForModelRequest.CloudEnum.AWS,
                      region,
                      embed,
                      DeletionProtection.DISABLED,
                      null
              );
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

      func main() {
          ctx := context.Background()

          pc, err := pinecone.NewClient(pinecone.NewClientParams{
              ApiKey: "{{YOUR_API_KEY}}",
          })
          if err != nil {
              log.Fatalf("Failed to create Client: %v", err)
          }

        	indexName := "quickstart-go"
          index, err := pc.CreateIndexForModel(ctx, &pinecone.CreateIndexForModelRequest{
              Name:   indexName,
              Cloud:  pinecone.Aws,
              Region: "us-east-1",
              Embed: pinecone.CreateIndexForModelEmbed{
                  Model:    "llama-text-embed-v2",
                  FieldMap: map[string]interface{}{"text": "chunk_text"},
              },
          })
          if err != nil {
              log.Fatalf("Failed to create serverless index: %v", err)
          } else {
              fmt.Printf("Successfully created serverless index: %v", idx.Name)
          }
      }

      // Function to prettify responses
      func prettifyStruct(obj interface{}) string {
        	bytes, _ := json.MarshalIndent(obj, "", "  ")
          return string(bytes)
      }
      ```

      ```csharp C# theme={null}
      using Pinecone;

      var pinecone = new PineconeClient("{{YOUR_API_KEY}}");

      var indexName = "quickstart-dotnet";

      var createIndexRequest = await pinecone.CreateIndexForModelAsync(
          new CreateIndexForModelRequest
          {
              Name = indexName,
              Cloud = CreateIndexForModelRequestCloud.Aws,
              Region = "us-east-1",
              Embed = new CreateIndexForModelRequestEmbed
              {
                  Model = "llama-text-embed-v2",
                  FieldMap = new Dictionary<string, object?>() 
                  { 
                      { "text", "chunk_text" } 
                  }
              }
      );
      ```
    </CodeGroup>

    ## 4. Upsert text

    Prepare a sample dataset of factual statements from different domains like history, physics, technology, and music. [Model the data](/guides/index-data/data-modeling) as as records with an ID, text, and category.

    <CodeGroup>
      ```python Python [expandable] theme={null}
      records = [
          { "_id": "rec1", "chunk_text": "The Eiffel Tower was completed in 1889 and stands in Paris, France.", "category": "history" },
          { "_id": "rec2", "chunk_text": "Photosynthesis allows plants to convert sunlight into energy.", "category": "science" },
          { "_id": "rec3", "chunk_text": "Albert Einstein developed the theory of relativity.", "category": "science" },
          { "_id": "rec4", "chunk_text": "The mitochondrion is often called the powerhouse of the cell.", "category": "biology" },
          { "_id": "rec5", "chunk_text": "Shakespeare wrote many famous plays, including Hamlet and Macbeth.", "category": "literature" },
          { "_id": "rec6", "chunk_text": "Water boils at 100°C under standard atmospheric pressure.", "category": "physics" },
          { "_id": "rec7", "chunk_text": "The Great Wall of China was built to protect against invasions.", "category": "history" },
          { "_id": "rec8", "chunk_text": "Honey never spoils due to its low moisture content and acidity.", "category": "food science" },
          { "_id": "rec9", "chunk_text": "The speed of light in a vacuum is approximately 299,792 km/s.", "category": "physics" },
          { "_id": "rec10", "chunk_text": "Newton's laws describe the motion of objects.", "category": "physics" },
          { "_id": "rec11", "chunk_text": "The human brain has approximately 86 billion neurons.", "category": "biology" },
          { "_id": "rec12", "chunk_text": "The Amazon Rainforest is one of the most biodiverse places on Earth.", "category": "geography" },
          { "_id": "rec13", "chunk_text": "Black holes have gravitational fields so strong that not even light can escape.", "category": "astronomy" },
          { "_id": "rec14", "chunk_text": "The periodic table organizes elements based on their atomic number.", "category": "chemistry" },
          { "_id": "rec15", "chunk_text": "Leonardo da Vinci painted the Mona Lisa.", "category": "art" },
          { "_id": "rec16", "chunk_text": "The internet revolutionized communication and information sharing.", "category": "technology" },
          { "_id": "rec17", "chunk_text": "The Pyramids of Giza are among the Seven Wonders of the Ancient World.", "category": "history" },
          { "_id": "rec18", "chunk_text": "Dogs have an incredible sense of smell, much stronger than humans.", "category": "biology" },
          { "_id": "rec19", "chunk_text": "The Pacific Ocean is the largest and deepest ocean on Earth.", "category": "geography" },
          { "_id": "rec20", "chunk_text": "Chess is a strategic game that originated in India.", "category": "games" },
          { "_id": "rec21", "chunk_text": "The Statue of Liberty was a gift from France to the United States.", "category": "history" },
          { "_id": "rec22", "chunk_text": "Coffee contains caffeine, a natural stimulant.", "category": "food science" },
          { "_id": "rec23", "chunk_text": "Thomas Edison invented the practical electric light bulb.", "category": "inventions" },
          { "_id": "rec24", "chunk_text": "The moon influences ocean tides due to gravitational pull.", "category": "astronomy" },
          { "_id": "rec25", "chunk_text": "DNA carries genetic information for all living organisms.", "category": "biology" },
          { "_id": "rec26", "chunk_text": "Rome was once the center of a vast empire.", "category": "history" },
          { "_id": "rec27", "chunk_text": "The Wright brothers pioneered human flight in 1903.", "category": "inventions" },
          { "_id": "rec28", "chunk_text": "Bananas are a good source of potassium.", "category": "nutrition" },
          { "_id": "rec29", "chunk_text": "The stock market fluctuates based on supply and demand.", "category": "economics" },
          { "_id": "rec30", "chunk_text": "A compass needle points toward the magnetic north pole.", "category": "navigation" },
          { "_id": "rec31", "chunk_text": "The universe is expanding, according to the Big Bang theory.", "category": "astronomy" },
          { "_id": "rec32", "chunk_text": "Elephants have excellent memory and strong social bonds.", "category": "biology" },
          { "_id": "rec33", "chunk_text": "The violin is a string instrument commonly used in orchestras.", "category": "music" },
          { "_id": "rec34", "chunk_text": "The heart pumps blood throughout the human body.", "category": "biology" },
          { "_id": "rec35", "chunk_text": "Ice cream melts when exposed to heat.", "category": "food science" },
          { "_id": "rec36", "chunk_text": "Solar panels convert sunlight into electricity.", "category": "technology" },
          { "_id": "rec37", "chunk_text": "The French Revolution began in 1789.", "category": "history" },
          { "_id": "rec38", "chunk_text": "The Taj Mahal is a mausoleum built by Emperor Shah Jahan.", "category": "history" },
          { "_id": "rec39", "chunk_text": "Rainbows are caused by light refracting through water droplets.", "category": "physics" },
          { "_id": "rec40", "chunk_text": "Mount Everest is the tallest mountain in the world.", "category": "geography" },
          { "_id": "rec41", "chunk_text": "Octopuses are highly intelligent marine creatures.", "category": "biology" },
          { "_id": "rec42", "chunk_text": "The speed of sound is around 343 meters per second in air.", "category": "physics" },
          { "_id": "rec43", "chunk_text": "Gravity keeps planets in orbit around the sun.", "category": "astronomy" },
          { "_id": "rec44", "chunk_text": "The Mediterranean diet is considered one of the healthiest in the world.", "category": "nutrition" },
          { "_id": "rec45", "chunk_text": "A haiku is a traditional Japanese poem with a 5-7-5 syllable structure.", "category": "literature" },
          { "_id": "rec46", "chunk_text": "The human body is made up of about 60% water.", "category": "biology" },
          { "_id": "rec47", "chunk_text": "The Industrial Revolution transformed manufacturing and transportation.", "category": "history" },
          { "_id": "rec48", "chunk_text": "Vincent van Gogh painted Starry Night.", "category": "art" },
          { "_id": "rec49", "chunk_text": "Airplanes fly due to the principles of lift and aerodynamics.", "category": "physics" },
          { "_id": "rec50", "chunk_text": "Renewable energy sources include wind, solar, and hydroelectric power.", "category": "energy" }
      ]
      ```

      ```javascript JavaScript [expandable] theme={null}
      const records = [
        { "_id": "rec1", "chunk_text": "The Eiffel Tower was completed in 1889 and stands in Paris, France.", "category": "history" },
        { "_id": "rec2", "chunk_text": "Photosynthesis allows plants to convert sunlight into energy.", "category": "science" },
        { "_id": "rec3", "chunk_text": "Albert Einstein developed the theory of relativity.", "category": "science" },
        { "_id": "rec4", "chunk_text": "The mitochondrion is often called the powerhouse of the cell.", "category": "biology" },
        { "_id": "rec5", "chunk_text": "Shakespeare wrote many famous plays, including Hamlet and Macbeth.", "category": "literature" },
        { "_id": "rec6", "chunk_text": "Water boils at 100°C under standard atmospheric pressure.", "category": "physics" },
        { "_id": "rec7", "chunk_text": "The Great Wall of China was built to protect against invasions.", "category": "history" },
        { "_id": "rec8", "chunk_text": "Honey never spoils due to its low moisture content and acidity.", "category": "food science" },
        { "_id": "rec9", "chunk_text": "The speed of light in a vacuum is approximately 299,792 km/s.", "category": "physics" },
        { "_id": "rec10", "chunk_text": "Newton's laws describe the motion of objects.", "category": "physics" },
        { "_id": "rec11", "chunk_text": "The human brain has approximately 86 billion neurons.", "category": "biology" },
        { "_id": "rec12", "chunk_text": "The Amazon Rainforest is one of the most biodiverse places on Earth.", "category": "geography" },
        { "_id": "rec13", "chunk_text": "Black holes have gravitational fields so strong that not even light can escape.", "category": "astronomy" },
        { "_id": "rec14", "chunk_text": "The periodic table organizes elements based on their atomic number.", "category": "chemistry" },
        { "_id": "rec15", "chunk_text": "Leonardo da Vinci painted the Mona Lisa.", "category": "art" },
        { "_id": "rec16", "chunk_text": "The internet revolutionized communication and information sharing.", "category": "technology" },
        { "_id": "rec17", "chunk_text": "The Pyramids of Giza are among the Seven Wonders of the Ancient World.", "category": "history" },
        { "_id": "rec18", "chunk_text": "Dogs have an incredible sense of smell, much stronger than humans.", "category": "biology" },
        { "_id": "rec19", "chunk_text": "The Pacific Ocean is the largest and deepest ocean on Earth.", "category": "geography" },
        { "_id": "rec20", "chunk_text": "Chess is a strategic game that originated in India.", "category": "games" },
        { "_id": "rec21", "chunk_text": "The Statue of Liberty was a gift from France to the United States.", "category": "history" },
        { "_id": "rec22", "chunk_text": "Coffee contains caffeine, a natural stimulant.", "category": "food science" },
        { "_id": "rec23", "chunk_text": "Thomas Edison invented the practical electric light bulb.", "category": "inventions" },
        { "_id": "rec24", "chunk_text": "The moon influences ocean tides due to gravitational pull.", "category": "astronomy" },
        { "_id": "rec25", "chunk_text": "DNA carries genetic information for all living organisms.", "category": "biology" },
        { "_id": "rec26", "chunk_text": "Rome was once the center of a vast empire.", "category": "history" },
        { "_id": "rec27", "chunk_text": "The Wright brothers pioneered human flight in 1903.", "category": "inventions" },
        { "_id": "rec28", "chunk_text": "Bananas are a good source of potassium.", "category": "nutrition" },
        { "_id": "rec29", "chunk_text": "The stock market fluctuates based on supply and demand.", "category": "economics" },
        { "_id": "rec30", "chunk_text": "A compass needle points toward the magnetic north pole.", "category": "navigation" },
        { "_id": "rec31", "chunk_text": "The universe is expanding, according to the Big Bang theory.", "category": "astronomy" },
        { "_id": "rec32", "chunk_text": "Elephants have excellent memory and strong social bonds.", "category": "biology" },
        { "_id": "rec33", "chunk_text": "The violin is a string instrument commonly used in orchestras.", "category": "music" },
        { "_id": "rec34", "chunk_text": "The heart pumps blood throughout the human body.", "category": "biology" },
        { "_id": "rec35", "chunk_text": "Ice cream melts when exposed to heat.", "category": "food science" },
        { "_id": "rec36", "chunk_text": "Solar panels convert sunlight into electricity.", "category": "technology" },
        { "_id": "rec37", "chunk_text": "The French Revolution began in 1789.", "category": "history" },
        { "_id": "rec38", "chunk_text": "The Taj Mahal is a mausoleum built by Emperor Shah Jahan.", "category": "history" },
        { "_id": "rec39", "chunk_text": "Rainbows are caused by light refracting through water droplets.", "category": "physics" },
        { "_id": "rec40", "chunk_text": "Mount Everest is the tallest mountain in the world.", "category": "geography" },
        { "_id": "rec41", "chunk_text": "Octopuses are highly intelligent marine creatures.", "category": "biology" },
        { "_id": "rec42", "chunk_text": "The speed of sound is around 343 meters per second in air.", "category": "physics" },
        { "_id": "rec43", "chunk_text": "Gravity keeps planets in orbit around the sun.", "category": "astronomy" },
        { "_id": "rec44", "chunk_text": "The Mediterranean diet is considered one of the healthiest in the world.", "category": "nutrition" },
        { "_id": "rec45", "chunk_text": "A haiku is a traditional Japanese poem with a 5-7-5 syllable structure.", "category": "literature" },
        { "_id": "rec46", "chunk_text": "The human body is made up of about 60% water.", "category": "biology" },
        { "_id": "rec47", "chunk_text": "The Industrial Revolution transformed manufacturing and transportation.", "category": "history" },
        { "_id": "rec48", "chunk_text": "Vincent van Gogh painted Starry Night.", "category": "art" },
        { "_id": "rec49", "chunk_text": "Airplanes fly due to the principles of lift and aerodynamics.", "category": "physics" },
        { "_id": "rec50", "chunk_text": "Renewable energy sources include wind, solar, and hydroelectric power.", "category": "energy" }
      ];
      ```

      ```java Java [expandable] theme={null}
      // Add to the Quickstart class:
      ArrayList<Map<String, String>> upsertRecords = new ArrayList<>();

      HashMap<String, String> record1 = new HashMap<>();
      record1.put("_id", "rec1");
      record1.put("chunk_text", "The Eiffel Tower was completed in 1889 and stands in Paris, France.");
      record1.put("category", "history");

      HashMap<String, String> record2 = new HashMap<>();
      record2.put("_id", "rec2");
      record2.put("chunk_text", "Photosynthesis allows plants to convert sunlight into energy.");
      record2.put("category", "science");

      HashMap<String, String> record3 = new HashMap<>();
      record3.put("_id", "rec3");
      record3.put("chunk_text", "Albert Einstein developed the theory of relativity.");
      record3.put("category", "science");

      HashMap<String, String> record4 = new HashMap<>();
      record4.put("_id", "rec4");
      record4.put("chunk_text", "The mitochondrion is often called the powerhouse of the cell.");
      record4.put("category", "biology");

      HashMap<String, String> record5 = new HashMap<>();
      record5.put("_id", "rec5");
      record5.put("chunk_text", "Shakespeare wrote many famous plays, including Hamlet and Macbeth.");
      record5.put("category", "literature");

      HashMap<String, String> record6 = new HashMap<>();
      record6.put("_id", "rec6");
      record6.put("chunk_text", "Water boils at 100°C under standard atmospheric pressure.");
      record6.put("category", "physics");

      HashMap<String, String> record7 = new HashMap<>();
      record7.put("_id", "rec7");
      record7.put("chunk_text", "The Great Wall of China was built to protect against invasions.");
      record7.put("category", "history");

      HashMap<String, String> record8 = new HashMap<>();
      record8.put("_id", "rec8");
      record8.put("chunk_text", "Honey never spoils due to its low moisture content and acidity.");
      record8.put("category", "food science");

      HashMap<String, String> record9 = new HashMap<>();
      record9.put("_id", "rec9");
      record9.put("chunk_text", "The speed of light in a vacuum is approximately 299,792 km/s.");
      record9.put("category", "physics");

      HashMap<String, String> record10 = new HashMap<>();
      record10.put("_id", "rec10");
      record10.put("chunk_text", "Newton's laws describe the motion of objects.");
      record10.put("category", "physics");

      HashMap<String, String> record11 = new HashMap<>();
      record11.put("_id", "rec11");
      record11.put("chunk_text", "The human brain has approximately 86 billion neurons.");
      record11.put("category", "biology");

      HashMap<String, String> record12 = new HashMap<>();
      record12.put("_id", "rec12");
      record12.put("chunk_text", "The Amazon Rainforest is one of the most biodiverse places on Earth.");
      record12.put("category", "geography");

      HashMap<String, String> record13 = new HashMap<>();
      record13.put("_id", "rec13");
      record13.put("chunk_text", "Black holes have gravitational fields so strong that not even light can escape.");
      record13.put("category", "astronomy");

      HashMap<String, String> record14 = new HashMap<>();
      record14.put("_id", "rec14");
      record14.put("chunk_text", "The periodic table organizes elements based on their atomic number.");
      record14.put("category", "chemistry");

      HashMap<String, String> record15 = new HashMap<>();
      record15.put("_id", "rec15");
      record15.put("chunk_text", "Leonardo da Vinci painted the Mona Lisa.");
      record15.put("category", "art");

      HashMap<String, String> record16 = new HashMap<>();
      record16.put("_id", "rec16");
      record16.put("chunk_text", "The internet revolutionized communication and information sharing.");
      record16.put("category", "technology");

      HashMap<String, String> record17 = new HashMap<>();
      record17.put("_id", "rec17");
      record17.put("chunk_text", "The Pyramids of Giza are among the Seven Wonders of the Ancient World.");
      record17.put("category", "history");

      HashMap<String, String> record18 = new HashMap<>();
      record18.put("_id", "rec18");
      record18.put("chunk_text", "Dogs have an incredible sense of smell, much stronger than humans.");
      record18.put("category", "biology");

      HashMap<String, String> record19 = new HashMap<>();
      record19.put("_id", "rec19");
      record19.put("chunk_text", "The Pacific Ocean is the largest and deepest ocean on Earth.");
      record19.put("category", "geography");

      HashMap<String, String> record20 = new HashMap<>();
      record20.put("_id", "rec20");
      record20.put("chunk_text", "Chess is a strategic game that originated in India.");
      record20.put("category", "games");

      HashMap<String, String> record21 = new HashMap<>();
      record21.put("_id", "rec21");
      record21.put("chunk_text", "The Statue of Liberty was a gift from France to the United States.");
      record21.put("category", "history");

      HashMap<String, String> record22 = new HashMap<>();
      record22.put("_id", "rec22");
      record22.put("chunk_text", "Coffee contains caffeine, a natural stimulant.");
      record22.put("category", "food science");

      HashMap<String, String> record23 = new HashMap<>();
      record23.put("_id", "rec23");
      record23.put("chunk_text", "Thomas Edison invented the practical electric light bulb.");
      record23.put("category", "inventions");

      HashMap<String, String> record24 = new HashMap<>();
      record24.put("_id", "rec24");
      record24.put("chunk_text", "The moon influences ocean tides due to gravitational pull.");
      record24.put("category", "astronomy");

      HashMap<String, String> record25 = new HashMap<>();
      record25.put("_id", "rec25");
      record25.put("chunk_text", "DNA carries genetic information for all living organisms.");
      record25.put("category", "biology");

      HashMap<String, String> record26 = new HashMap<>();
      record26.put("_id", "rec26");
      record26.put("chunk_text", "Rome was once the center of a vast empire.");
      record26.put("category", "history");

      HashMap<String, String> record27 = new HashMap<>();
      record27.put("_id", "rec27");
      record27.put("chunk_text", "The Wright brothers pioneered human flight in 1903.");
      record27.put("category", "inventions");

      HashMap<String, String> record28 = new HashMap<>();
      record28.put("_id", "rec28");
      record28.put("chunk_text", "Bananas are a good source of potassium.");
      record28.put("category", "nutrition");

      HashMap<String, String> record29 = new HashMap<>();
      record29.put("_id", "rec29");
      record29.put("chunk_text", "The stock market fluctuates based on supply and demand.");
      record29.put("category", "economics");

      HashMap<String, String> record30 = new HashMap<>();
      record30.put("_id", "rec30");
      record30.put("chunk_text", "A compass needle points toward the magnetic north pole.");
      record30.put("category", "navigation");

      HashMap<String, String> record31 = new HashMap<>();
      record31.put("_id", "rec31");
      record31.put("chunk_text", "The universe is expanding, according to the Big Bang theory.");
      record31.put("category", "astronomy");

      HashMap<String, String> record32 = new HashMap<>();
      record32.put("_id", "rec32");
      record32.put("chunk_text", "Elephants have excellent memory and strong social bonds.");
      record32.put("category", "biology");

      HashMap<String, String> record33 = new HashMap<>();
      record33.put("_id", "rec33");
      record33.put("chunk_text", "The violin is a string instrument commonly used in orchestras.");
      record33.put("category", "music");

      HashMap<String, String> record34 = new HashMap<>();
      record34.put("_id", "rec34");
      record34.put("chunk_text", "The heart pumps blood throughout the human body.");
      record34.put("category", "biology");

      HashMap<String, String> record35 = new HashMap<>();
      record35.put("_id", "rec35");
      record35.put("chunk_text", "Ice cream melts when exposed to heat.");
      record35.put("category", "food science");

      HashMap<String, String> record36 = new HashMap<>();
      record36.put("_id", "rec36");
      record36.put("chunk_text", "Solar panels convert sunlight into electricity.");
      record36.put("category", "technology");

      HashMap<String, String> record37 = new HashMap<>();
      record37.put("_id", "rec37");
      record37.put("chunk_text", "The French Revolution began in 1789.");
      record37.put("category", "history");

      HashMap<String, String> record38 = new HashMap<>();
      record38.put("_id", "rec38");
      record38.put("chunk_text", "The Taj Mahal is a mausoleum built by Emperor Shah Jahan.");
      record38.put("category", "history");

      HashMap<String, String> record39 = new HashMap<>();
      record39.put("_id", "rec39");
      record39.put("chunk_text", "Rainbows are caused by light refracting through water droplets.");
      record39.put("category", "physics");

      HashMap<String, String> record40 = new HashMap<>();
      record40.put("_id", "rec40");
      record40.put("chunk_text", "Mount Everest is the tallest mountain in the world.");
      record40.put("category", "geography");

      HashMap<String, String> record41 = new HashMap<>();
      record41.put("_id", "rec41");
      record41.put("chunk_text", "Octopuses are highly intelligent marine creatures.");
      record41.put("category", "biology");

      HashMap<String, String> record42 = new HashMap<>();
      record42.put("_id", "rec42");
      record42.put("chunk_text", "The speed of sound is around 343 meters per second in air.");
      record42.put("category", "physics");

      HashMap<String, String> record43 = new HashMap<>();
      record43.put("_id", "rec43");
      record43.put("chunk_text", "Gravity keeps planets in orbit around the sun.");
      record43.put("category", "astronomy");

      HashMap<String, String> record44 = new HashMap<>();
      record44.put("_id", "rec44");
      record44.put("chunk_text", "The Mediterranean diet is considered one of the healthiest in the world.");
      record44.put("category", "nutrition");

      HashMap<String, String> record45 = new HashMap<>();
      record45.put("_id", "rec45");
      record45.put("chunk_text", "A haiku is a traditional Japanese poem with a 5-7-5 syllable structure.");
      record45.put("category", "literature");

      HashMap<String, String> record46 = new HashMap<>();
      record46.put("_id", "rec46");
      record46.put("chunk_text", "The human body is made up of about 60% water.");
      record46.put("category", "biology");

      HashMap<String, String> record47 = new HashMap<>();
      record47.put("_id", "rec47");
      record47.put("chunk_text", "The Industrial Revolution transformed manufacturing and transportation.");
      record47.put("category", "history");

      HashMap<String, String> record48 = new HashMap<>();
      record48.put("_id", "rec48");
      record48.put("chunk_text", "Vincent van Gogh painted Starry Night.");
      record48.put("category", "art");

      HashMap<String, String> record49 = new HashMap<>();
      record49.put("_id", "rec49");
      record49.put("chunk_text", "Airplanes fly due to the principles of lift and aerodynamics.");
      record49.put("category", "physics");

      HashMap<String, String> record50 = new HashMap<>();
      record50.put("_id", "rec50");
      record50.put("chunk_text", "Renewable energy sources include wind, solar, and hydroelectric power.");
      record50.put("category", "energy");

      upsertRecords.add(record1);
      upsertRecords.add(record2);
      upsertRecords.add(record3);
      upsertRecords.add(record4);
      upsertRecords.add(record5);
      upsertRecords.add(record6);
      upsertRecords.add(record7);
      upsertRecords.add(record8);
      upsertRecords.add(record9);
      upsertRecords.add(record10);
      upsertRecords.add(record11);
      upsertRecords.add(record12);
      upsertRecords.add(record13);
      upsertRecords.add(record14);
      upsertRecords.add(record15);
      upsertRecords.add(record16);
      upsertRecords.add(record17);
      upsertRecords.add(record18);
      upsertRecords.add(record19);
      upsertRecords.add(record20);
      upsertRecords.add(record21);
      upsertRecords.add(record22);
      upsertRecords.add(record23);
      upsertRecords.add(record24);
      upsertRecords.add(record25);
      upsertRecords.add(record26);
      upsertRecords.add(record27);
      upsertRecords.add(record28);
      upsertRecords.add(record29);
      upsertRecords.add(record30);
      upsertRecords.add(record31);
      upsertRecords.add(record32);
      upsertRecords.add(record33);
      upsertRecords.add(record34);
      upsertRecords.add(record35);
      upsertRecords.add(record36);
      upsertRecords.add(record37);
      upsertRecords.add(record38);
      upsertRecords.add(record39);
      upsertRecords.add(record40);
      upsertRecords.add(record41);
      upsertRecords.add(record42);
      upsertRecords.add(record43);
      upsertRecords.add(record44);
      upsertRecords.add(record45);
      upsertRecords.add(record46);
      upsertRecords.add(record47);
      upsertRecords.add(record48);
      upsertRecords.add(record49);
      upsertRecords.add(record50);
      ```

      ```go Go [expandable] theme={null}
      // Add to the main function:
      records := []*pinecone.IntegratedRecord{
          { "_id": "rec1", "chunk_text": "The Eiffel Tower was completed in 1889 and stands in Paris, France.", "category": "history" },
          { "_id": "rec2", "chunk_text": "Photosynthesis allows plants to convert sunlight into energy.", "category": "science" },
          { "_id": "rec3", "chunk_text": "Albert Einstein developed the theory of relativity.", "category": "science" },
          { "_id": "rec4", "chunk_text": "The mitochondrion is often called the powerhouse of the cell.", "category": "biology" },
          { "_id": "rec5", "chunk_text": "Shakespeare wrote many famous plays, including Hamlet and Macbeth.", "category": "literature" },
          { "_id": "rec6", "chunk_text": "Water boils at 100°C under standard atmospheric pressure.", "category": "physics" },
          { "_id": "rec7", "chunk_text": "The Great Wall of China was built to protect against invasions.", "category": "history" },
          { "_id": "rec8", "chunk_text": "Honey never spoils due to its low moisture content and acidity.", "category": "food science" },
          { "_id": "rec9", "chunk_text": "The speed of light in a vacuum is approximately 299,792 km/s.", "category": "physics" },
          { "_id": "rec10", "chunk_text": "Newton's laws describe the motion of objects.", "category": "physics" },
          { "_id": "rec11", "chunk_text": "The human brain has approximately 86 billion neurons.", "category": "biology" },
          { "_id": "rec12", "chunk_text": "The Amazon Rainforest is one of the most biodiverse places on Earth.", "category": "geography" },
          { "_id": "rec13", "chunk_text": "Black holes have gravitational fields so strong that not even light can escape.", "category": "astronomy" },
          { "_id": "rec14", "chunk_text": "The periodic table organizes elements based on their atomic number.", "category": "chemistry" },
          { "_id": "rec15", "chunk_text": "Leonardo da Vinci painted the Mona Lisa.", "category": "art" },
          { "_id": "rec16", "chunk_text": "The internet revolutionized communication and information sharing.", "category": "technology" },
          { "_id": "rec17", "chunk_text": "The Pyramids of Giza are among the Seven Wonders of the Ancient World.", "category": "history" },
          { "_id": "rec18", "chunk_text": "Dogs have an incredible sense of smell, much stronger than humans.", "category": "biology" },
          { "_id": "rec19", "chunk_text": "The Pacific Ocean is the largest and deepest ocean on Earth.", "category": "geography" },
          { "_id": "rec20", "chunk_text": "Chess is a strategic game that originated in India.", "category": "games" },
          { "_id": "rec21", "chunk_text": "The Statue of Liberty was a gift from France to the United States.", "category": "history" },
          { "_id": "rec22", "chunk_text": "Coffee contains caffeine, a natural stimulant.", "category": "food science" },
          { "_id": "rec23", "chunk_text": "Thomas Edison invented the practical electric light bulb.", "category": "inventions" },
          { "_id": "rec24", "chunk_text": "The moon influences ocean tides due to gravitational pull.", "category": "astronomy" },
          { "_id": "rec25", "chunk_text": "DNA carries genetic information for all living organisms.", "category": "biology" },
          { "_id": "rec26", "chunk_text": "Rome was once the center of a vast empire.", "category": "history" },
          { "_id": "rec27", "chunk_text": "The Wright brothers pioneered human flight in 1903.", "category": "inventions" },
          { "_id": "rec28", "chunk_text": "Bananas are a good source of potassium.", "category": "nutrition" },
          { "_id": "rec29", "chunk_text": "The stock market fluctuates based on supply and demand.", "category": "economics" },
          { "_id": "rec30", "chunk_text": "A compass needle points toward the magnetic north pole.", "category": "navigation" },
          { "_id": "rec31", "chunk_text": "The universe is expanding, according to the Big Bang theory.", "category": "astronomy" },
          { "_id": "rec32", "chunk_text": "Elephants have excellent memory and strong social bonds.", "category": "biology" },
          { "_id": "rec33", "chunk_text": "The violin is a string instrument commonly used in orchestras.", "category": "music" },
          { "_id": "rec34", "chunk_text": "The heart pumps blood throughout the human body.", "category": "biology" },
          { "_id": "rec35", "chunk_text": "Ice cream melts when exposed to heat.", "category": "food science" },
          { "_id": "rec36", "chunk_text": "Solar panels convert sunlight into electricity.", "category": "technology" },
          { "_id": "rec37", "chunk_text": "The French Revolution began in 1789.", "category": "history" },
          { "_id": "rec38", "chunk_text": "The Taj Mahal is a mausoleum built by Emperor Shah Jahan.", "category": "history" },
          { "_id": "rec39", "chunk_text": "Rainbows are caused by light refracting through water droplets.", "category": "physics" },
          { "_id": "rec40", "chunk_text": "Mount Everest is the tallest mountain in the world.", "category": "geography" },
          { "_id": "rec41", "chunk_text": "Octopuses are highly intelligent marine creatures.", "category": "biology" },
          { "_id": "rec42", "chunk_text": "The speed of sound is around 343 meters per second in air.", "category": "physics" },
          { "_id": "rec43", "chunk_text": "Gravity keeps planets in orbit around the sun.", "category": "astronomy" },
          { "_id": "rec44", "chunk_text": "The Mediterranean diet is considered one of the healthiest in the world.", "category": "nutrition" },
          { "_id": "rec45", "chunk_text": "A haiku is a traditional Japanese poem with a 5-7-5 syllable structure.", "category": "literature" },
          { "_id": "rec46", "chunk_text": "The human body is made up of about 60% water.", "category": "biology" },
          { "_id": "rec47", "chunk_text": "The Industrial Revolution transformed manufacturing and transportation.", "category": "history" },
          { "_id": "rec48", "chunk_text": "Vincent van Gogh painted Starry Night.", "category": "art" },
          { "_id": "rec49", "chunk_text": "Airplanes fly due to the principles of lift and aerodynamics.", "category": "physics" },
          { "_id": "rec50", "chunk_text": "Renewable energy sources include wind, solar, and hydroelectric power.", "category": "energy" },
      }
      ```

      ```csharp C# [expandable] theme={null}
      var records = new List<UpsertRecord>
      {
          new UpsertRecord
          {
              Id = "rec1",
                AdditionalProperties =
                {
                    ["chunk_text"] = "The Eiffel Tower was completed in 1889 and stands in Paris, France.",
                    ["category"] = "history",
                },
            },
            new UpsertRecord
            {
                Id = "rec2",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Photosynthesis allows plants to convert sunlight into energy.",
                    ["category"] = "science",
                },
            },  
            new UpsertRecord
            {
                Id = "rec3",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Albert Einstein developed the theory of relativity.",
                    ["category"] = "science",
                },
            },
            new UpsertRecord
            {
                Id = "rec4",
                AdditionalProperties =
                {
                    ["chunk_text"] = "The mitochondrion is often called the powerhouse of the cell.",
                    ["category"] = "biology",
                },
            },
            new UpsertRecord
            {
                Id = "rec5",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Shakespeare wrote many famous plays, including Hamlet and Macbeth.",
                    ["category"] = "literature",
                },
            },
            new UpsertRecord
            {
                Id = "rec6",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Water boils at 100°C under standard atmospheric pressure.",
                    ["category"] = "physics",
                },
            },
            new UpsertRecord
            {
                Id = "rec7",
                AdditionalProperties =
                {
                    ["chunk_text"] = "The Great Wall of China was built to protect against invasions.",
                    ["category"] = "history",
                },
            },
            new UpsertRecord
            {
                Id = "rec8",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Honey never spoils due to its low moisture content and acidity.",
                    ["category"] = "food science",
                },
            },
            new UpsertRecord
            {
                Id = "rec9",
                AdditionalProperties =
                {
                    ["chunk_text"] = "The speed of light in a vacuum is approximately 299,792 km/s.",
                    ["category"] = "physics",
                },
            },
            new UpsertRecord
            {
                Id = "rec10",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Newton's laws describe the motion of objects.",
                    ["category"] = "physics",
                },
            },
            new UpsertRecord
            {
                Id = "rec11",
                AdditionalProperties =
                {
                    ["chunk_text"] = "The human brain has approximately 86 billion neurons.",
                    ["category"] = "biology",
                },
            },
            new UpsertRecord
            {
                Id = "rec12",
                AdditionalProperties =
                {
                    ["chunk_text"] = "The Amazon Rainforest is one of the most biodiverse places on Earth.",
                    ["category"] = "geography",
                },
            },
            new UpsertRecord
            {
                Id = "rec13",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Black holes have gravitational fields so strong that not even light can escape.",
                    ["category"] = "astronomy",
                },
            },
            new UpsertRecord
            {
                Id = "rec14",
                AdditionalProperties =
                {
                    ["chunk_text"] = "The periodic table organizes elements based on their atomic number.",
                    ["category"] = "chemistry",
                },
            },
            new UpsertRecord
            {
                Id = "rec15",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Leonardo da Vinci painted the Mona Lisa.",
                    ["category"] = "art",
                },
            },
            new UpsertRecord
            {
                Id = "rec16",
                AdditionalProperties =
                {
                    ["chunk_text"] = "The internet revolutionized communication and information sharing.",
                    ["category"] = "technology",
                },
            },
            new UpsertRecord
            {
                Id = "rec17",
                AdditionalProperties =
                {
                    ["chunk_text"] = "The Pyramids of Giza are among the Seven Wonders of the Ancient World.",
                    ["category"] = "history",
                },
            },
            new UpsertRecord
            {
                Id = "rec18",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Dogs have an incredible sense of smell, much stronger than humans.",
                    ["category"] = "biology",
                },
            },
            new UpsertRecord
            {
                Id = "rec19",
                AdditionalProperties =
                {
                    ["chunk_text"] = "The Pacific Ocean is the largest and deepest ocean on Earth.",
                    ["category"] = "geography",
                },
            },
            new UpsertRecord
            {
                Id = "rec20",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Chess is a strategic game that originated in India.",
                    ["category"] = "games",
                },
            },
            new UpsertRecord
            {
                Id = "rec21",
                AdditionalProperties =
                {
                    ["chunk_text"] = "The Statue of Liberty was a gift from France to the United States.",
                    ["category"] = "history",
                },
            },
            new UpsertRecord
            {
                Id = "rec22",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Coffee contains caffeine, a natural stimulant.",
                    ["category"] = "food science",
                },
            },
            new UpsertRecord
            {
                Id = "rec23",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Thomas Edison invented the practical electric light bulb.",
                    ["category"] = "inventions",
                },
            },
            new UpsertRecord
            {
                Id = "rec24",
                AdditionalProperties =
                {
                    ["chunk_text"] = "The moon influences ocean tides due to gravitational pull.",
                    ["category"] = "astronomy",
                },
            },
            new UpsertRecord
            {
                Id = "rec25",
                AdditionalProperties =
                {
                    ["chunk_text"] = "DNA carries genetic information for all living organisms.",
                    ["category"] = "biology",
                },
            },
            new UpsertRecord
            {
                Id = "rec26",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Rome was once the center of a vast empire.",
                    ["category"] = "history",
                },
            },
            new UpsertRecord
            {
                Id = "rec27",
                AdditionalProperties =
                {
                    ["chunk_text"] = "The Wright brothers pioneered human flight in 1903.",
                    ["category"] = "inventions",
                },
            },
            new UpsertRecord
            {
                Id = "rec28",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Bananas are a good source of potassium.",
                    ["category"] = "nutrition",
                },
            },
            new UpsertRecord
            {
                Id = "rec29",
                AdditionalProperties =
                {
                    ["chunk_text"] = "The stock market fluctuates based on supply and demand.",
                    ["category"] = "economics",
                },
            },
            new UpsertRecord
            {
                Id = "rec30",
                AdditionalProperties =
                {
                    ["chunk_text"] = "A compass needle points toward the magnetic north pole.",
                    ["category"] = "navigation",
                },
            },
            new UpsertRecord
            {
                Id = "rec31",
                AdditionalProperties =
                {
                    ["chunk_text"] = "The universe is expanding, according to the Big Bang theory.",
                    ["category"] = "astronomy",
                },
            },
            new UpsertRecord
            {
                Id = "rec32",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Elephants have excellent memory and strong social bonds.",
                    ["category"] = "biology",
                },
            },
            new UpsertRecord
            {
                Id = "rec33",
                AdditionalProperties =
                {
                    ["chunk_text"] = "The violin is a string instrument commonly used in orchestras.",
                    ["category"] = "music",
                },
            },
            new UpsertRecord
            {
                Id = "rec34",
                AdditionalProperties =
                {
                    ["chunk_text"] = "The heart pumps blood throughout the human body.",
                    ["category"] = "biology",
                },
            },
            new UpsertRecord
            {
                Id = "rec35",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Ice cream melts when exposed to heat.",
                    ["category"] = "food science",
                },
            },
            new UpsertRecord
            {
                Id = "rec36",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Solar panels convert sunlight into electricity.",
                    ["category"] = "technology",
                },
            },
            new UpsertRecord
            {
                Id = "rec37",
                AdditionalProperties =
                {
                    ["chunk_text"] = "The French Revolution began in 1789.",
                    ["category"] = "history",
                },
            },
            new UpsertRecord
            {
                Id = "rec38",
                AdditionalProperties =
                {
                    ["chunk_text"] = "The Taj Mahal is a mausoleum built by Emperor Shah Jahan.",
                    ["category"] = "history",
                },
            },
            new UpsertRecord
            {
                Id = "rec39",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Rainbows are caused by light refracting through water droplets.",
                    ["category"] = "physics",
                },
            },
            new UpsertRecord
            {
                Id = "rec40",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Mount Everest is the tallest mountain in the world.",
                    ["category"] = "geography",
                },
            },
            new UpsertRecord
            {
                Id = "rec41",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Octopuses are highly intelligent marine creatures.",
                    ["category"] = "biology",
                },
            },
            new UpsertRecord
            {
                Id = "rec42",
                AdditionalProperties =
                {
                    ["chunk_text"] = "The speed of sound is around 343 meters per second in air.",
                    ["category"] = "physics",
                },
            },
            new UpsertRecord
            {
                Id = "rec43",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Gravity keeps planets in orbit around the sun.",
                    ["category"] = "astronomy",
                },
            },
            new UpsertRecord
            {
                Id = "rec44",
                AdditionalProperties =
                {
                    ["chunk_text"] = "The Mediterranean diet is considered one of the healthiest in the world.",
                    ["category"] = "nutrition",
                },
            },
            new UpsertRecord
            {
                Id = "rec45",
                AdditionalProperties =
                {
                    ["chunk_text"] = "A haiku is a traditional Japanese poem with a 5-7-5 syllable structure.",
                    ["category"] = "literature",
                },
            },
            new UpsertRecord
            {
                Id = "rec46",
                AdditionalProperties =
                {
                    ["chunk_text"] = "The human body is made up of about 60% water.",
                    ["category"] = "biology",
                },
            },
            new UpsertRecord
            {
                Id = "rec47",
                AdditionalProperties =
                {
                    ["chunk_text"] = "The Industrial Revolution transformed manufacturing and transportation.",
                    ["category"] = "history",
                },
            },
            new UpsertRecord
            {
                Id = "rec48",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Vincent van Gogh painted Starry Night.",
                    ["category"] = "art",
                },
            },
            new UpsertRecord
            {
                Id = "rec49",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Airplanes fly due to the principles of lift and aerodynamics.",
                    ["category"] = "physics",
                },
            },
            new UpsertRecord
            {
                Id = "rec50",
                AdditionalProperties =
                {
                    ["chunk_text"] = "Renewable energy sources include wind, solar, and hydroelectric power.",
                    ["category"] = "energy",
                },
            },
      };
      ```
    </CodeGroup>

    [Upsert](/guides/index-data/upsert-data) the sample dataset into a new [namespace](/guides/index-data/indexing-overview#namespaces) in your index.

    Because your index is integrated with an embedding model, you provide the textual statements and Pinecone converts them to dense vectors automatically.

    <CodeGroup>
      ```python Python theme={null}
      # Target the index
      dense_index = pc.Index(index_name)

      # Upsert the records into a namespace
      dense_index.upsert_records("example-namespace", records)
      ```

      ```javascript JavaScript theme={null}
      // Target the index
      const index = pc.index(indexName).namespace("example-namespace");

      // Upsert the records into a namespace
      await index.upsertRecords(records);
      ```

      ```java Java theme={null}
      // Add to the Quickstart class:
      // Target the index
      Index index = new Index(config, connection, "quickstart-java");
      // Upsert the records into a namespace
      index.upsertRecords("example-namespace", upsertRecords);
      ```

      ```go Go theme={null}
      // Add to the main function:
      // Target the index
      idxModel, err := pc.DescribeIndex(ctx, indexName)
      if err != nil {
          log.Fatalf("Failed to describe index \"%v\": %v", indexName, err)
      }

      idxConnection, err := pc.Index(pinecone.NewIndexConnParams{Host: idxModel.Host, Namespace: "example-namespace"})
      if err != nil {
          log.Fatalf("Failed to create IndexConnection for Host: %v: %v", idxModel.Host, err)
      }

      // Upsert the records into a namespace
      err = idxConnection.UpsertRecords(ctx, records)
      if err != nil {
          log.Fatalf("Failed to upsert vectors: %v", err)
      }
      ```

      ```csharp C# theme={null}
      // Upsert the records into a namespace
      await index.UpsertRecordsAsync(
          "example-namespace",
          records
      );
      ```
    </CodeGroup>

    <Tip>
      To control costs when ingesting large datasets (10,000,000+ records), use [import](/guides/index-data/import-data) instead of upsert.
    </Tip>

    Pinecone is eventually consistent, so there can be a slight delay before new or changed records are visible to queries. You can [view index stats](/guides/index-data/check-data-freshness) to check if the current vector count matches the number of vectors you upserted (50):

    <CodeGroup>
      ```python Python theme={null}
      # Wait for the upserted vectors to be indexed
      import time
      time.sleep(10)

      # View stats for the index
      stats = dense_index.describe_index_stats()
      print(stats)
      ```

      ```javascript JavaScript theme={null}
      // Wait for the upserted vectors to be indexed
      await new Promise(resolve => setTimeout(resolve, 10000));

      // View stats for the index
      const stats = await index.describeIndexStats();
      console.log(stats);
      ```

      ```java Java theme={null}
      // Add to the Quickstart class:
      // Wait for upserted vectors to be indexed
      Thread.sleep(5000);

      // View stats for the index
      DescribeIndexStatsResponse indexStatsResponse = index.describeIndexStats();
      System.out.println(indexStatsResponse);
      ```

      ```go Go theme={null}
      // Add to the main function:
      // View stats for the index
      stats, err := idxConnection.DescribeIndexStats(ctx)
      if err != nil {
          log.Fatalf("Failed to describe index \"%v\": %v", indexName, err)
      } else {
          fmt.Printf("%+v", prettifyStruct(*stats))
      }
      ```

      ```csharp C# theme={null}
      var indexStatsResponse = await index.DescribeIndexStatsAsync(new DescribeIndexStatsRequest());

      Console.WriteLine(indexStatsResponse);
      ```
    </CodeGroup>

    The response looks like this:

    <CodeGroup>
      ```python Python theme={null}
      {'dimension': 1024,
       'index_fullness': 0.0,
       'metric': 'cosine',
       'namespaces': {'example-namespace': {'vector_count': 50}},
       'total_vector_count': 50,
       'vector_type': 'dense'}
      ```

      ```javascript JavaScript theme={null}
      {
        namespaces: { 'example-namespace': { recordCount: 50 } },
        dimension: 1024,
        indexFullness: 0,
        totalRecordCount: 50
      }
      ```

      ```java Java theme={null}
      namespaces {
        key: "example-namespace"
        value {
          vector_count: 50
        }
      }
      dimension: 1024
      total_vector_count: 50
      metric: "cosine"
      vector_type: "dense"
      ```

      ```go Go theme={null}
      {
        "dimension": 1024,
        "index_fullness": 0,
        "total_vector_count": 50,
        "namespaces": {
          "example-namespace": {
            "vector_count": 50
          }
        }
      }
      ```

      ```csharp C# theme={null}
      {
        "namespaces": {
          "example-namespace": {
            "vectorCount": 50
          }
        },
        "dimension": 1024,
        "indexFullness": 0,
        "totalVectorCount": 50,
        "metric": "cosine",
        "vectorType": "dense"
      }
      ```
    </CodeGroup>

    ## 5. Semantic search

    [Search the dense index](/guides/search/semantic-search) for ten records that are most semantically similar to the query, "Famous historical structures and monuments".

    Again, because your index is integrated with an embedding model, you provide the query as text and Pinecone converts the text to a dense vector automatically.

    <CodeGroup>
      ```python Python theme={null}
      # Define the query
      query = "Famous historical structures and monuments"

      # Search the dense index
      results = dense_index.search(
          namespace="example-namespace",
          query={
              "top_k": 10,
              "inputs": {
                  'text': query
              }
          }
      )

      # Print the results
      for hit in results['result']['hits']:
              print(f"id: {hit['_id']:<5} | score: {round(hit['_score'], 2):<5} | category: {hit['fields']['category']:<10} | text: {hit['fields']['chunk_text']:<50}")
      ```

      ```javascript JavaScript theme={null}
      // Define the query
      const query = 'Famous historical structures and monuments';

      // Search the dense index
      const results = await index.searchRecords({
        query: {
          topK: 10,
          inputs: { text: query },
        },
      });

      // Print the results
      results.result.hits.forEach(hit => {
        console.log(`id: ${hit.id}, score: ${hit.score.toFixed(2)}, category: ${hit.fields.category}, text: ${hit.fields.chunk_text}`);
      });
      ```

      ```java Java theme={null}
      // Add to the Quickstart class:
      // Define the query
      String query = "Famous historical structures and monuments";
      List<String> fields = new ArrayList<>();
      fields.add("category");
      fields.add("chunk_text");

      // Search the dense index
      SearchRecordsResponse recordsResponse = index.searchRecordsByText(query,  "example-namespace", fields, 10, null, null);

      // Print the results
      System.out.println(recordsResponse);
      ```

      ```go Go theme={null}
      // Add to the main function:
      // Define the query
      query := "Famous historical structures and monuments"

      // Search the dense index
      res, err := idxConnection.SearchRecords(ctx, &pinecone.SearchRecordsRequest{
          Query: pinecone.SearchRecordsQuery{
              TopK: 10,
              Inputs: &map[string]interface{}{
                  "text": query,
              },
          },
      })
      if err != nil {
          log.Fatalf("Failed to search records: %v", err)
      }
      fmt.Printf(prettifyStruct(res))
      ```

      ```csharp C# theme={null}
      // Search the dense index
      var response = await index.SearchRecordsAsync(
          "example-namespace",
          new SearchRecordsRequest
          {
              Query = new SearchRecordsRequestQuery
              {
                  TopK = 10,
                  Inputs = new Dictionary<string, object?> { { "text", "Famous historical structures and monuments" } },
              },
              Fields = ["category", "chunk_text"],
          }
      );

      Console.WriteLine(response);
      ```
    </CodeGroup>

    Notice that most of the results are about historical structures and monuments. However, a few unrelated statements are included as well and are ranked high in the list, for example, a statement about Shakespeare.

    <CodeGroup>
      ```console Python theme={null}
      id: rec17 | score: 0.24  | category: history    | text: The Pyramids of Giza are among the Seven Wonders of the Ancient World.
      id: rec38 | score: 0.19  | category: history    | text: The Taj Mahal is a mausoleum built by Emperor Shah Jahan.
      id: rec5  | score: 0.19  | category: literature | text: Shakespeare wrote many famous plays, including Hamlet and Macbeth.
      id: rec15 | score: 0.11  | category: art        | text: Leonardo da Vinci painted the Mona Lisa.          
      id: rec50 | score: 0.1   | category: energy     | text: Renewable energy sources include wind, solar, and hydroelectric power.
      id: rec26 | score: 0.09  | category: history    | text: Rome was once the center of a vast empire.        
      id: rec47 | score: 0.08  | category: history    | text: The Industrial Revolution transformed manufacturing and transportation.
      id: rec7  | score: 0.07  | category: history    | text: The Great Wall of China was built to protect against invasions.
      id: rec1  | score: 0.07  | category: history    | text: The Eiffel Tower was completed in 1889 and stands in Paris, France.
      id: rec3  | score: 0.07  | category: science    | text: Albert Einstein developed the theory of relativity.
      ```

      ```console JavaScript theme={null}
      id: rec17, score: 0.24, text: The Pyramids of Giza are among the Seven Wonders of the Ancient World., category: history
      id: rec38, score: 0.19, text: The Taj Mahal is a mausoleum built by Emperor Shah Jahan., category: history
      id: rec5, score: 0.19, text: Shakespeare wrote many famous plays, including Hamlet and Macbeth., category: literature
      id: rec15, score: 0.11, text: Leonardo da Vinci painted the Mona Lisa., category: art
      id: rec50, score: 0.10, text: Renewable energy sources include wind, solar, and hydroelectric power., category: energy
      id: rec26, score: 0.09, text: Rome was once the center of a vast empire., category: history
      id: rec47, score: 0.08, text: The Industrial Revolution transformed manufacturing and transportation., category: history
      id: rec7, score: 0.07, text: The Great Wall of China was built to protect against invasions., category: history
      id: rec1, score: 0.07, text: The Eiffel Tower was completed in 1889 and stands in Paris, France., category: history
      id: rec3, score: 0.07, text: Albert Einstein developed the theory of relativity., category: science
      ```

      ```java Java [expandable] theme={null}
      class SearchRecordsResponse {
          result: class SearchRecordsResponseResult {
              hits: [class Hit {
                  id: rec17
                  score: 0.77387625
                  fields: {category=history, chunk_text=The Pyramids of Giza are among the Seven Wonders of the Ancient World.}
                  additionalProperties: null
              }, class Hit {
                  id: rec1
                  score: 0.77372295
                  fields: {category=history, chunk_text=The Eiffel Tower was completed in 1889 and stands in Paris, France.}
                  additionalProperties: null
              }, class Hit {
                  id: rec38
                  score: 0.75988203
                  fields: {category=history, chunk_text=The Taj Mahal is a mausoleum built by Emperor Shah Jahan.}
                  additionalProperties: null
              }, class Hit {
                  id: rec5
                  score: 0.75516135
                  fields: {category=literature, chunk_text=Shakespeare wrote many famous plays, including Hamlet and Macbeth.}
                  additionalProperties: null
              }, class Hit {
                  id: rec26
                  score: 0.7550185
                  fields: {category=history, chunk_text=Rome was once the center of a vast empire.}
                  additionalProperties: null
              }, class Hit {
                  id: rec45
                  score: 0.73588645
                  fields: {category=literature, chunk_text=A haiku is a traditional Japanese poem with a 5-7-5 syllable structure.}
                  additionalProperties: null
              }, class Hit {
                  id: rec4
                  score: 0.730563
                  fields: {category=biology, chunk_text=The mitochondrion is often called the powerhouse of the cell.}
                  additionalProperties: null
              }, class Hit {
                  id: rec7
                  score: 0.73037535
                  fields: {category=history, chunk_text=The Great Wall of China was built to protect against invasions.}
                  additionalProperties: null
              }, class Hit {
                  id: rec32
                  score: 0.72860974
                  fields: {category=biology, chunk_text=Elephants have excellent memory and strong social bonds.}
                  additionalProperties: null
              }, class Hit {
                  id: rec47
                  score: 0.7285921
                  fields: {category=history, chunk_text=The Industrial Revolution transformed manufacturing and transportation.}
                  additionalProperties: null
              }]
              additionalProperties: null
          }
          usage: class SearchUsage {
              readUnits: 6
              embedTotalTokens: 13
              rerankUnits: null
              additionalProperties: null
          }
          additionalProperties: null
      }
      ```

      ```json Go [expandable] theme={null}
      {
        "result": {
          "hits": [
            {
              "_id": "rec17",
              "_score": 0.24442708,
              "fields": {
                "category": "history",
                "chunk_text": "The Pyramids of Giza are among the Seven Wonders of the Ancient World."
              }
            },
            {
              "_id": "rec38",
              "_score": 0.1876694,
              "fields": {
                "category": "history",
                "chunk_text": "The Taj Mahal is a mausoleum built by Emperor Shah Jahan."
              }
            },
            {
              "_id": "rec5",
              "_score": 0.18504046,
              "fields": {
                "category": "literature",
                "chunk_text": "Shakespeare wrote many famous plays, including Hamlet and Macbeth."
              }
            },
            {
              "_id": "rec15",
              "_score": 0.109251045,
              "fields": {
                "category": "art",
                "chunk_text": "Leonardo da Vinci painted the Mona Lisa."
              }
            },
            {
              "_id": "rec50",
              "_score": 0.098952696,
              "fields": {
                "category": "energy",
                "chunk_text": "Renewable energy sources include wind, solar, and hydroelectric power."
              }
            },
            {
              "_id": "rec26",
              "_score": 0.085251465,
              "fields": {
                "category": "history",
                "chunk_text": "Rome was once the center of a vast empire."
              }
            },
            {
              "_id": "rec47",
              "_score": 0.07533597,
              "fields": {
                "category": "history",
                "chunk_text": "The Industrial Revolution transformed manufacturing and transportation."
              }
            },
            {
              "_id": "rec7",
              "_score": 0.06859385,
              "fields": {
                "category": "history",
                "chunk_text": "The Great Wall of China was built to protect against invasions."
              }
            },
            {
              "_id": "rec1",
              "_score": 0.06831257,
              "fields": {
                "category": "history",
                "chunk_text": "The Eiffel Tower was completed in 1889 and stands in Paris, France."
              }
            },
            {
              "_id": "rec3",
              "_score": 0.06689669,
              "fields": {
                "category": "science",
                "chunk_text": "Albert Einstein developed the theory of relativity."
              }
            }
          ]
        },
        "usage": {
          "read_units": 6,
          "embed_total_tokens": 8
        }
      }
      ```

      ```csharp C# [expandable] theme={null}
      {
        "result": {
          "hits": [
            {
              "_id": "rec17",
              "_score": 0.27985704,
              "fields": {
                "category": "history",
                "chunk_text": "The Pyramids of Giza are among the Seven Wonders of the Ancient World."
              }
            },
            {
              "_id": "rec38",
              "_score": 0.18836586,
              "fields": {
                "category": "history",
                "chunk_text": "The Taj Mahal is a mausoleum built by Emperor Shah Jahan."
              }
            },
            {
              "_id": "rec5",
              "_score": 0.18140909,
              "fields": {
                "category": "literature",
                "chunk_text": "Shakespeare wrote many famous plays, including Hamlet and Macbeth."
              }
            },
            {
              "_id": "rec15",
              "_score": 0.09603156,
              "fields": {
                "category": "art",
                "chunk_text": "Leonardo da Vinci painted the Mona Lisa."
              }
            },
            {
              "_id": "rec50",
              "_score": 0.091406636,
              "fields": {
                "category": "energy",
                "chunk_text": "Renewable energy sources include wind, solar, and hydroelectric power."
              }
            },
            {
              "_id": "rec1",
              "_score": 0.0828001,
              "fields": {
                "category": "history",
                "chunk_text": "The Eiffel Tower was completed in 1889 and stands in Paris, France."
              }
            },
            {
              "_id": "rec26",
              "_score": 0.081794746,
              "fields": {
                "category": "history",
                "chunk_text": "Rome was once the center of a vast empire."
              }
            },
            {
              "_id": "rec7",
              "_score": 0.078153394,
              "fields": {
                "category": "history",
                "chunk_text": "The Great Wall of China was built to protect against invasions."
              }
            },
            {
              "_id": "rec47",
              "_score": 0.06604649,
              "fields": {
                "category": "history",
                "chunk_text": "The Industrial Revolution transformed manufacturing and transportation."
              }
            },
            {
              "_id": "rec21",
              "_score": 0.056735568,
              "fields": {
                "category": "history",
                "chunk_text": "The Statue of Liberty was a gift from France to the United States."
              }
            }
          ]
        },
        "usage": {
          "read_units": 6,
          "embed_total_tokens": 8
        }
      }
      ```
    </CodeGroup>

    ## 6. Rerank results

    To get a more accurate ranking, search again but this time [rerank the initial results](/guides/search/rerank-results) based on their relevance to the query.

    <CodeGroup>
      ```python Python {10-14} theme={null}
      # Search the dense index and rerank results
      reranked_results = dense_index.search(
          namespace="example-namespace",
          query={
              "top_k": 10,
              "inputs": {
                  'text': query
              }
          },
          rerank={
              "model": "bge-reranker-v2-m3",
              "top_n": 10,
              "rank_fields": ["chunk_text"]
          }   
      )

      # Print the reranked results
      for hit in reranked_results['result']['hits']:
          print(f"id: {hit['_id']}, score: {round(hit['_score'], 2)}, text: {hit['fields']['chunk_text']}, category: {hit['fields']['category']}")
      ```

      ```javascript JavaScript {7-11} theme={null}
      // Search the dense index and rerank results
      const rerankedResults = await index.searchRecords({
        query: {
          topK: 10,
          inputs: { text: query },
        },
        rerank: {
          model: 'bge-reranker-v2-m3',
          topN: 10,
          rankFields: ['chunk_text'],
        },
      });

      // Print the reranked results
      rerankedResults.result.hits.forEach(hit => {
        console.log(`id: ${hit.id}, score: ${hit.score.toFixed(2)}, text: ${hit.fields.chunk_text}, category: ${hit.fields.category}`);
      });
      ```

      ```java Java {9} theme={null}
      // Add to the Quickstart class:
      // Define the rerank parameters
      List<String>rankFields = new ArrayList<>();
      rankFields.add("chunk_text");
      SearchRecordsRequestRerank rerank = new SearchRecordsRequestRerank()
              .query(query)
              .model("bge-reranker-v2-m3")
              .topN(10)
              .rankFields(rankFields);

      // Search the dense index and rerank results
      SearchRecordsResponse recordsResponseReranked = index.searchRecordsByText(query,  "example-namespace", fields, 10, null, rerank );

      // Print the reranked results
      System.out.println(recordsResponseReranked);
      ```

      ```go Go {11-15} theme={null}
      // Add to the main function:
      // Search the dense index and rerank results
      topN := int32(10)
      resReranked, err := idxConnection.SearchRecords(ctx, &pinecone.SearchRecordsRequest{
          Query: pinecone.SearchRecordsQuery{
              TopK: 10,
              Inputs: &map[string]interface{}{
                  "text": query,
              },
          },
          Rerank: &pinecone.SearchRecordsRerank{
              Model:      "bge-reranker-v2-m3",
              TopN:       &topN,
              RankFields: []string{"chunk_text"},
          },
      })
      if err != nil {
          log.Fatalf("Failed to search records: %v", err)
      }
      fmt.Printf(prettifyStruct(resReranked))
      ```

      ```csharp C# {12-17} theme={null}
      // Search the dense index and rerank results
      var responseReranked = await index.SearchRecordsAsync(
          "example-namespace",
          new SearchRecordsRequest
          {
              Query = new SearchRecordsRequestQuery
              {
                  TopK = 10,
                  Inputs = new Dictionary<string, object?> { { "text", "Famous historical structures and monuments" } },
              },
              Fields = ["category", "chunk_text"],
              Rerank = new SearchRecordsRequestRerank
              {
                  Model = "bge-reranker-v2-m3",
                  TopN = 10,
                  RankFields = ["chunk_text"],
              }
          }
      );

      Console.WriteLine(responseReranked);
      ```
    </CodeGroup>

    Notice that all of the most relevant results about historical structures and monuments are now ranked highest.

    <CodeGroup>
      ```console Python theme={null}
      id: rec1  | score: 0.11  | category: history    | text: The Eiffel Tower was completed in 1889 and stands in Paris, France.
      id: rec38 | score: 0.06  | category: history    | text: The Taj Mahal is a mausoleum built by Emperor Shah Jahan.
      id: rec7  | score: 0.06  | category: history    | text: The Great Wall of China was built to protect against invasions.
      id: rec17 | score: 0.02  | category: history    | text: The Pyramids of Giza are among the Seven Wonders of the Ancient World.
      id: rec26 | score: 0.01  | category: history    | text: Rome was once the center of a vast empire.        
      id: rec15 | score: 0.01  | category: art        | text: Leonardo da Vinci painted the Mona Lisa.          
      id: rec5  | score: 0.0   | category: literature | text: Shakespeare wrote many famous plays, including Hamlet and Macbeth.
      id: rec47 | score: 0.0   | category: history    | text: The Industrial Revolution transformed manufacturing and transportation.
      id: rec50 | score: 0.0   | category: energy     | text: Renewable energy sources include wind, solar, and hydroelectric power.
      id: rec3  | score: 0.0   | category: science    | text: Albert Einstein developed the theory of relativity.
      ```

      ```console JavaScript theme={null}
      id: rec1, score: 0.11, text: The Eiffel Tower was completed in 1889 and stands in Paris, France., category: history
      id: rec38, score: 0.06, text: The Taj Mahal is a mausoleum built by Emperor Shah Jahan., category: history
      id: rec7, score: 0.06, text: The Great Wall of China was built to protect against invasions., category: history
      id: rec17, score: 0.02, text: The Pyramids of Giza are among the Seven Wonders of the Ancient World., category: history
      id: rec26, score: 0.01, text: Rome was once the center of a vast empire., category: history
      id: rec15, score: 0.01, text: Leonardo da Vinci painted the Mona Lisa., category: art
      id: rec5, score: 0.00, text: Shakespeare wrote many famous plays, including Hamlet and Macbeth., category: literature
      id: rec47, score: 0.00, text: The Industrial Revolution transformed manufacturing and transportation., category: history
      id: rec50, score: 0.00, text: Renewable energy sources include wind, solar, and hydroelectric power., category: energy
      id: rec3, score: 0.00, text: Albert Einstein developed the theory of relativity., category: science
      ```

      ```java Java [expandable] theme={null}
      class SearchRecordsResponse {
          result: class SearchRecordsResponseResult {
              hits: [class Hit {
                  id: rec1
                  score: 0.10687689
                  fields: {category=history, chunk_text=The Eiffel Tower was completed in 1889 and stands in Paris, France.}
                  additionalProperties: null
              }, class Hit {
                  id: rec38
                  score: 0.06418265
                  fields: {category=history, chunk_text=The Taj Mahal is a mausoleum built by Emperor Shah Jahan.}
                  additionalProperties: null
              }, class Hit {
                  id: rec7
                  score: 0.062445287
                  fields: {category=history, chunk_text=The Great Wall of China was built to protect against invasions.}
                  additionalProperties: null
              }, class Hit {
                  id: rec17
                  score: 0.0153063545
                  fields: {category=history, chunk_text=The Pyramids of Giza are among the Seven Wonders of the Ancient World.}
                  additionalProperties: null
              }, class Hit {
                  id: rec26
                  score: 0.010652511
                  fields: {category=history, chunk_text=Rome was once the center of a vast empire.}
                  additionalProperties: null
              }, class Hit {
                  id: rec5
                  score: 3.194182E-5
                  fields: {category=literature, chunk_text=Shakespeare wrote many famous plays, including Hamlet and Macbeth.}
                  additionalProperties: null
              }, class Hit {
                  id: rec47
                  score: 1.7502925E-5
                  fields: {category=history, chunk_text=The Industrial Revolution transformed manufacturing and transportation.}
                  additionalProperties: null
              }, class Hit {
                  id: rec32
                  score: 1.631454E-5
                  fields: {category=biology, chunk_text=Elephants have excellent memory and strong social bonds.}
                  additionalProperties: null
              }, class Hit {
                  id: rec4
                  score: 1.6187581E-5
                  fields: {category=biology, chunk_text=The mitochondrion is often called the powerhouse of the cell.}
                  additionalProperties: null
              }, class Hit {
                  id: rec45
                  score: 1.6061611E-5
                  fields: {category=literature, chunk_text=A haiku is a traditional Japanese poem with a 5-7-5 syllable structure.}
                  additionalProperties: null
              }]
              additionalProperties: null
          }
          usage: class SearchUsage {
              readUnits: 6
              embedTotalTokens: 13
              rerankUnits: 1
              additionalProperties: null
          }
          additionalProperties: null
      }
      ```

      ```json Go [expandable] theme={null}
      {
        "result": {
          "hits": [
            {
              "_id": "rec1",
              "_score": 0.10743748,
              "fields": {
                "category": "history",
                "chunk_text": "The Eiffel Tower was completed in 1889 and stands in Paris, France."
              }
            },
            {
              "_id": "rec38",
              "_score": 0.064535476,
              "fields": {
                "category": "history",
                "chunk_text": "The Taj Mahal is a mausoleum built by Emperor Shah Jahan."
              }
            },
            {
              "_id": "rec7",
              "_score": 0.062445287,
              "fields": {
                "category": "history",
                "chunk_text": "The Great Wall of China was built to protect against invasions."
              }
            },
            {
              "_id": "rec17",
              "_score": 0.0153063545,
              "fields": {
                "category": "history",
                "chunk_text": "The Pyramids of Giza are among the Seven Wonders of the Ancient World."
              }
            },
            {
              "_id": "rec26",
              "_score": 0.010652511,
              "fields": {
                "category": "history",
                "chunk_text": "Rome was once the center of a vast empire."
              }
            },
            {
              "_id": "rec15",
              "_score": 0.007876706,
              "fields": {
                "category": "art",
                "chunk_text": "Leonardo da Vinci painted the Mona Lisa."
              }
            },
            {
              "_id": "rec5",
              "_score": 0.00003194182,
              "fields": {
                "category": "literature",
                "chunk_text": "Shakespeare wrote many famous plays, including Hamlet and Macbeth."
              }
            },
            {
              "_id": "rec47",
              "_score": 0.000017502925,
              "fields": {
                "category": "history",
                "chunk_text": "The Industrial Revolution transformed manufacturing and transportation."
              }
            },
            {
              "_id": "rec50",
              "_score": 0.00001631454,
              "fields": {
                "category": "energy",
                "chunk_text": "Renewable energy sources include wind, solar, and hydroelectric power."
              }
            },
            {
              "_id": "rec3",
              "_score": 0.000015936621,
              "fields": {
                "category": "science",
                "chunk_text": "Albert Einstein developed the theory of relativity."
              }
            }
          ]
        },
        "usage": {
          "read_units": 6,
          "embed_total_tokens": 8,
          "rerank_units": 1
        }
      }
      ```

      ```csharp C# [expandable] theme={null}
      {
        "result": {
          "hits": [
            {
              "_id": "rec1",
              "_score": 0.10687689,
              "fields": {
                "category": "history",
                "chunk_text": "The Eiffel Tower was completed in 1889 and stands in Paris, France."
              }
            },
            {
              "_id": "rec38",
              "_score": 0.064535476,
              "fields": {
                "category": "history",
                "chunk_text": "The Taj Mahal is a mausoleum built by Emperor Shah Jahan."
              }
            },
            {
              "_id": "rec7",
              "_score": 0.062445287,
              "fields": {
                "category": "history",
                "chunk_text": "The Great Wall of China was built to protect against invasions."
              }
            },
            {
              "_id": "rec21",
              "_score": 0.018511046,
              "fields": {
                "category": "history",
                "chunk_text": "The Statue of Liberty was a gift from France to the United States."
              }
            },
            {
              "_id": "rec17",
              "_score": 0.0153063545,
              "fields": {
                "category": "history",
                "chunk_text": "The Pyramids of Giza are among the Seven Wonders of the Ancient World."
              }
            },
            {
              "_id": "rec26",
              "_score": 0.010652511,
              "fields": {
                "category": "history",
                "chunk_text": "Rome was once the center of a vast empire."
              }
            },
            {
              "_id": "rec15",
              "_score": 0.007876706,
              "fields": {
                "category": "art",
                "chunk_text": "Leonardo da Vinci painted the Mona Lisa."
              }
            },
            {
              "_id": "rec5",
              "_score": 0.00003194182,
              "fields": {
                "category": "literature",
                "chunk_text": "Shakespeare wrote many famous plays, including Hamlet and Macbeth."
              }
            },
            {
              "_id": "rec47",
              "_score": 0.000017502925,
              "fields": {
                "category": "history",
                "chunk_text": "The Industrial Revolution transformed manufacturing and transportation."
              }
            },
            {
              "_id": "rec50",
              "_score": 0.00001631454,
              "fields": {
                "category": "energy",
                "chunk_text": "Renewable energy sources include wind, solar, and hydroelectric power."
              }
            }
          ]
        },
        "usage": {
          "read_units": 6,
          "embed_total_tokens": 8,
          "rerank_units": 1
        }
      }
      ```
    </CodeGroup>

    ## 7. Improve results

    [Reranking results](/guides/search/rerank-results) is one of the most effective ways to improve search accuracy and relevance, but there are many other techniques to consider. For example:

    * [Filtering by metadata](/guides/search/filter-by-metadata): When records contain additional metadata, you can limit the search to records matching a [filter expression](/guides/index-data/indexing-overview#metadata-filter-expressions).

    * [Hybrid search](/guides/search/hybrid-search): You can add [lexical search](/guides/search/lexical-search) to capture precise keyword matches (e.g., product SKUs, email addresses, domain-specific terms) in addition to semantic matches.

    * [Chunking strategies](https://www.pinecone.io/learn/chunking-strategies/): You can chunk your content in different ways to get better results. Consider factors like the length of the content, the complexity of queries, and how results will be used in your application.

    ## 8. Clean up

    When you no longer need your example index, delete it as follows:

    <CodeGroup>
      ```python Python theme={null}
      # Delete the index
      pc.delete_index(index_name)
      ```

      ```javascript JavaScript theme={null}
      // Delete the index
      await pc.deleteIndex(indexName);
      ```

      ```java Java theme={null}
      // Add to the Quickstart class:
      // Delete the index
      pc.deleteIndex(indexName);
      ```

      ```go Go theme={null}
      // Add to the main function:
      // Delete the index
      err = pc.DeleteIndex(ctx, indexName)
      if err != nil {
          log.Fatalf("Failed to delete index: %v", err)
      } else {
          fmt.Println("Index \"%v\" deleted successfully", indexName)
      }
      ```

      ```csharp C# theme={null}
      // Delete the index
      await pinecone.DeleteIndexAsync(indexName);
      ```
    </CodeGroup>

    <Tip>
      For production indexes, consider [enabling deletion protection](/guides/manage-data/manage-indexes#configure-deletion-protection).
    </Tip>

    ## Next steps

    <CardGroup cols={3}>
      <Card title="Index data" icon="book-open" href="/guides/index-data/indexing-overview">
        Learn more about storing data in Pinecone
      </Card>

      <Card title="Search" icon="magnifying-glass" href="/guides/search/search-overview">
        Explore different forms of vector search.
      </Card>

      <Card title="Optimize" icon="rocket" href="/guides/optimize">
        Find out how to improve performance
      </Card>
    </CardGroup>
  </Tab>

  <Tab title="Cursor">
    Use [Cursor](https://cursor.com/) to build a Pinecone application with current best practices. Instead of copying code snippets, you'll work with an agent that understands Pinecone APIs and implements production-ready patterns automatically.

    <Note>
      Because this quickstart relies on AI, the exact implementation may vary each time.
    </Note>

    ## 1. Sign up

    If you're new to Pinecone, sign up at [app.pinecone.io](https://app.pinecone.io) and choose a free plan:

    * [Starter plan](https://pinecone.io/pricing/): Free access to most features, but you're limited to one cloud region and need to stay under Starter plan [limits](/reference/api/database-limits).

    * [Standard plan trial](/guides/organizations/manage-billing/standard-trial): 21 days and \$300 in credits with access to Standard plan [features](https://www.pinecone.io/pricing/) and [higher limits](/reference/api/database-limits) that let you test Pinecone at scale.

    <Note>
      You cannot switch from the Starter plan to the Standard plan trial, so be sure to select the right plan for your needs.
    </Note>

    After signing up, you'll receive an API key in the console. Save this key. You'll need it to authenticate your requests to Pinecone.

    ## 2. Download `AGENTS.md`

    AI coding agents like Cursor learn from web searches and training data, which can include outdated patterns. To ensure Cursor uses current Pinecone APIs and best practices, you'll use an `AGENTS.md` reference file that provides authoritative, up-to-date information about Pinecone's 2025 APIs and CLI commands.

    1. Create a new project folder:

       ```shell  theme={null}
       mkdir pinecone-quickstart
       cd pinecone-quickstart
       ```

    2. Download the `AGENTS.md` reference file for your preferred programming language:

       <div id="cursor-reference-file">
         <CodeGroup>
           ```shell Python theme={null}
           curl -o AGENTS.md https://docs.pinecone.io/AGENTS-PYTHON.md
           ```

           ```shell JavaScript theme={null}
           curl -o AGENTS.md https://docs.pinecone.io/AGENTS-JAVASCRIPT.md
           ```
         </CodeGroup>
       </div>

    3. Open your project in Cursor and start a new agent chat (`Cmd I`).

       <Tip>
         If you don't have Cursor installed, see the [Cursor quickstart](https://cursor.com/docs/get-started/quickstart).
       </Tip>

    4. Verify that Cursor has access to the `AGENTS.md` file:

       ```terminal wrap theme={null}
       Confirm you can see the AGENTS.md file and understand the current Pinecone best practices it contains.

       Summarize the key points about using Pinecone in 2025.

       Just give me a concise summary - don't create any additional files or examples yet.
       ```

    ## 3. Prompt your agent

    Now ask your agent to help you get started with Pinecone:

    ```terminal wrap theme={null} theme={null} theme={null} theme={null}
    Help me get started with Pinecone.
    ```

    Your agent will first ask you to choose an option: quick test, semantic search, RAG, or recommendations. Based on your choice, it will build and test a sample application using Pinecone best practices. Finally, it will provide a succinct summary of what it did.

    Throughout and after the process, you can review the generated code in your IDE to understand the patterns and best practices applied. You can also ask your coding agent to explain the code to you.

    ## 4. Give us feedback

    We'd love to hear your feedback on this quickstart. Please fill out this [short survey](https://share.hsforms.com/1roCbfhevRhKBOndYpA85pw4wfik).

    ## Next steps

    * Use your coding agent to:
      * Learn more about the system you built.
      * Extend or modify it.
      * Plan and implement specific requirements related to your own use case.

    * Learn more about Pinecone:

      <CardGroup cols={3}>
        <Card title="Index data" icon="book-open" href="/guides/index-data/indexing-overview">
          Learn more about storing data in Pinecone
        </Card>

        <Card title="Search" icon="magnifying-glass" href="/guides/search/search-overview">
          Explore different forms of vector search.
        </Card>

        <Card title="Optimize" icon="rocket" href="/guides/optimize">
          Find out how to improve performance
        </Card>
      </CardGroup>
  </Tab>

  <Tab title="Claude Code">
    Use [Claude Code](https://www.claude.com/product/claude-code) to build a Pinecone application with current best practices. Instead of copying code snippets, work with an agent that understands Pinecone APIs and implements production-ready patterns automatically.

    <Note>
      Because this quickstart relies on AI, the exact implementation may vary each time.
    </Note>

    ## 1. Sign up

    If you're new to Pinecone, sign up at [app.pinecone.io](https://app.pinecone.io) and choose a free plan:

    * [Starter plan](https://pinecone.io/pricing/): Free access to most features, but you're limited to one cloud region and need to stay under Starter plan [limits](/reference/api/database-limits).

    * [Standard plan trial](/guides/organizations/manage-billing/standard-trial): 21 days and \$300 in credits with access to Standard plan [features](https://www.pinecone.io/pricing/) and [higher limits](/reference/api/database-limits) that let you test Pinecone at scale.

    <Note>
      You cannot switch from the Starter plan to the Standard plan trial, so be sure to select the right plan for your needs.
    </Note>

    After signing up, you'll receive an API key in the console. Save this key. You'll need it to authenticate your requests to Pinecone.

    ## 2. Download `CLAUDE.md`

    AI coding agents like Claude Code learn from web searches and training data, which can include outdated patterns. To ensure Claude Code uses current Pinecone APIs and best practices, you'll use a `CLAUDE.md` reference file that provides authoritative, up-to-date information about Pinecone's 2025 APIs and CLI commands.

    1. Create a new project folder:

       ```shell  theme={null}
       mkdir pinecone-quickstart
       cd pinecone-quickstart
       ```

    2. Download the `CLAUDE.md` reference file for your preferred programming language:

       <div id="claude-reference-file">
         <CodeGroup>
           ```shell Python theme={null}
           curl -o CLAUDE.md https://docs.pinecone.io/AGENTS-PYTHON.md
           ```

           ```shell JavaScript theme={null}
           curl -o CLAUDE.md https://docs.pinecone.io/AGENTS-JAVASCRIPT.md
           ```
         </CodeGroup>
       </div>

    3. Start Claude Code:

       ```shell  theme={null}
       claude
       ```

       <Tip>
         If you don't have Claude Code installed, see the [Claude Code quickstart](https://docs.claude.com/en/docs/claude-code/quickstart).
       </Tip>

    4. Verify that Claude Code has access to the `CLAUDE.md` file:

       ```terminal wrap theme={null}
       Confirm you can see the CLAUDE.md file and understand the current Pinecone best practices it contains.

       Summarize the key points about using Pinecone in 2025.

       Just give me a concise summary - don't create any additional files or examples yet.
       ```

    ## 3. Prompt your agent

    Now ask your agent to help you get started with Pinecone:

    ```terminal wrap theme={null} theme={null} theme={null} theme={null}
    Help me get started with Pinecone.
    ```

    Your agent will first ask you to choose an option: quick test, semantic search, RAG, or recommendations. Based on your choice, it will build and test a sample application using Pinecone best practices. Finally, it will provide a succinct summary of what it did.

    Throughout and after the process, you can review the generated code in your IDE to understand the patterns and best practices applied. You can also ask your coding agent to explain the code to you.

    ## 4. Give us feedback

    We'd love to hear your feedback on this quickstart. Please fill out this [short survey](https://share.hsforms.com/1roCbfhevRhKBOndYpA85pw4wfik).

    ## Next steps

    * Use your coding agent to:
      * Learn more about the system you built.
      * Extend or modify it.
      * Plan and implement specific requirements related to your own use case.

    * Learn more about Pinecone:

      <CardGroup cols={3}>
        <Card title="Index data" icon="book-open" href="/guides/index-data/indexing-overview">
          Learn more about storing data in Pinecone
        </Card>

        <Card title="Search" icon="magnifying-glass" href="/guides/search/search-overview">
          Explore different forms of vector search.
        </Card>

        <Card title="Optimize" icon="rocket" href="/guides/optimize">
          Find out how to improve performance
        </Card>
      </CardGroup>
  </Tab>

  <Tab title="n8n">
    Create an [n8n](https://docs.n8n.io/choose-n8n/) workflow that downloads files via HTTP and lets you chat with them using Pinecone Database and OpenAI.

    <Tip>
      If you're not interested in chunking and embedding your own data or figuring out which search method to use, [use n8n with Pinecone Assistant](/guides/assistant/quickstart#n8n) instead.
    </Tip>

    ## 1. Get API keys

    Your n8n workflow will need API keys for Pinecone and OpenAI.

    <Steps>
      <Step title="Get a Pinecone API key">
        Create a new API key in the [Pinecone console](https://app.pinecone.io/organizations/-/keys), or use the widget below to generate a key. If you don't have a Pinecone account, the widget will sign you up for the free [Starter plan](https://www.pinecone.io/pricing/).

        <div style={{minWidth: '450px', minHeight:'152px'}}>
          <div id="pinecone-connect-widget">
            <div class="connect-widget-skeleton">
              <div class="skeleton-content" />
            </div>
          </div>
        </div>

        Your generated API key:

        ```shell  theme={null}
        "{{YOUR_API_KEY}}"
        ```
      </Step>

      <Step title="Get an OpenAI API key">
        Create a new API key in the [OpenAI console](https://platform.openai.com/api-keys).
      </Step>
    </Steps>

    ## 2. Create an index

    [Create an index](https://app.pinecone.io/organizations/-/projects/-/create-index/serverless) in the Pinecone console:

    * Name your index `n8n-dense-index`
    * Under **Configuration**, check **Custom settings** and set **Dimension** to 1536.
    * Leave everything else as default.

    ## 3. Set up n8n

    <Steps>
      <Step title="Create a new workflow">
        In your n8n account, [create a new workflow](https://docs.n8n.io/workflows/create/).
      </Step>

      <Step title="Import a workflow template">
        Copy this workflow template URL:

        ```shell  theme={null}
        https://raw.githubusercontent.com/pinecone-io/n8n-templates/refs/heads/main/database-quickstart/database-quickstart.json
        ```

        Paste the URL into the workflow editor and then click **Import** to add the workflow.
      </Step>

      <Step title="Add credentials to the workflow">
        * Add your Pinecone credentials:
          * In the **Pinecone Vector Store** node, select **Credential to connect with** > **Create new credential** and paste in your Pinecone API key.
          * Name the credential **Pinecone** so that other nodes reference it.

        * Add your OpenAI credentials:
          * In the **OpenAI Chat Model**, select **Credential to connect with** > **Create new credential** and paste in your OpenAI API key.
      </Step>

      <Step title="Activate the workflow">
        The workflow is configured to download recent Pinecone release notes and upload them to your Pinecone index. Click **Execute workflow** to start the workflow.

        <Tip>
          You can add your own files to the workflow by changing the URLs in the **Set file urls** node.
        </Tip>
      </Step>
    </Steps>

    ## 4. Chat with your docs

    Once the workflow is activated, ask it for the latest changes to Pinecone Database:

    ```
    What's new in Pinecone Database?
    ```

    ## Next steps

    * Use your own data:
      * Change the urls in **Set file urls** node to use your own files.
      * You may need to adjust the chunk sizes in the **Recursive Character Text Splitter** node or use a different chunking strategy. You want chunks that are big enough to contain meaningful information but not so big that the meaning is diluted or it can't fit within the context window of the embedding model. See [Chunking Strategies for LLM Applications](https://www.pinecone.io/learn/chunking-strategies/) for more info.
      * Customize the system message of the **AI Agent** node to reflect what the **Pinecone Vector Store Tool** will be used for. Be sure to include info on what data can be retrieved using that tool.
      * Customize the description of the **Pinecone Vector Store Tool** to reflect what data you are storing in the Pinecone index.
    * Use n8n, Pinecone Assistant, and OpenAI to [chat with your Google Drive documents](https://n8n.io/workflows/9942-rag-powered-document-chat-with-google-drive-openai-and-pinecone-assistant/).
    * Get help in the [Pinecone Discord community](https://discord.gg/tJ8V62S3sH) or the [Pinecone Forum](https://community.pinecone.io/).
  </Tab>
</Tabs>
