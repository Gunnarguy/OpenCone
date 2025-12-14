# Hybrid search

> Combine semantic and lexical search for better results.

[Semantic search](/guides/search/semantic-search) and [lexical search](/guides/search/lexical-search) are powerful information retrieval techniques, but each has notable limitations. For example, semantic search can miss results based on exact keyword matches, especially in scenarios involving domain-specific terminology, while lexical search can miss results based on relationships, such as synonyms and paraphrases.

This page shows you how to lift these limitations by combining semantic and lexical search. This is often called hybrid search.

## Hybrid search approaches

There are two ways to perform hybrid search in Pinecone:

* [Use separate dense and sparse indexes](#use-separate-dense-and-sparse-indexes). This is the **recommended** approach because it provides the most flexibility.
* [Use a single hybrid index](#use-a-single-hybrid-index). This approach is simpler to implement but doesn't support a few useful features.

The following table summarizes the pros and cons between the two approaches:

| Approach                          | Pros                                                                                                                                                                                                                                                                                       | Cons                                                                                                                                                                            |
| :-------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Separate dense and sparse indexes | <ul><li>You can start with dense for semantic search and add sparse for lexical search later.</li><li>You can do sparse-only queries.</li><li>You can rerank at multiple levels (for each index and for merged results).</li><li>You can use integrated embedding and reranking.</li></ul> | <ul><li>You need to manage and make requests to two separate indexes.</li><li>You need to maintain the linkage between sparse and dense vectors in different indexes.</li></ul> |
| Single hybrid index               | <ul><li>You make requests to only a single index.</li><li>The linkage between dense and sparse vectors is implicit.</li></ul>                                                                                                                                                              | <ul><li>You can't do sparse-only queries.</li><li>You can't use integrated embedding and reranking.</li></ul>                                                                   |

## Use separate dense and sparse indexes

This is the recommended way to perform hybrid search in Pinecone. You create separate dense and sparse indexes, upsert dense vectors into the dense index and sparse vectors into the sparse index, and search each index separately. Then you combine and deduplicate the results, use one of Pinecone's [hosted reranking models](/guides/search/rerank-results#reranking-models) to rerank them based on a unified relevance score, and return the most relevant matches.

<Steps>
  <Step title="Create dense and sparse indexes">
    [Create a dense index](/guides/index-data/create-an-index#create-a-dense-index) and [create a sparse index](/guides/index-data/create-an-index#create-a-sparse-index), either with integrated embedding or for vectors created with external models.

    For example, the following code creates indexes with integrated embedding models.

    ```python Python theme={null}
    from pinecone import Pinecone

    pc = Pinecone(api_key="YOUR_API_KEY")

    dense_index_name = "dense-for-hybrid-py"
    sparse_index_name = "sparse-for-hybrid-py"

    if not pc.has_index(dense_index_name):
        pc.create_index_for_model(
            name=dense_index_name,
            cloud="aws",
            region="us-east-1",
            embed={
                "model":"llama-text-embed-v2",
                "field_map":{"text": "chunk_text"}
            }
        )

    if not pc.has_index(sparse_index_name):
        pc.create_index_for_model(
            name=sparse_index_name,
            cloud="aws",
            region="us-east-1",
            embed={
                "model":"pinecone-sparse-english-v0",
                "field_map":{"text": "chunk_text"}
            }
        )
    ```
  </Step>

  <Step title="Upsert dense and sparse vectors">
    [Upsert dense vectors](/guides/index-data/upsert-data#upsert-dense-vectors) into the dense index and [upsert sparse vectors](/guides/index-data/upsert-data#upsert-sparse-vectors) into the sparse index.

    Make sure to establish a linkage between the dense and sparse vectors so you can merge and deduplicate search results later. For example, the following uses `_id` as the linkage, but you can use any other custom field as well. Because the indexes are integrated with embedding models, you provide the source texts and Pinecone converts them to vectors automatically.

    ```python Python [expandable] theme={null}
    # Define the records
    records = [
        { "_id": "vec1", "chunk_text": "Apple Inc. issued a $10 billion corporate bond in 2023." },
        { "_id": "vec2", "chunk_text": "ETFs tracking the S&P 500 outperformed active funds last year." },
        { "_id": "vec3", "chunk_text": "Tesla's options volume surged after the latest earnings report." },
        { "_id": "vec4", "chunk_text": "Dividend aristocrats are known for consistently raising payouts." },
        { "_id": "vec5", "chunk_text": "The Federal Reserve raised interest rates by 0.25% to curb inflation." },
        { "_id": "vec6", "chunk_text": "Unemployment hit a record low of 3.7% in Q4 of 2024." },
        { "_id": "vec7", "chunk_text": "The CPI index rose by 6% in July 2024, raising concerns about purchasing power." },
        { "_id": "vec8", "chunk_text": "GDP growth in emerging markets outpaced developed economies." },
        { "_id": "vec9", "chunk_text": "Amazon's acquisition of MGM Studios was valued at $8.45 billion." },
        { "_id": "vec10", "chunk_text": "Alphabet reported a 20% increase in advertising revenue." },
        { "_id": "vec11", "chunk_text": "ExxonMobil announced a special dividend after record profits." },
        { "_id": "vec12", "chunk_text": "Tesla plans a 3-for-1 stock split to attract retail investors." },
        { "_id": "vec13", "chunk_text": "Credit card APRs reached an all-time high of 22.8% in 2024." },
        { "_id": "vec14", "chunk_text": "A 529 college savings plan offers tax advantages for education." },
        { "_id": "vec15", "chunk_text": "Emergency savings should ideally cover 6 months of expenses." },
        { "_id": "vec16", "chunk_text": "The average mortgage rate rose to 7.1% in December." },
        { "_id": "vec17", "chunk_text": "The SEC fined a hedge fund $50 million for insider trading." },
        { "_id": "vec18", "chunk_text": "New ESG regulations require companies to disclose climate risks." },
        { "_id": "vec19", "chunk_text": "The IRS introduced a new tax bracket for high earners." },
        { "_id": "vec20", "chunk_text": "Compliance with GDPR is mandatory for companies operating in Europe." },
        { "_id": "vec21", "chunk_text": "What are the best-performing green bonds in a rising rate environment?" },
        { "_id": "vec22", "chunk_text": "How does inflation impact the real yield of Treasury bonds?" },
        { "_id": "vec23", "chunk_text": "Top SPAC mergers in the technology sector for 2024." },
        { "_id": "vec24", "chunk_text": "Are stablecoins a viable hedge against currency devaluation?" },
        { "_id": "vec25", "chunk_text": "Comparison of Roth IRA vs 401(k) for high-income earners." },
        { "_id": "vec26", "chunk_text": "Stock splits and their effect on investor sentiment." },
        { "_id": "vec27", "chunk_text": "Tech IPOs that disappointed in their first year." },
        { "_id": "vec28", "chunk_text": "Impact of interest rate hikes on bank stocks." },
        { "_id": "vec29", "chunk_text": "Growth vs. value investing strategies in 2024." },
        { "_id": "vec30", "chunk_text": "The role of artificial intelligence in quantitative trading." },
        { "_id": "vec31", "chunk_text": "What are the implications of quantitative tightening on equities?" },
        { "_id": "vec32", "chunk_text": "How does compounding interest affect long-term investments?" },
        { "_id": "vec33", "chunk_text": "What are the best assets to hedge against inflation?" },
        { "_id": "vec34", "chunk_text": "Can ETFs provide better diversification than mutual funds?" },
        { "_id": "vec35", "chunk_text": "Unemployment hit at 2.4% in Q3 of 2024." },
        { "_id": "vec36", "chunk_text": "Unemployment is expected to hit 2.5% in Q3 of 2024." },
        { "_id": "vec37", "chunk_text": "In Q3 2025 unemployment for the prior year was revised to 2.2%"},
        { "_id": "vec38", "chunk_text": "Emerging markets witnessed increased foreign direct investment as global interest rates stabilized." },
        { "_id": "vec39", "chunk_text": "The rise in energy prices significantly impacted inflation trends during the first half of 2024." },
        { "_id": "vec40", "chunk_text": "Labor market trends show a declining participation rate despite record low unemployment in 2024." },
        { "_id": "vec41", "chunk_text": "Forecasts of global supply chain disruptions eased in late 2024, but consumer prices remained elevated due to persistent demand." },
        { "_id": "vec42", "chunk_text": "Tech sector layoffs in Q3 2024 have reshaped hiring trends across high-growth industries." },
        { "_id": "vec43", "chunk_text": "The U.S. dollar weakened against a basket of currencies as the global economy adjusted to shifting trade balances." },
        { "_id": "vec44", "chunk_text": "Central banks worldwide increased gold reserves to hedge against geopolitical and economic instability." },
        { "_id": "vec45", "chunk_text": "Corporate earnings in Q4 2024 were largely impacted by rising raw material costs and currency fluctuations." },
        { "_id": "vec46", "chunk_text": "Economic recovery in Q2 2024 relied heavily on government spending in infrastructure and green energy projects." },
        { "_id": "vec47", "chunk_text": "The housing market saw a rebound in late 2024, driven by falling mortgage rates and pent-up demand." },
        { "_id": "vec48", "chunk_text": "Wage growth outpaced inflation for the first time in years, signaling improved purchasing power in 2024." },
        { "_id": "vec49", "chunk_text": "China's economic growth in 2024 slowed to its lowest level in decades due to structural reforms and weak exports." },
        { "_id": "vec50", "chunk_text": "AI-driven automation in the manufacturing sector boosted productivity but raised concerns about job displacement." },
        { "_id": "vec51", "chunk_text": "The European Union introduced new fiscal policies in 2024 aimed at reducing public debt without stifling growth." },
        { "_id": "vec52", "chunk_text": "Record-breaking weather events in early 2024 have highlighted the growing economic impact of climate change." },
        { "_id": "vec53", "chunk_text": "Cryptocurrencies faced regulatory scrutiny in 2024, leading to volatility and reduced market capitalization." },
        { "_id": "vec54", "chunk_text": "The global tourism sector showed signs of recovery in late 2024 after years of pandemic-related setbacks." },
        { "_id": "vec55", "chunk_text": "Trade tensions between the U.S. and China escalated in 2024, impacting global supply chains and investment flows." },
        { "_id": "vec56", "chunk_text": "Consumer confidence indices remained resilient in Q2 2024 despite fears of an impending recession." },
        { "_id": "vec57", "chunk_text": "Startups in 2024 faced tighter funding conditions as venture capitalists focused on profitability over growth." },
        { "_id": "vec58", "chunk_text": "Oil production cuts in Q1 2024 by OPEC nations drove prices higher, influencing global energy policies." },
        { "_id": "vec59", "chunk_text": "The adoption of digital currencies by central banks increased in 2024, reshaping monetary policy frameworks." },
        { "_id": "vec60", "chunk_text": "Healthcare spending in 2024 surged as governments expanded access to preventive care and pandemic preparedness." },
        { "_id": "vec61", "chunk_text": "The World Bank reported declining poverty rates globally, but regional disparities persisted." },
        { "_id": "vec62", "chunk_text": "Private equity activity in 2024 focused on renewable energy and technology sectors amid shifting investor priorities." },
        { "_id": "vec63", "chunk_text": "Population aging emerged as a critical economic issue in 2024, especially in advanced economies." },
        { "_id": "vec64", "chunk_text": "Rising commodity prices in 2024 strained emerging markets dependent on imports of raw materials." },
        { "_id": "vec65", "chunk_text": "The global shipping industry experienced declining freight rates in 2024 due to overcapacity and reduced demand." },
        { "_id": "vec66", "chunk_text": "Bank lending to small and medium-sized enterprises surged in 2024 as governments incentivized entrepreneurship." },
        { "_id": "vec67", "chunk_text": "Renewable energy projects accounted for a record share of global infrastructure investment in 2024." },
        { "_id": "vec68", "chunk_text": "Cybersecurity spending reached new highs in 2024, reflecting the growing threat of digital attacks on infrastructure." },
        { "_id": "vec69", "chunk_text": "The agricultural sector faced challenges in 2024 due to extreme weather and rising input costs." },
        { "_id": "vec70", "chunk_text": "Consumer spending patterns shifted in 2024, with a greater focus on experiences over goods." },
        { "_id": "vec71", "chunk_text": "The economic impact of the 2008 financial crisis was mitigated by quantitative easing policies." },
        { "_id": "vec72", "chunk_text": "In early 2024, global GDP growth slowed, driven by weaker exports in Asia and Europe." },
        { "_id": "vec73", "chunk_text": "The historical relationship between inflation and unemployment is explained by the Phillips Curve." },
        { "_id": "vec74", "chunk_text": "The World Trade Organization's role in resolving disputes was tested in 2024." },
        { "_id": "vec75", "chunk_text": "The collapse of Silicon Valley Bank raised questions about regulatory oversight in 2024." },
        { "_id": "vec76", "chunk_text": "The cost of living crisis has been exacerbated by stagnant wage growth and rising inflation." },
        { "_id": "vec77", "chunk_text": "Supply chain resilience became a top priority for multinational corporations in 2024." },
        { "_id": "vec78", "chunk_text": "Consumer sentiment surveys in 2024 reflected optimism despite high interest rates." },
        { "_id": "vec79", "chunk_text": "The resurgence of industrial policy in Q1 2024 focused on decoupling critical supply chains." },
        { "_id": "vec80", "chunk_text": "Technological innovation in the fintech sector disrupted traditional banking in 2024." },
        { "_id": "vec81", "chunk_text": "The link between climate change and migration patterns is increasingly recognized." },
        { "_id": "vec82", "chunk_text": "Renewable energy subsidies in 2024 reduced the global reliance on fossil fuels." },
        { "_id": "vec83", "chunk_text": "The economic fallout of geopolitical tensions was evident in rising defense budgets worldwide." },
        { "_id": "vec84", "chunk_text": "The IMF's 2024 global outlook highlighted risks of stagflation in emerging markets." },
        { "_id": "vec85", "chunk_text": "Declining birth rates in advanced economies pose long-term challenges for labor markets." },
        { "_id": "vec86", "chunk_text": "Digital transformation initiatives in 2024 drove productivity gains in the services sector." },
        { "_id": "vec87", "chunk_text": "The U.S. labor market's resilience in 2024 defied predictions of a severe recession." },
        { "_id": "vec88", "chunk_text": "New fiscal measures in the European Union aimed to stabilize debt levels post-pandemic." },
        { "_id": "vec89", "chunk_text": "Venture capital investments in 2024 leaned heavily toward AI and automation startups." },
        { "_id": "vec90", "chunk_text": "The surge in e-commerce in 2024 was facilitated by advancements in logistics technology." },
        { "_id": "vec91", "chunk_text": "The impact of ESG investing on corporate strategies has been a major focus in 2024." },
        { "_id": "vec92", "chunk_text": "Income inequality widened in 2024 despite strong economic growth in developed nations." },
        { "_id": "vec93", "chunk_text": "The collapse of FTX highlighted the volatility and risks associated with cryptocurrencies." },
        { "_id": "vec94", "chunk_text": "Cyberattacks targeting financial institutions in 2024 led to record cybersecurity spending." },
        { "_id": "vec95", "chunk_text": "Automation in agriculture in 2024 increased yields but displaced rural workers." },
        { "_id": "vec96", "chunk_text": "New trade agreements signed 2022 will make an impact in 2024"},
    ]
    ```

    ```python Python theme={null}
    # Target the dense and sparse indexes
    # To get the unique host for an index, 
    # see https://docs.pinecone.io/guides/manage-data/target-an-index
    dense_index = pc.Index(host="INDEX_HOST")
    sparse_index = pc.Index(host="INDEX_HOST")

    # Upsert the records
    # The `chunk_text` fields are converted to dense and sparse vectors
    dense_index.upsert_records("example-namespace", records)
    sparse_index.upsert_records("example-namespace", records)
    ```
  </Step>

  <Step title="Search the dense index">
    Perform a [semantic search](/guides/search/semantic-search) on the dense index.

    For example, the following code searches the dense index for 40 records most semantically related to the query "Q3 2024 us economic data". Because the index is integrated with an embedding model, you provide the query as text and Pinecone converts the text to a dense vector automatically.

    ```python Python theme={null}
    query = "Q3 2024 us economic data"

    dense_results = dense_index.search(
        namespace="example-namespace",
        query={
            "top_k": 40,
            "inputs": {
                "text": query
            }
        }
    )

    print(dense_results)
    ```

    ```python Response [expandable] theme={null}
    {'result': {'hits': [{'_id': 'vec35',
                          '_score': 0.8629686832427979,
                          'fields': {'chunk_text': 'Unemployment hit at 2.4% in Q3 '
                                                   'of 2024.'}},
                         {'_id': 'vec36',
                          '_score': 0.8573639988899231,
                          'fields': {'chunk_text': 'Unemployment is expected to '
                                                   'hit 2.5% in Q3 of 2024.'}},
                         {'_id': 'vec6',
                          '_score': 0.8535352945327759,
                          'fields': {'chunk_text': 'Unemployment hit a record low '
                                                   'of 3.7% in Q4 of 2024.'}},
                         {'_id': 'vec42',
                          '_score': 0.8336166739463806,
                          'fields': {'chunk_text': 'Tech sector layoffs in Q3 2024 '
                                                   'have reshaped hiring trends '
                                                   'across high-growth '
                                                   'industries.'}},
                         {'_id': 'vec48',
                          '_score': 0.8328524827957153,
                          'fields': {'chunk_text': 'Wage growth outpaced inflation '
                                                   'for the first time in years, '
                                                   'signaling improved purchasing '
                                                   'power in 2024.'}},
                         {'_id': 'vec55',
                          '_score': 0.8322604298591614,
                          'fields': {'chunk_text': 'Trade tensions between the '
                                                   'U.S. and China escalated in '
                                                   '2024, impacting global supply '
                                                   'chains and investment flows.'}},
                         {'_id': 'vec45',
                          '_score': 0.8309446573257446,
                          'fields': {'chunk_text': 'Corporate earnings in Q4 2024 '
                                                   'were largely impacted by '
                                                   'rising raw material costs and '
                                                   'currency fluctuations.'}},
                         {'_id': 'vec72',
                          '_score': 0.8275909423828125,
                          'fields': {'chunk_text': 'In early 2024, global GDP '
                                                   'growth slowed, driven by '
                                                   'weaker exports in Asia and '
                                                   'Europe.'}},
                         {'_id': 'vec29',
                          '_score': 0.8270887136459351,
                          'fields': {'chunk_text': 'Growth vs. value investing '
                                                   'strategies in 2024.'}},
                         {'_id': 'vec46',
                          '_score': 0.8263787627220154,
                          'fields': {'chunk_text': 'Economic recovery in Q2 2024 '
                                                   'relied heavily on government '
                                                   'spending in infrastructure and '
                                                   'green energy projects.'}},
                         {'_id': 'vec79',
                          '_score': 0.8258304595947266,
                          'fields': {'chunk_text': 'The resurgence of industrial '
                                                   'policy in Q1 2024 focused on '
                                                   'decoupling critical supply '
                                                   'chains.'}},
                         {'_id': 'vec87',
                          '_score': 0.8257324695587158,
                          'fields': {'chunk_text': "The U.S. labor market's "
                                                   'resilience in 2024 defied '
                                                   'predictions of a severe '
                                                   'recession.'}},
                         {'_id': 'vec40',
                          '_score': 0.8253997564315796,
                          'fields': {'chunk_text': 'Labor market trends show a '
                                                   'declining participation rate '
                                                   'despite record low '
                                                   'unemployment in 2024.'}},
                         {'_id': 'vec37',
                          '_score': 0.8235862255096436,
                          'fields': {'chunk_text': 'In Q3 2025 unemployment for '
                                                   'the prior year was revised to '
                                                   '2.2%'}},
                         {'_id': 'vec58',
                          '_score': 0.8233317136764526,
                          'fields': {'chunk_text': 'Oil production cuts in Q1 2024 '
                                                   'by OPEC nations drove prices '
                                                   'higher, influencing global '
                                                   'energy policies.'}},
                         {'_id': 'vec47',
                          '_score': 0.8231339454650879,
                          'fields': {'chunk_text': 'The housing market saw a '
                                                   'rebound in late 2024, driven '
                                                   'by falling mortgage rates and '
                                                   'pent-up demand.'}},
                         {'_id': 'vec41',
                          '_score': 0.8187897801399231,
                          'fields': {'chunk_text': 'Forecasts of global supply '
                                                   'chain disruptions eased in '
                                                   'late 2024, but consumer prices '
                                                   'remained elevated due to '
                                                   'persistent demand.'}},
                         {'_id': 'vec56',
                          '_score': 0.8155254125595093,
                          'fields': {'chunk_text': 'Consumer confidence indices '
                                                   'remained resilient in Q2 2024 '
                                                   'despite fears of an impending '
                                                   'recession.'}},
                         {'_id': 'vec63',
                          '_score': 0.8136948347091675,
                          'fields': {'chunk_text': 'Population aging emerged as a '
                                                   'critical economic issue in '
                                                   '2024, especially in advanced '
                                                   'economies.'}},
                         {'_id': 'vec52',
                          '_score': 0.8129132390022278,
                          'fields': {'chunk_text': 'Record-breaking weather events '
                                                   'in early 2024 have highlighted '
                                                   'the growing economic impact of '
                                                   'climate change.'}},
                         {'_id': 'vec23',
                          '_score': 0.8126378655433655,
                          'fields': {'chunk_text': 'Top SPAC mergers in the '
                                                   'technology sector for 2024.'}},
                         {'_id': 'vec62',
                          '_score': 0.8116977214813232,
                          'fields': {'chunk_text': 'Private equity activity in '
                                                   '2024 focused on renewable '
                                                   'energy and technology sectors '
                                                   'amid shifting investor '
                                                   'priorities.'}},
                         {'_id': 'vec64',
                          '_score': 0.8109902739524841,
                          'fields': {'chunk_text': 'Rising commodity prices in '
                                                   '2024 strained emerging markets '
                                                   'dependent on imports of raw '
                                                   'materials.'}},
                         {'_id': 'vec54',
                          '_score': 0.8092231154441833,
                          'fields': {'chunk_text': 'The global tourism sector '
                                                   'showed signs of recovery in '
                                                   'late 2024 after years of '
                                                   'pandemic-related setbacks.'}},
                         {'_id': 'vec96',
                          '_score': 0.8075559735298157,
                          'fields': {'chunk_text': 'New trade agreements signed '
                                                   '2022 will make an impact in '
                                                   '2024'}},
                         {'_id': 'vec49',
                          '_score': 0.8062589764595032,
                          'fields': {'chunk_text': "China's economic growth in "
                                                   '2024 slowed to its lowest '
                                                   'level in decades due to '
                                                   'structural reforms and weak '
                                                   'exports.'}},
                         {'_id': 'vec7',
                          '_score': 0.8034461140632629,
                          'fields': {'chunk_text': 'The CPI index rose by 6% in '
                                                   'July 2024, raising concerns '
                                                   'about purchasing power.'}},
                         {'_id': 'vec84',
                          '_score': 0.8027160167694092,
                          'fields': {'chunk_text': "The IMF's 2024 global outlook "
                                                   'highlighted risks of '
                                                   'stagflation in emerging '
                                                   'markets.'}},
                         {'_id': 'vec13',
                          '_score': 0.8010239601135254,
                          'fields': {'chunk_text': 'Credit card APRs reached an '
                                                   'all-time high of 22.8% in '
                                                   '2024.'}},
                         {'_id': 'vec53',
                          '_score': 0.8007135391235352,
                          'fields': {'chunk_text': 'Cryptocurrencies faced '
                                                   'regulatory scrutiny in 2024, '
                                                   'leading to volatility and '
                                                   'reduced market '
                                                   'capitalization.'}},
                         {'_id': 'vec60',
                          '_score': 0.7980866432189941,
                          'fields': {'chunk_text': 'Healthcare spending in 2024 '
                                                   'surged as governments expanded '
                                                   'access to preventive care and '
                                                   'pandemic preparedness.'}},
                         {'_id': 'vec91',
                          '_score': 0.7980680465698242,
                          'fields': {'chunk_text': 'The impact of ESG investing on '
                                                   'corporate strategies has been '
                                                   'a major focus in 2024.'}},
                         {'_id': 'vec68',
                          '_score': 0.797269880771637,
                          'fields': {'chunk_text': 'Cybersecurity spending reached '
                                                   'new highs in 2024, reflecting '
                                                   'the growing threat of digital '
                                                   'attacks on infrastructure.'}},
                         {'_id': 'vec59',
                          '_score': 0.795337438583374,
                          'fields': {'chunk_text': 'The adoption of digital '
                                                   'currencies by central banks '
                                                   'increased in 2024, reshaping '
                                                   'monetary policy frameworks.'}},
                         {'_id': 'vec39',
                          '_score': 0.793889045715332,
                          'fields': {'chunk_text': 'The rise in energy prices '
                                                   'significantly impacted '
                                                   'inflation trends during the '
                                                   'first half of 2024.'}},
                         {'_id': 'vec66',
                          '_score': 0.7919396162033081,
                          'fields': {'chunk_text': 'Bank lending to small and '
                                                   'medium-sized enterprises '
                                                   'surged in 2024 as governments '
                                                   'incentivized '
                                                   'entrepreneurship.'}},
                         {'_id': 'vec57',
                          '_score': 0.7917722463607788,
                          'fields': {'chunk_text': 'Startups in 2024 faced tighter '
                                                   'funding conditions as venture '
                                                   'capitalists focused on '
                                                   'profitability over growth.'}},
                         {'_id': 'vec75',
                          '_score': 0.7907494306564331,
                          'fields': {'chunk_text': 'The collapse of Silicon Valley '
                                                   'Bank raised questions about '
                                                   'regulatory oversight in '
                                                   '2024.'}},
                         {'_id': 'vec51',
                          '_score': 0.790622889995575,
                          'fields': {'chunk_text': 'The European Union introduced '
                                                   'new fiscal policies in 2024 '
                                                   'aimed at reducing public debt '
                                                   'without stifling growth.'}},
                         {'_id': 'vec89',
                          '_score': 0.7899052500724792,
                          'fields': {'chunk_text': 'Venture capital investments in '
                                                   '2024 leaned heavily toward AI '
                                                   'and automation startups.'}}]},
     'usage': {'embed_total_tokens': 12, 'read_units': 1}}
    ```
  </Step>

  <Step title="Search the sparse index">
    Perform a [lexical search](/guides/search/lexical-search).

    For example, the following code searches the sparse index for 40 records that most exactly match the words in the query. Again, because the index is integrated with an embedding model, you provide the query as text and Pinecone converts the text to a sparse vector automatically.

    ```python Python theme={null}
    sparse_results = sparse_index.search(
        namespace="example-namespace",
        query={
            "top_k": 40,
            "inputs": {
                "text": query
            }
        }
    )

    print(sparse_results)
    ```

    ```python Response [expandable] theme={null}
    {'result': {'hits': [{'_id': 'vec35',
                          '_score': 7.0625,
                          'fields': {'chunk_text': 'Unemployment hit at 2.4% in Q3 '
                                                   'of 2024.'}},
                         {'_id': 'vec46',
                          '_score': 7.041015625,
                          'fields': {'chunk_text': 'Economic recovery in Q2 2024 '
                                                   'relied heavily on government '
                                                   'spending in infrastructure and '
                                                   'green energy projects.'}},
                         {'_id': 'vec36',
                          '_score': 6.96875,
                          'fields': {'chunk_text': 'Unemployment is expected to '
                                                   'hit 2.5% in Q3 of 2024.'}},
                         {'_id': 'vec42',
                          '_score': 6.9609375,
                          'fields': {'chunk_text': 'Tech sector layoffs in Q3 2024 '
                                                   'have reshaped hiring trends '
                                                   'across high-growth '
                                                   'industries.'}},
                         {'_id': 'vec49',
                          '_score': 6.65625,
                          'fields': {'chunk_text': "China's economic growth in "
                                                   '2024 slowed to its lowest '
                                                   'level in decades due to '
                                                   'structural reforms and weak '
                                                   'exports.'}},
                         {'_id': 'vec63',
                          '_score': 6.4765625,
                          'fields': {'chunk_text': 'Population aging emerged as a '
                                                   'critical economic issue in '
                                                   '2024, especially in advanced '
                                                   'economies.'}},
                         {'_id': 'vec92',
                          '_score': 5.72265625,
                          'fields': {'chunk_text': 'Income inequality widened in '
                                                   '2024 despite strong economic '
                                                   'growth in developed nations.'}},
                         {'_id': 'vec52',
                          '_score': 5.599609375,
                          'fields': {'chunk_text': 'Record-breaking weather events '
                                                   'in early 2024 have highlighted '
                                                   'the growing economic impact of '
                                                   'climate change.'}},
                         {'_id': 'vec89',
                          '_score': 4.0078125,
                          'fields': {'chunk_text': 'Venture capital investments in '
                                                   '2024 leaned heavily toward AI '
                                                   'and automation startups.'}},
                         {'_id': 'vec62',
                          '_score': 3.99609375,
                          'fields': {'chunk_text': 'Private equity activity in '
                                                   '2024 focused on renewable '
                                                   'energy and technology sectors '
                                                   'amid shifting investor '
                                                   'priorities.'}},
                         {'_id': 'vec57',
                          '_score': 3.93359375,
                          'fields': {'chunk_text': 'Startups in 2024 faced tighter '
                                                   'funding conditions as venture '
                                                   'capitalists focused on '
                                                   'profitability over growth.'}},
                         {'_id': 'vec69',
                          '_score': 3.8984375,
                          'fields': {'chunk_text': 'The agricultural sector faced '
                                                   'challenges in 2024 due to '
                                                   'extreme weather and rising '
                                                   'input costs.'}},
                         {'_id': 'vec37',
                          '_score': 3.89453125,
                          'fields': {'chunk_text': 'In Q3 2025 unemployment for '
                                                   'the prior year was revised to '
                                                   '2.2%'}},
                         {'_id': 'vec60',
                          '_score': 3.822265625,
                          'fields': {'chunk_text': 'Healthcare spending in 2024 '
                                                   'surged as governments expanded '
                                                   'access to preventive care and '
                                                   'pandemic preparedness.'}},
                         {'_id': 'vec51',
                          '_score': 3.783203125,
                          'fields': {'chunk_text': 'The European Union introduced '
                                                   'new fiscal policies in 2024 '
                                                   'aimed at reducing public debt '
                                                   'without stifling growth.'}},
                         {'_id': 'vec55',
                          '_score': 3.765625,
                          'fields': {'chunk_text': 'Trade tensions between the '
                                                   'U.S. and China escalated in '
                                                   '2024, impacting global supply '
                                                   'chains and investment flows.'}},
                         {'_id': 'vec70',
                          '_score': 3.76171875,
                          'fields': {'chunk_text': 'Consumer spending patterns '
                                                   'shifted in 2024, with a '
                                                   'greater focus on experiences '
                                                   'over goods.'}},
                         {'_id': 'vec90',
                          '_score': 3.70703125,
                          'fields': {'chunk_text': 'The surge in e-commerce in '
                                                   '2024 was facilitated by '
                                                   'advancements in logistics '
                                                   'technology.'}},
                         {'_id': 'vec87',
                          '_score': 3.69140625,
                          'fields': {'chunk_text': "The U.S. labor market's "
                                                   'resilience in 2024 defied '
                                                   'predictions of a severe '
                                                   'recession.'}},
                         {'_id': 'vec78',
                          '_score': 3.673828125,
                          'fields': {'chunk_text': 'Consumer sentiment surveys in '
                                                   '2024 reflected optimism '
                                                   'despite high interest rates.'}},
                         {'_id': 'vec82',
                          '_score': 3.66015625,
                          'fields': {'chunk_text': 'Renewable energy subsidies in '
                                                   '2024 reduced the global '
                                                   'reliance on fossil fuels.'}},
                         {'_id': 'vec53',
                          '_score': 3.642578125,
                          'fields': {'chunk_text': 'Cryptocurrencies faced '
                                                   'regulatory scrutiny in 2024, '
                                                   'leading to volatility and '
                                                   'reduced market '
                                                   'capitalization.'}},
                         {'_id': 'vec94',
                          '_score': 3.625,
                          'fields': {'chunk_text': 'Cyberattacks targeting '
                                                   'financial institutions in 2024 '
                                                   'led to record cybersecurity '
                                                   'spending.'}},
                         {'_id': 'vec45',
                          '_score': 3.607421875,
                          'fields': {'chunk_text': 'Corporate earnings in Q4 2024 '
                                                   'were largely impacted by '
                                                   'rising raw material costs and '
                                                   'currency fluctuations.'}},
                         {'_id': 'vec47',
                          '_score': 3.576171875,
                          'fields': {'chunk_text': 'The housing market saw a '
                                                   'rebound in late 2024, driven '
                                                   'by falling mortgage rates and '
                                                   'pent-up demand.'}},
                         {'_id': 'vec84',
                          '_score': 3.5703125,
                          'fields': {'chunk_text': "The IMF's 2024 global outlook "
                                                   'highlighted risks of '
                                                   'stagflation in emerging '
                                                   'markets.'}},
                         {'_id': 'vec41',
                          '_score': 3.5546875,
                          'fields': {'chunk_text': 'Forecasts of global supply '
                                                   'chain disruptions eased in '
                                                   'late 2024, but consumer prices '
                                                   'remained elevated due to '
                                                   'persistent demand.'}},
                         {'_id': 'vec65',
                          '_score': 3.537109375,
                          'fields': {'chunk_text': 'The global shipping industry '
                                                   'experienced declining freight '
                                                   'rates in 2024 due to '
                                                   'overcapacity and reduced '
                                                   'demand.'}},
                         {'_id': 'vec96',
                          '_score': 3.53125,
                          'fields': {'chunk_text': 'New trade agreements signed '
                                                   '2022 will make an impact in '
                                                   '2024'}},
                         {'_id': 'vec86',
                          '_score': 3.52734375,
                          'fields': {'chunk_text': 'Digital transformation '
                                                   'initiatives in 2024 drove '
                                                   'productivity gains in the '
                                                   'services sector.'}},
                         {'_id': 'vec95',
                          '_score': 3.5234375,
                          'fields': {'chunk_text': 'Automation in agriculture in '
                                                   '2024 increased yields but '
                                                   'displaced rural workers.'}},
                         {'_id': 'vec64',
                          '_score': 3.51171875,
                          'fields': {'chunk_text': 'Rising commodity prices in '
                                                   '2024 strained emerging markets '
                                                   'dependent on imports of raw '
                                                   'materials.'}},
                         {'_id': 'vec79',
                          '_score': 3.51171875,
                          'fields': {'chunk_text': 'The resurgence of industrial '
                                                   'policy in Q1 2024 focused on '
                                                   'decoupling critical supply '
                                                   'chains.'}},
                         {'_id': 'vec66',
                          '_score': 3.48046875,
                          'fields': {'chunk_text': 'Bank lending to small and '
                                                   'medium-sized enterprises '
                                                   'surged in 2024 as governments '
                                                   'incentivized '
                                                   'entrepreneurship.'}},
                         {'_id': 'vec6',
                          '_score': 3.4765625,
                          'fields': {'chunk_text': 'Unemployment hit a record low '
                                                   'of 3.7% in Q4 of 2024.'}},
                         {'_id': 'vec58',
                          '_score': 3.39453125,
                          'fields': {'chunk_text': 'Oil production cuts in Q1 2024 '
                                                   'by OPEC nations drove prices '
                                                   'higher, influencing global '
                                                   'energy policies.'}},
                         {'_id': 'vec80',
                          '_score': 3.390625,
                          'fields': {'chunk_text': 'Technological innovation in '
                                                   'the fintech sector disrupted '
                                                   'traditional banking in 2024.'}},
                         {'_id': 'vec75',
                          '_score': 3.37109375,
                          'fields': {'chunk_text': 'The collapse of Silicon Valley '
                                                   'Bank raised questions about '
                                                   'regulatory oversight in '
                                                   '2024.'}},
                         {'_id': 'vec67',
                          '_score': 3.357421875,
                          'fields': {'chunk_text': 'Renewable energy projects '
                                                   'accounted for a record share '
                                                   'of global infrastructure '
                                                   'investment in 2024.'}},
                         {'_id': 'vec56',
                          '_score': 3.341796875,
                          'fields': {'chunk_text': 'Consumer confidence indices '
                                                   'remained resilient in Q2 2024 '
                                                   'despite fears of an impending '
                                                   'recession.'}}]},
     'usage': {'embed_total_tokens': 9, 'read_units': 1}}
    ```
  </Step>

  <Step title="Merge and deduplicate the results">
    Merge the 40 dense and 40 sparse results and deduplicated them based on the field you used to link sparse and dense vectors.

    For example, the following code merges and deduplicates the results based on the `_id` field, resulting in 52 unique results.

    ```python Python theme={null}
    def merge_chunks(h1, h2):
        """Get the unique hits from two search results and return them as single array of {'_id', 'chunk_text'} dicts, printing each dict on a new line."""
        # Deduplicate by _id
        deduped_hits = {hit['_id']: hit for hit in h1['result']['hits'] + h2['result']['hits']}.values()
        # Sort by _score descending
        sorted_hits = sorted(deduped_hits, key=lambda x: x['_score'], reverse=True)
        # Transform to format for reranking
        result = [{'_id': hit['_id'], 'chunk_text': hit['fields']['chunk_text']} for hit in sorted_hits]
        return result

    merged_results = merge_chunks(sparse_results, dense_results)

    print('[\n   ' + ',\n   '.join(str(obj) for obj in merged_results) + '\n]')
    ```

    ```console Response [expandable] theme={null}
    [
       {'_id': 'vec92', 'chunk_text': 'Income inequality widened in 2024 despite strong economic growth in developed nations.'},
       {'_id': 'vec69', 'chunk_text': 'The agricultural sector faced challenges in 2024 due to extreme weather and rising input costs.'},
       {'_id': 'vec70', 'chunk_text': 'Consumer spending patterns shifted in 2024, with a greater focus on experiences over goods.'},
       {'_id': 'vec90', 'chunk_text': 'The surge in e-commerce in 2024 was facilitated by advancements in logistics technology.'},
       {'_id': 'vec78', 'chunk_text': 'Consumer sentiment surveys in 2024 reflected optimism despite high interest rates.'},
       {'_id': 'vec82', 'chunk_text': 'Renewable energy subsidies in 2024 reduced the global reliance on fossil fuels.'},
       {'_id': 'vec94', 'chunk_text': 'Cyberattacks targeting financial institutions in 2024 led to record cybersecurity spending.'},
       {'_id': 'vec65', 'chunk_text': 'The global shipping industry experienced declining freight rates in 2024 due to overcapacity and reduced demand.'},
       {'_id': 'vec86', 'chunk_text': 'Digital transformation initiatives in 2024 drove productivity gains in the services sector.'},
       {'_id': 'vec95', 'chunk_text': 'Automation in agriculture in 2024 increased yields but displaced rural workers.'},
       {'_id': 'vec80', 'chunk_text': 'Technological innovation in the fintech sector disrupted traditional banking in 2024.'},
       {'_id': 'vec67', 'chunk_text': 'Renewable energy projects accounted for a record share of global infrastructure investment in 2024.'},
       {'_id': 'vec35', 'chunk_text': 'Unemployment hit at 2.4% in Q3 of 2024.'},
       {'_id': 'vec36', 'chunk_text': 'Unemployment is expected to hit 2.5% in Q3 of 2024.'},
       {'_id': 'vec6', 'chunk_text': 'Unemployment hit a record low of 3.7% in Q4 of 2024.'},
       {'_id': 'vec42', 'chunk_text': 'Tech sector layoffs in Q3 2024 have reshaped hiring trends across high-growth industries.'},
       {'_id': 'vec48', 'chunk_text': 'Wage growth outpaced inflation for the first time in years, signaling improved purchasing power in 2024.'},
       {'_id': 'vec55', 'chunk_text': 'Trade tensions between the U.S. and China escalated in 2024, impacting global supply chains and investment flows.'},
       {'_id': 'vec45', 'chunk_text': 'Corporate earnings in Q4 2024 were largely impacted by rising raw material costs and currency fluctuations.'},
       {'_id': 'vec72', 'chunk_text': 'In early 2024, global GDP growth slowed, driven by weaker exports in Asia and Europe.'},
       {'_id': 'vec29', 'chunk_text': 'Growth vs. value investing strategies in 2024.'},
       {'_id': 'vec46', 'chunk_text': 'Economic recovery in Q2 2024 relied heavily on government spending in infrastructure and green energy projects.'},
       {'_id': 'vec79', 'chunk_text': 'The resurgence of industrial policy in Q1 2024 focused on decoupling critical supply chains.'},
       {'_id': 'vec87', 'chunk_text': "The U.S. labor market's resilience in 2024 defied predictions of a severe recession."},
       {'_id': 'vec40', 'chunk_text': 'Labor market trends show a declining participation rate despite record low unemployment in 2024.'},
       {'_id': 'vec37', 'chunk_text': 'In Q3 2025 unemployment for the prior year was revised to 2.2%'},
       {'_id': 'vec58', 'chunk_text': 'Oil production cuts in Q1 2024 by OPEC nations drove prices higher, influencing global energy policies.'},
       {'_id': 'vec47', 'chunk_text': 'The housing market saw a rebound in late 2024, driven by falling mortgage rates and pent-up demand.'},
       {'_id': 'vec41', 'chunk_text': 'Forecasts of global supply chain disruptions eased in late 2024, but consumer prices remained elevated due to persistent demand.'},
       {'_id': 'vec56', 'chunk_text': 'Consumer confidence indices remained resilient in Q2 2024 despite fears of an impending recession.'},
       {'_id': 'vec63', 'chunk_text': 'Population aging emerged as a critical economic issue in 2024, especially in advanced economies.'},
       {'_id': 'vec52', 'chunk_text': 'Record-breaking weather events in early 2024 have highlighted the growing economic impact of climate change.'},
       {'_id': 'vec23', 'chunk_text': 'Top SPAC mergers in the technology sector for 2024.'},
       {'_id': 'vec62', 'chunk_text': 'Private equity activity in 2024 focused on renewable energy and technology sectors amid shifting investor priorities.'},
       {'_id': 'vec64', 'chunk_text': 'Rising commodity prices in 2024 strained emerging markets dependent on imports of raw materials.'},
       {'_id': 'vec54', 'chunk_text': 'The global tourism sector showed signs of recovery in late 2024 after years of pandemic-related setbacks.'},
       {'_id': 'vec96', 'chunk_text': 'New trade agreements signed 2022 will make an impact in 2024'},
       {'_id': 'vec49', 'chunk_text': "China's economic growth in 2024 slowed to its lowest level in decades due to structural reforms and weak exports."},
       {'_id': 'vec7', 'chunk_text': 'The CPI index rose by 6% in July 2024, raising concerns about purchasing power.'},
       {'_id': 'vec84', 'chunk_text': "The IMF's 2024 global outlook highlighted risks of stagflation in emerging markets."},
       {'_id': 'vec13', 'chunk_text': 'Credit card APRs reached an all-time high of 22.8% in 2024.'},
       {'_id': 'vec53', 'chunk_text': 'Cryptocurrencies faced regulatory scrutiny in 2024, leading to volatility and reduced market capitalization.'},
       {'_id': 'vec60', 'chunk_text': 'Healthcare spending in 2024 surged as governments expanded access to preventive care and pandemic preparedness.'},
       {'_id': 'vec91', 'chunk_text': 'The impact of ESG investing on corporate strategies has been a major focus in 2024.'},
       {'_id': 'vec68', 'chunk_text': 'Cybersecurity spending reached new highs in 2024, reflecting the growing threat of digital attacks on infrastructure.'},
       {'_id': 'vec59', 'chunk_text': 'The adoption of digital currencies by central banks increased in 2024, reshaping monetary policy frameworks.'},
       {'_id': 'vec39', 'chunk_text': 'The rise in energy prices significantly impacted inflation trends during the first half of 2024.'},
       {'_id': 'vec66', 'chunk_text': 'Bank lending to small and medium-sized enterprises surged in 2024 as governments incentivized entrepreneurship.'},
       {'_id': 'vec57', 'chunk_text': 'Startups in 2024 faced tighter funding conditions as venture capitalists focused on profitability over growth.'},
       {'_id': 'vec75', 'chunk_text': 'The collapse of Silicon Valley Bank raised questions about regulatory oversight in 2024.'},
       {'_id': 'vec51', 'chunk_text': 'The European Union introduced new fiscal policies in 2024 aimed at reducing public debt without stifling growth.'},
       {'_id': 'vec89', 'chunk_text': 'Venture capital investments in 2024 leaned heavily toward AI and automation startups.'}
    ]
    ```
  </Step>

  <Step title="Rerank the results">
    Use one of Pinecone's [hosted reranking models](/guides/search/rerank-results#reranking-models) to rerank the merged and deduplicated results based on a unified relevance score and then return a smaller set of the most highly relevant results.

    For example, the following code sends the 52 unique results from the last step to the `bge-reranker-v2-m3` reranking model and returns the top 10 most relevant results.

    ```python Python theme={null}
    result = pc.inference.rerank(
        model="bge-reranker-v2-m3",
        query=query,
        documents=merged_results,
        rank_fields=["chunk_text"],
        top_n=10,
        return_documents=True,
        parameters={
            "truncate": "END"
        }
    )

    print("Query", query)
    print('-----')
    for row in result.data:
        print(f"{row['document']['_id']} - {round(row['score'], 2)} - {row['document']['chunk_text']}")
    ```

    ```console Response [expandable] theme={null}
    Query Q3 2024 us economic data
    -----
    vec36 - 0.84 - Unemployment is expected to hit 2.5% in Q3 of 2024.
    vec35 - 0.76 - Unemployment hit at 2.4% in Q3 of 2024.
    vec48 - 0.33 - Wage growth outpaced inflation for the first time in years, signaling improved purchasing power in 2024.
    vec37 - 0.25 - In Q3 2025 unemployment for the prior year was revised to 2.2%
    vec42 - 0.21 - Tech sector layoffs in Q3 2024 have reshaped hiring trends across high-growth industries.
    vec87 - 0.2 - The U.S. labor market's resilience in 2024 defied predictions of a severe recession.
    vec63 - 0.08 - Population aging emerged as a critical economic issue in 2024, especially in advanced economies.
    vec92 - 0.08 - Income inequality widened in 2024 despite strong economic growth in developed nations.
    vec72 - 0.07 - In early 2024, global GDP growth slowed, driven by weaker exports in Asia and Europe.
    vec46 - 0.06 - Economic recovery in Q2 2024 relied heavily on government spending in infrastructure and green energy projects.
    ```
  </Step>
</Steps>

## Use a single hybrid index

You can perform hybrid search with a single hybrid index as follows:

<Steps>
  <Step title="Create a hybrid index">
    To store both dense and sparse vectors in a single index, use the [`create_index`](/reference/api/latest/control-plane/create_index) operation, setting the `vector_type` to `dense` and the `metric` to `dotproduct`. This is the only combination that supports dense/sparse search on a single index.

    ```python Python theme={null}
    from pinecone.grpc import PineconeGRPC as Pinecone
    from pinecone import ServerlessSpec

    pc = Pinecone(api_key="YOUR_API_KEY")

    index_name = "hybrid-index"

    if not pc.has_index(index_name):
        pc.create_index(
            name=index_name,
            vector_type="dense",
            dimension=1024,
            metric="dotproduct",
            spec=ServerlessSpec(
                cloud="aws",
                region="us-east-1"
            )
        )
    ```
  </Step>

  <Step title="Generate vectors">
    Use Pinecone's [hosted embedding models](/guides/index-data/create-an-index#embedding-models) to [convert data into dense and sparse vectors](/reference/api/latest/inference/generate-embeddings).

    ```python Python [expandable] theme={null}
    # Define the records
    data = [
        { "_id": "vec1", "chunk_text": "Apple Inc. issued a $10 billion corporate bond in 2023." },
        { "_id": "vec2", "chunk_text": "ETFs tracking the S&P 500 outperformed active funds last year." },
        { "_id": "vec3", "chunk_text": "Tesla's options volume surged after the latest earnings report." },
        { "_id": "vec4", "chunk_text": "Dividend aristocrats are known for consistently raising payouts." },
        { "_id": "vec5", "chunk_text": "The Federal Reserve raised interest rates by 0.25% to curb inflation." },
        { "_id": "vec6", "chunk_text": "Unemployment hit a record low of 3.7% in Q4 of 2024." },
        { "_id": "vec7", "chunk_text": "The CPI index rose by 6% in July 2024, raising concerns about purchasing power." },
        { "_id": "vec8", "chunk_text": "GDP growth in emerging markets outpaced developed economies." },
        { "_id": "vec9", "chunk_text": "Amazon's acquisition of MGM Studios was valued at $8.45 billion." },
        { "_id": "vec10", "chunk_text": "Alphabet reported a 20% increase in advertising revenue." },
        { "_id": "vec11", "chunk_text": "ExxonMobil announced a special dividend after record profits." },
        { "_id": "vec12", "chunk_text": "Tesla plans a 3-for-1 stock split to attract retail investors." },
        { "_id": "vec13", "chunk_text": "Credit card APRs reached an all-time high of 22.8% in 2024." },
        { "_id": "vec14", "chunk_text": "A 529 college savings plan offers tax advantages for education." },
        { "_id": "vec15", "chunk_text": "Emergency savings should ideally cover 6 months of expenses." },
        { "_id": "vec16", "chunk_text": "The average mortgage rate rose to 7.1% in December." },
        { "_id": "vec17", "chunk_text": "The SEC fined a hedge fund $50 million for insider trading." },
        { "_id": "vec18", "chunk_text": "New ESG regulations require companies to disclose climate risks." },
        { "_id": "vec19", "chunk_text": "The IRS introduced a new tax bracket for high earners." },
        { "_id": "vec20", "chunk_text": "Compliance with GDPR is mandatory for companies operating in Europe." },
        { "_id": "vec21", "chunk_text": "What are the best-performing green bonds in a rising rate environment?" },
        { "_id": "vec22", "chunk_text": "How does inflation impact the real yield of Treasury bonds?" },
        { "_id": "vec23", "chunk_text": "Top SPAC mergers in the technology sector for 2024." },
        { "_id": "vec24", "chunk_text": "Are stablecoins a viable hedge against currency devaluation?" },
        { "_id": "vec25", "chunk_text": "Comparison of Roth IRA vs 401(k) for high-income earners." },
        { "_id": "vec26", "chunk_text": "Stock splits and their effect on investor sentiment." },
        { "_id": "vec27", "chunk_text": "Tech IPOs that disappointed in their first year." },
        { "_id": "vec28", "chunk_text": "Impact of interest rate hikes on bank stocks." },
        { "_id": "vec29", "chunk_text": "Growth vs. value investing strategies in 2024." },
        { "_id": "vec30", "chunk_text": "The role of artificial intelligence in quantitative trading." },
        { "_id": "vec31", "chunk_text": "What are the implications of quantitative tightening on equities?" },
        { "_id": "vec32", "chunk_text": "How does compounding interest affect long-term investments?" },
        { "_id": "vec33", "chunk_text": "What are the best assets to hedge against inflation?" },
        { "_id": "vec34", "chunk_text": "Can ETFs provide better diversification than mutual funds?" },
        { "_id": "vec35", "chunk_text": "Unemployment hit at 2.4% in Q3 of 2024." },
        { "_id": "vec36", "chunk_text": "Unemployment is expected to hit 2.5% in Q3 of 2024." },
        { "_id": "vec37", "chunk_text": "In Q3 2025 unemployment for the prior year was revised to 2.2%"},
        { "_id": "vec38", "chunk_text": "Emerging markets witnessed increased foreign direct investment as global interest rates stabilized." },
        { "_id": "vec39", "chunk_text": "The rise in energy prices significantly impacted inflation trends during the first half of 2024." },
        { "_id": "vec40", "chunk_text": "Labor market trends show a declining participation rate despite record low unemployment in 2024." },
        { "_id": "vec41", "chunk_text": "Forecasts of global supply chain disruptions eased in late 2024, but consumer prices remained elevated due to persistent demand." },
        { "_id": "vec42", "chunk_text": "Tech sector layoffs in Q3 2024 have reshaped hiring trends across high-growth industries." },
        { "_id": "vec43", "chunk_text": "The U.S. dollar weakened against a basket of currencies as the global economy adjusted to shifting trade balances." },
        { "_id": "vec44", "chunk_text": "Central banks worldwide increased gold reserves to hedge against geopolitical and economic instability." },
        { "_id": "vec45", "chunk_text": "Corporate earnings in Q4 2024 were largely impacted by rising raw material costs and currency fluctuations." },
        { "_id": "vec46", "chunk_text": "Economic recovery in Q2 2024 relied heavily on government spending in infrastructure and green energy projects." },
        { "_id": "vec47", "chunk_text": "The housing market saw a rebound in late 2024, driven by falling mortgage rates and pent-up demand." },
        { "_id": "vec48", "chunk_text": "Wage growth outpaced inflation for the first time in years, signaling improved purchasing power in 2024." },
        { "_id": "vec49", "chunk_text": "China's economic growth in 2024 slowed to its lowest level in decades due to structural reforms and weak exports." },
        { "_id": "vec50", "chunk_text": "AI-driven automation in the manufacturing sector boosted productivity but raised concerns about job displacement." },
        { "_id": "vec51", "chunk_text": "The European Union introduced new fiscal policies in 2024 aimed at reducing public debt without stifling growth." },
        { "_id": "vec52", "chunk_text": "Record-breaking weather events in early 2024 have highlighted the growing economic impact of climate change." },
        { "_id": "vec53", "chunk_text": "Cryptocurrencies faced regulatory scrutiny in 2024, leading to volatility and reduced market capitalization." },
        { "_id": "vec54", "chunk_text": "The global tourism sector showed signs of recovery in late 2024 after years of pandemic-related setbacks." },
        { "_id": "vec55", "chunk_text": "Trade tensions between the U.S. and China escalated in 2024, impacting global supply chains and investment flows." },
        { "_id": "vec56", "chunk_text": "Consumer confidence indices remained resilient in Q2 2024 despite fears of an impending recession." },
        { "_id": "vec57", "chunk_text": "Startups in 2024 faced tighter funding conditions as venture capitalists focused on profitability over growth." },
        { "_id": "vec58", "chunk_text": "Oil production cuts in Q1 2024 by OPEC nations drove prices higher, influencing global energy policies." },
        { "_id": "vec59", "chunk_text": "The adoption of digital currencies by central banks increased in 2024, reshaping monetary policy frameworks." },
        { "_id": "vec60", "chunk_text": "Healthcare spending in 2024 surged as governments expanded access to preventive care and pandemic preparedness." },
        { "_id": "vec61", "chunk_text": "The World Bank reported declining poverty rates globally, but regional disparities persisted." },
        { "_id": "vec62", "chunk_text": "Private equity activity in 2024 focused on renewable energy and technology sectors amid shifting investor priorities." },
        { "_id": "vec63", "chunk_text": "Population aging emerged as a critical economic issue in 2024, especially in advanced economies." },
        { "_id": "vec64", "chunk_text": "Rising commodity prices in 2024 strained emerging markets dependent on imports of raw materials." },
        { "_id": "vec65", "chunk_text": "The global shipping industry experienced declining freight rates in 2024 due to overcapacity and reduced demand." },
        { "_id": "vec66", "chunk_text": "Bank lending to small and medium-sized enterprises surged in 2024 as governments incentivized entrepreneurship." },
        { "_id": "vec67", "chunk_text": "Renewable energy projects accounted for a record share of global infrastructure investment in 2024." },
        { "_id": "vec68", "chunk_text": "Cybersecurity spending reached new highs in 2024, reflecting the growing threat of digital attacks on infrastructure." },
        { "_id": "vec69", "chunk_text": "The agricultural sector faced challenges in 2024 due to extreme weather and rising input costs." },
        { "_id": "vec70", "chunk_text": "Consumer spending patterns shifted in 2024, with a greater focus on experiences over goods." },
        { "_id": "vec71", "chunk_text": "The economic impact of the 2008 financial crisis was mitigated by quantitative easing policies." },
        { "_id": "vec72", "chunk_text": "In early 2024, global GDP growth slowed, driven by weaker exports in Asia and Europe." },
        { "_id": "vec73", "chunk_text": "The historical relationship between inflation and unemployment is explained by the Phillips Curve." },
        { "_id": "vec74", "chunk_text": "The World Trade Organization's role in resolving disputes was tested in 2024." },
        { "_id": "vec75", "chunk_text": "The collapse of Silicon Valley Bank raised questions about regulatory oversight in 2024." },
        { "_id": "vec76", "chunk_text": "The cost of living crisis has been exacerbated by stagnant wage growth and rising inflation." },
        { "_id": "vec77", "chunk_text": "Supply chain resilience became a top priority for multinational corporations in 2024." },
        { "_id": "vec78", "chunk_text": "Consumer sentiment surveys in 2024 reflected optimism despite high interest rates." },
        { "_id": "vec79", "chunk_text": "The resurgence of industrial policy in Q1 2024 focused on decoupling critical supply chains." },
        { "_id": "vec80", "chunk_text": "Technological innovation in the fintech sector disrupted traditional banking in 2024." },
        { "_id": "vec81", "chunk_text": "The link between climate change and migration patterns is increasingly recognized." },
        { "_id": "vec82", "chunk_text": "Renewable energy subsidies in 2024 reduced the global reliance on fossil fuels." },
        { "_id": "vec83", "chunk_text": "The economic fallout of geopolitical tensions was evident in rising defense budgets worldwide." },
        { "_id": "vec84", "chunk_text": "The IMF's 2024 global outlook highlighted risks of stagflation in emerging markets." },
        { "_id": "vec85", "chunk_text": "Declining birth rates in advanced economies pose long-term challenges for labor markets." },
        { "_id": "vec86", "chunk_text": "Digital transformation initiatives in 2024 drove productivity gains in the services sector." },
        { "_id": "vec87", "chunk_text": "The U.S. labor market's resilience in 2024 defied predictions of a severe recession." },
        { "_id": "vec88", "chunk_text": "New fiscal measures in the European Union aimed to stabilize debt levels post-pandemic." },
        { "_id": "vec89", "chunk_text": "Venture capital investments in 2024 leaned heavily toward AI and automation startups." },
        { "_id": "vec90", "chunk_text": "The surge in e-commerce in 2024 was facilitated by advancements in logistics technology." },
        { "_id": "vec91", "chunk_text": "The impact of ESG investing on corporate strategies has been a major focus in 2024." },
        { "_id": "vec92", "chunk_text": "Income inequality widened in 2024 despite strong economic growth in developed nations." },
        { "_id": "vec93", "chunk_text": "The collapse of FTX highlighted the volatility and risks associated with cryptocurrencies." },
        { "_id": "vec94", "chunk_text": "Cyberattacks targeting financial institutions in 2024 led to record cybersecurity spending." },
        { "_id": "vec95", "chunk_text": "Automation in agriculture in 2024 increased yields but displaced rural workers." },
        { "_id": "vec96", "chunk_text": "New trade agreements signed 2022 will make an impact in 2024"},
    ]
    ```

    ```python Python theme={null}
    # Convert the chunk_text into dense vectors
    dense_embeddings = pc.inference.embed(
        model="llama-text-embed-v2",
        inputs=[d['chunk_text'] for d in data],
        parameters={"input_type": "passage", "truncate": "END"}
    )

    # Convert the chunk_text into sparse vectors
    sparse_embeddings = pc.inference.embed(
        model="pinecone-sparse-english-v0",
        inputs=[d['chunk_text'] for d in data],
        parameters={"input_type": "passage", "truncate": "END"}
    )
    ```
  </Step>

  <Step title="Upsert records with dense and sparse vectors">
    Use the [`upsert`](/reference/api/latest/data-plane/upsert) operation, specifying dense values in the `value` parameter and sparse values in the `sparse_values` parameter.

    <Note>
      Only dense indexes using the [dotproduct distance metric](/guides/index-data/indexing-overview#dotproduct) support dense and sparse vectors. Upserting records with dense and sparse vectors into dense indexes with a different distance metric will succeed, but querying will return an error.
    </Note>

    ```Python Python theme={null}
    # Target the hybrid index
    # To get the unique host for an index, 
    # see https://docs.pinecone.io/guides/manage-data/target-an-index
    index = pc.Index(host="INDEX_HOST")

    # Each record contains an ID, a dense vector, a sparse vector, and the original text as metadata
    records = []
    for d, de, se in zip(data, dense_embeddings, sparse_embeddings):
        records.append({
            "id": d['_id'],
            "values": de['values'],
            "sparse_values": {'indices': se['sparse_indices'], 'values': se['sparse_values']},
            "metadata": {'text': d['chunk_text']}
        })

    # Upsert the records into the hybrid index
    index.upsert(
        vectors=records,
        namespace="example-namespace"
    )
    ```
  </Step>

  <Step title="Search the hybrid index">
    Use the [`embed`](/reference/api/latest/inference/generate-embeddings) operation to convert your query into a dense vector and a sparse vector, and then use the [`query`](/reference/api/latest/data-plane/query) operation to search the hybrid index for the 40 most relevant records.

    ```Python Python theme={null}
    query = "Q3 2024 us economic data"

    # Convert the query into a dense vector
    dense_query_embedding = pc.inference.embed(
        model="llama-text-embed-v2",
        inputs=query,
        parameters={"input_type": "query", "truncate": "END"}
    )

    # Convert the query into a sparse vector
    sparse_query_embedding = pc.inference.embed(
        model="pinecone-sparse-english-v0",
        inputs=query,
        parameters={"input_type": "query", "truncate": "END"}
    )

    for d, s in zip(dense_query_embedding, sparse_query_embedding):
        query_response = index.query(
            namespace="example-namespace",
            top_k=40,
            vector=d['values'],
            sparse_vector={'indices': s['sparse_indices'], 'values': s['sparse_values']},
            include_values=False,
            include_metadata=True
        )
        print(query_response)
    ```

    ```python Response [expandable] theme={null}
    {'matches': [{'id': 'vec35',
                  'metadata': {'text': 'Unemployment hit at 2.4% in Q3 of 2024.'},
                  'score': 7.92519569,
                  'values': []},
                 {'id': 'vec46',
                  'metadata': {'text': 'Economic recovery in Q2 2024 relied '
                                       'heavily on government spending in '
                                       'infrastructure and green energy projects.'},
                  'score': 7.86733627,
                  'values': []},
                 {'id': 'vec36',
                  'metadata': {'text': 'Unemployment is expected to hit 2.5% in Q3 '
                                       'of 2024.'},
                  'score': 7.82636,
                  'values': []},
                 {'id': 'vec42',
                  'metadata': {'text': 'Tech sector layoffs in Q3 2024 have '
                                       'reshaped hiring trends across high-growth '
                                       'industries.'},
                  'score': 7.79465914,
                  'values': []},
                 {'id': 'vec49',
                  'metadata': {'text': "China's economic growth in 2024 slowed to "
                                       'its lowest level in decades due to '
                                       'structural reforms and weak exports.'},
                  'score': 7.46323156,
                  'values': []},
                 {'id': 'vec63',
                  'metadata': {'text': 'Population aging emerged as a critical '
                                       'economic issue in 2024, especially in '
                                       'advanced economies.'},
                  'score': 7.29055929,
                  'values': []},
                 {'id': 'vec92',
                  'metadata': {'text': 'Income inequality widened in 2024 despite '
                                       'strong economic growth in developed '
                                       'nations.'},
                  'score': 6.51210213,
                  'values': []},
                 {'id': 'vec52',
                  'metadata': {'text': 'Record-breaking weather events in early '
                                       '2024 have highlighted the growing economic '
                                       'impact of climate change.'},
                  'score': 6.4125514,
                  'values': []},
                 {'id': 'vec62',
                  'metadata': {'text': 'Private equity activity in 2024 focused on '
                                       'renewable energy and technology sectors '
                                       'amid shifting investor priorities.'},
                  'score': 4.8084693,
                  'values': []},
                 {'id': 'vec89',
                  'metadata': {'text': 'Venture capital investments in 2024 leaned '
                                       'heavily toward AI and automation '
                                       'startups.'},
                  'score': 4.7974205,
                  'values': []},
                 {'id': 'vec57',
                  'metadata': {'text': 'Startups in 2024 faced tighter funding '
                                       'conditions as venture capitalists focused '
                                       'on profitability over growth.'},
                  'score': 4.72518444,
                  'values': []},
                 {'id': 'vec37',
                  'metadata': {'text': 'In Q3 2025 unemployment for the prior year '
                                       'was revised to 2.2%'},
                  'score': 4.71824408,
                  'values': []},
                 {'id': 'vec69',
                  'metadata': {'text': 'The agricultural sector faced challenges '
                                       'in 2024 due to extreme weather and rising '
                                       'input costs.'},
                  'score': 4.66726208,
                  'values': []},
                 {'id': 'vec60',
                  'metadata': {'text': 'Healthcare spending in 2024 surged as '
                                       'governments expanded access to preventive '
                                       'care and pandemic preparedness.'},
                  'score': 4.62045908,
                  'values': []},
                 {'id': 'vec55',
                  'metadata': {'text': 'Trade tensions between the U.S. and China '
                                       'escalated in 2024, impacting global supply '
                                       'chains and investment flows.'},
                  'score': 4.59764862,
                  'values': []},
                 {'id': 'vec51',
                  'metadata': {'text': 'The European Union introduced new fiscal '
                                       'policies in 2024 aimed at reducing public '
                                       'debt without stifling growth.'},
                  'score': 4.57397079,
                  'values': []},
                 {'id': 'vec70',
                  'metadata': {'text': 'Consumer spending patterns shifted in '
                                       '2024, with a greater focus on experiences '
                                       'over goods.'},
                  'score': 4.55043507,
                  'values': []},
                 {'id': 'vec87',
                  'metadata': {'text': "The U.S. labor market's resilience in 2024 "
                                       'defied predictions of a severe recession.'},
                  'score': 4.51785707,
                  'values': []},
                 {'id': 'vec90',
                  'metadata': {'text': 'The surge in e-commerce in 2024 was '
                                       'facilitated by advancements in logistics '
                                       'technology.'},
                  'score': 4.47754288,
                  'values': []},
                 {'id': 'vec78',
                  'metadata': {'text': 'Consumer sentiment surveys in 2024 '
                                       'reflected optimism despite high interest '
                                       'rates.'},
                  'score': 4.46246624,
                  'values': []},
                 {'id': 'vec53',
                  'metadata': {'text': 'Cryptocurrencies faced regulatory scrutiny '
                                       'in 2024, leading to volatility and reduced '
                                       'market capitalization.'},
                  'score': 4.4435873,
                  'values': []},
                 {'id': 'vec45',
                  'metadata': {'text': 'Corporate earnings in Q4 2024 were largely '
                                       'impacted by rising raw material costs and '
                                       'currency fluctuations.'},
                  'score': 4.43836403,
                  'values': []},
                 {'id': 'vec82',
                  'metadata': {'text': 'Renewable energy subsidies in 2024 reduced '
                                       'the global reliance on fossil fuels.'},
                  'score': 4.43601322,
                  'values': []},
                 {'id': 'vec94',
                  'metadata': {'text': 'Cyberattacks targeting financial '
                                       'institutions in 2024 led to record '
                                       'cybersecurity spending.'},
                  'score': 4.41334057,
                  'values': []},
                 {'id': 'vec47',
                  'metadata': {'text': 'The housing market saw a rebound in late '
                                       '2024, driven by falling mortgage rates and '
                                       'pent-up demand.'},
                  'score': 4.39900732,
                  'values': []},
                 {'id': 'vec41',
                  'metadata': {'text': 'Forecasts of global supply chain '
                                       'disruptions eased in late 2024, but '
                                       'consumer prices remained elevated due to '
                                       'persistent demand.'},
                  'score': 4.37389421,
                  'values': []},
                 {'id': 'vec84',
                  'metadata': {'text': "The IMF's 2024 global outlook highlighted "
                                       'risks of stagflation in emerging markets.'},
                  'score': 4.37335157,
                  'values': []},
                 {'id': 'vec96',
                  'metadata': {'text': 'New trade agreements signed 2022 will make '
                                       'an impact in 2024'},
                  'score': 4.33860636,
                  'values': []},
                 {'id': 'vec79',
                  'metadata': {'text': 'The resurgence of industrial policy in Q1 '
                                       '2024 focused on decoupling critical supply '
                                       'chains.'},
                  'score': 4.33784199,
                  'values': []},
                 {'id': 'vec6',
                  'metadata': {'text': 'Unemployment hit a record low of 3.7% in '
                                       'Q4 of 2024.'},
                  'score': 4.33008051,
                  'values': []},
                 {'id': 'vec65',
                  'metadata': {'text': 'The global shipping industry experienced '
                                       'declining freight rates in 2024 due to '
                                       'overcapacity and reduced demand.'},
                  'score': 4.3228569,
                  'values': []},
                 {'id': 'vec64',
                  'metadata': {'text': 'Rising commodity prices in 2024 strained '
                                       'emerging markets dependent on imports of '
                                       'raw materials.'},
                  'score': 4.32269621,
                  'values': []},
                 {'id': 'vec95',
                  'metadata': {'text': 'Automation in agriculture in 2024 '
                                       'increased yields but displaced rural '
                                       'workers.'},
                  'score': 4.31127262,
                  'values': []},
                 {'id': 'vec86',
                  'metadata': {'text': 'Digital transformation initiatives in 2024 '
                                       'drove productivity gains in the services '
                                       'sector.'},
                  'score': 4.30181122,
                  'values': []},
                 {'id': 'vec66',
                  'metadata': {'text': 'Bank lending to small and medium-sized '
                                       'enterprises surged in 2024 as governments '
                                       'incentivized entrepreneurship.'},
                  'score': 4.27241945,
                  'values': []},
                 {'id': 'vec58',
                  'metadata': {'text': 'Oil production cuts in Q1 2024 by OPEC '
                                       'nations drove prices higher, influencing '
                                       'global energy policies.'},
                  'score': 4.21715498,
                  'values': []},
                 {'id': 'vec80',
                  'metadata': {'text': 'Technological innovation in the fintech '
                                       'sector disrupted traditional banking in '
                                       '2024.'},
                  'score': 4.17712116,
                  'values': []},
                 {'id': 'vec75',
                  'metadata': {'text': 'The collapse of Silicon Valley Bank raised '
                                       'questions about regulatory oversight in '
                                       '2024.'},
                  'score': 4.16192341,
                  'values': []},
                 {'id': 'vec56',
                  'metadata': {'text': 'Consumer confidence indices remained '
                                       'resilient in Q2 2024 despite fears of an '
                                       'impending recession.'},
                  'score': 4.15782213,
                  'values': []},
                 {'id': 'vec67',
                  'metadata': {'text': 'Renewable energy projects accounted for a '
                                       'record share of global infrastructure '
                                       'investment in 2024.'},
                  'score': 4.14623,
                  'values': []}],
     'namespace': 'example-namespace',
     'usage': {'read_units': 9}}
    ```
  </Step>

  <Step title="Search the hybrid index with explicit weighting">
    Because Pinecone views your sparse-dense vector as a single vector, it does not offer a built-in parameter to adjust the weight of a query's dense part against its sparse part; the index is agnostic to density or sparsity of coordinates in your vectors. You may, however, incorporate a linear weighting scheme by customizing your query vector, as we demonstrate in the function below.

    The following example transforms vector values using an alpha parameter.

    ```Python Python theme={null}
    def hybrid_score_norm(dense, sparse, alpha: float):
        """Hybrid score using a convex combination

        alpha * dense + (1 - alpha) * sparse

        Args:
            dense: Array of floats representing
            sparse: a dict of `indices` and `values`
            alpha: scale between 0 and 1
        """
        if alpha < 0 or alpha > 1:
            raise ValueError("Alpha must be between 0 and 1")
        hs = {
            'indices': sparse['indices'],
            'values':  [v * (1 - alpha) for v in sparse['values']]
        }
        return [v * alpha for v in dense], hs
    ```

    The following example transforms a vector using the above function, then queries a Pinecone index.

    ```Python Python theme={null}
    sparse_vector = {
       'indices': [10, 45, 16],
       'values':  [0.5, 0.5, 0.2]
    }
    dense_vector = [0.1, 0.2, 0.3]

    hdense, hsparse = hybrid_score_norm(dense_vector, sparse_vector, alpha=0.75)

    query_response = index.query(
        namespace="example-namespace",
        top_k=10,
        vector=hdense,
        sparse_vector=hsparse
    )
    ```
  </Step>
</Steps>
