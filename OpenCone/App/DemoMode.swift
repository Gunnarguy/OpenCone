import Foundation

/// Sample content for screenshots and checks of the interface without keys. Launched with
/// `-OpenConeDemo`, the app opens on sample indexes and a sample conversation; it makes no requests
/// unless a question is sent, and saves no settings or keys (the settings stay in memory and the
/// keys aren't checked). `-OpenConeDemoScreen <name>` also opens one screen (empty, answer, long-table, scope,
/// documents-indexing (a document finishes indexing 3 seconds in, to check its row redraws),
/// scope-one, answer-settings, models, sources, passage, settings, settings-answers,
/// settings-advanced, endpoints, endpoint, documents, index-details, document).
/// Debug builds only: in Release, `isActive` is always false.
enum DemoMode {
    static var isActive: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-OpenConeDemo")
        #else
        return false
        #endif
    }

    /// The screen to open at launch, from the `-OpenConeDemoScreen` argument
    static var screen: String? {
        guard isActive else { return nil }
        return UserDefaults.standard.string(forKey: "OpenConeDemoScreen")
    }
}

#if DEBUG
@MainActor
enum DemoContent {
    static func seed(_ search: SearchViewModel, settings: SettingsViewModel) async {
        let profiles = [
            profile(
                "manuals",
                summary: "Manuals for the café's espresso machine and grinder, one namespace per machine.",
                namespaces: [("espresso", 412), ("grinder", 236), ("", 18)],
                model: "text-embedding-3-large",
                dimension: 3072
            ),
            profile(
                "research",
                summary: "Notes and papers on water chemistry and coffee extraction, 2019 to 2026.",
                namespaces: [("", 1_204)],
                model: "text-embedding-3-large",
                dimension: 3072
            ),
            profile(
                "recipes",
                summary: "Family recipes and weekly meal plans.",
                namespaces: [("", 96)],
                model: "text-embedding-3-small",
                dimension: 1536
            ),
            IndexProfile(
                name: "legacy-notes",
                dimension: 768,
                metric: "cosine",
                namespaces: [IndexProfile.Namespace(name: "", vectorCount: 2_310)],
                embeddingModel: nil,
                modelCheck: .noMatch,
                modelSimilarity: 0.08,
                summary: "",
                summarySource: .missing,
                surveyedAt: Date().addingTimeInterval(-3_600)
            ),
        ]

        search.pineconeIndexes = profiles.map(\.name)
        search.indexProfiles = Dictionary(uniqueKeysWithValues: profiles.map { ($0.name, $0) })
        search.selectedIndex = "manuals"
        search.indexDimension = 3072
        search.indexMetric = "cosine"
        search.namespaces = ["", "espresso", "grinder"]
        search.namespaceVectorCounts = ["": 18, "espresso": 412, "grinder": 236]
        search.selectedNamespace = nil
        search.hasLoadedIndexes = true
        await search.setIndex("recipes", included: false)

        // The catalog's recommended model, reasoning at its default effort
        settings.reasoningEffort = CurrentModelCatalog.normalizedEffort("medium", model: settings.completionModel)

        switch DemoMode.screen {
        case "scope-one":
            settings.searchScope = .oneIndex
        case "empty", "scope":
            settings.searchScope = .auto
        case "settings-answers":
            settings.maxOutputTokens = 32_000
            settings.webSearchEnabled = true
            settings.webSearchDomains = "usgs.gov, wikipedia.org"
        default:
            break
        }

        guard DemoMode.screen != "empty" else { return }
        // "answer" shows the first exchange alone, its table and citations in full view; "long-table"
        // shows a table whose cells wrap, as the model writes when it describes each index
        switch DemoMode.screen {
        case "answer": search.messages = Array(conversation().prefix(2))
        case "long-table": search.messages = longTableConversation()
        default: search.messages = conversation()
        }
    }

    /// Sample requests for Settings > Advanced > Endpoints: launch, an upload, and a few questions
    static func seedActivity() {
        let activity = APIActivity.shared
        guard activity.calls.isEmpty else { return }
        let samples: [(APIEndpoint, Int?, TimeInterval, TimeInterval)] = [
            (.listIndexes, 200, 0.21, -1_800),
            (.models, 200, 0.34, -1_790),
            (.describeIndex, 200, 0.12, -1_780),
            (.indexStats, 200, 0.09, -1_200),
            (.listNamespaces, 200, 0.14, -1_195),
            (.embeddings, 200, 0.28, -620),
            (.upsert, 200, 0.46, -615),
            (.upsert, 200, 0.41, -612),
            (.indexStats, 200, 0.08, -300),
            (.responses, 200, 1.9, -299),
            (.embeddings, 200, 0.22, -297),
            (.query, 200, 0.18, -296),
            (.query, 200, 0.16, -296),
            (.rerank, 200, 0.31, -295),
            (.responses, 200, 7.4, -294),
            (.modelPages, 200, 0.42, -1_785),
            (.responses, 200, 4.1, -120),
            (.indexStats, 200, 0.07, -60),
            (.embeddings, 200, 0.19, -58),
            (.query, 200, 0.15, -57),
            (.responses, 200, 5.2, -56),
        ]
        for (endpoint, status, duration, offset) in samples {
            activity.record(APICall(endpoint: endpoint, status: status, duration: duration, date: Date().addingTimeInterval(offset)))
        }
    }

    /// Sample documents in every state, in the "manuals" index
    static func seedDocuments(_ documents: DocumentsViewModel) {
        documents.needsSecurityConsent = false
        documents.pineconeIndexes = ["manuals", "research", "recipes", "legacy-notes"]
        documents.selectedIndex = "manuals"
        documents.namespaces = ["", "espresso", "grinder"]
        documents.selectedNamespace = "espresso"
        documents.indexDimension = 3072
        documents.indexStats = IndexStatsResponse(
            namespaces: ["": NamespaceStats(vectorCount: 18), "espresso": NamespaceStats(vectorCount: 412), "grinder": NamespaceStats(vectorCount: 236)],
            dimension: 3072,
            totalVectorCount: 666
        )
        documents.indexMetadata = IndexDescribeResponse(
            name: "manuals",
            dimension: 3072,
            metric: "cosine",
            host: "manuals-a1b2c3d.svc.aped-4627-b74a.pinecone.io",
            status: IndexStatus(state: "Ready", ready: true)
        )

        func document(_ name: String, mime: String, size: Int64, chunks: Int = 0, namespace: String? = nil, error: String? = nil, minutesAgo: Double) -> DocumentModel {
            var document = DocumentModel(
                fileName: name,
                filePath: URL(fileURLWithPath: "/demo/\(name)"),
                mimeType: mime,
                fileSize: size,
                dateAdded: Date().addingTimeInterval(-minutesAgo * 60),
                isProcessed: namespace != nil,
                processingError: error,
                chunkCount: chunks
            )
            if let namespace {
                document.lastIndexedIndexName = "manuals"
                document.lastIndexedNamespace = namespace
                document.lastIndexedAt = Date().addingTimeInterval(-minutesAgo * 60 + 90)
                var stats = DocumentProcessingStats()
                let start = document.lastIndexedAt!.addingTimeInterval(-42)
                stats.startTime = start
                stats.endTime = document.lastIndexedAt
                stats.addPhase(phase: .textExtraction, start: start, end: start.addingTimeInterval(6))
                stats.addPhase(phase: .chunking, start: start.addingTimeInterval(6), end: start.addingTimeInterval(7))
                stats.addPhase(phase: .embeddingGeneration, start: start.addingTimeInterval(7), end: start.addingTimeInterval(31))
                stats.addPhase(phase: .vectorUpsert, start: start.addingTimeInterval(31), end: start.addingTimeInterval(42))
                stats.chunkSizes = (0..<chunks).map { 700 + ($0 * 37 % 330) }
                stats.extractedTextLength = stats.chunkSizes.reduce(0, +)
                stats.totalTokens = stats.extractedTextLength / 4
                stats.avgTokensPerChunk = Double(stats.totalTokens) / Double(max(chunks, 1))
                stats.vectorsUploaded = chunks
                document.processingStats = stats
            }
            return document
        }

        documents.documents = [
            document("Aster Duo User Manual.pdf", mime: "application/pdf", size: 8_912_384, chunks: 168, namespace: "espresso", minutesAgo: 2_880),
            document("Fenn 64 Grinder Guide.pdf", mime: "application/pdf", size: 6_104_221, chunks: 124, namespace: "grinder", minutesAgo: 1_440),
            document("Descaling checklist.md", mime: "text/markdown", size: 6_240, minutesAgo: 12),
            document("Water test strip.jpg", mime: "image/jpeg", size: 1_843_200, minutesAgo: 9),
            document("Scanned warranty card.pdf", mime: "application/pdf", size: 482_310, error: "No text could be read from the file.", minutesAgo: 30),
        ]

        // The way indexing reports back: the document is replaced in the list by its indexed self
        if DemoMode.screen == "documents-indexing" {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard let position = documents.documents.firstIndex(where: { $0.fileName == "Descaling checklist.md" }) else { return }
                var indexed = documents.documents[position]
                indexed.isProcessed = true
                indexed.chunkCount = 4
                indexed.lastIndexedIndexName = "manuals"
                indexed.lastIndexedNamespace = "espresso"
                indexed.lastIndexedAt = Date()
                documents.documents[position] = indexed
            }
        }
    }

    private static func profile(
        _ name: String,
        summary: String,
        namespaces: [(String, Int)],
        model: String,
        dimension: Int
    ) -> IndexProfile {
        IndexProfile(
            name: name,
            dimension: dimension,
            metric: "cosine",
            namespaces: namespaces.map { IndexProfile.Namespace(name: $0.0, vectorCount: $0.1) },
            embeddingModel: model,
            modelCheck: .matched,
            modelSimilarity: 0.998,
            summary: summary,
            summarySource: .drafted,
            surveyedAt: Date().addingTimeInterval(-600)
        )
    }

    private static func passage(_ tag: String, _ text: String, document: String, index: String, namespace: String, score: Float, page: String) -> SearchResultModel {
        var result = SearchResultModel(
            content: text,
            sourceDocument: document,
            score: score,
            metadata: ["page_number": page, "doc_id": document],
            index: index,
            namespace: namespace
        )
        result.citationTag = tag
        return result
    }

    static let firstPassages: [SearchResultModel] = [
        passage("S1", "Descale every 3 months on soft water. When the water is harder than 120 ppm, descale monthly.", document: "manuals/Aster Duo User Manual.pdf", index: "manuals", namespace: "espresso", score: 0.91, page: "42"),
        passage("S2", "Empty the drip tray and remove the portafilter before descaling. Never descale with vinegar: it degrades the gaskets.", document: "manuals/Aster Duo User Manual.pdf", index: "manuals", namespace: "espresso", score: 0.86, page: "43"),
        passage("S3", "Brush the burrs every 2 weeks, and take them out for a full clean every 3 months.", document: "manuals/Fenn 64 Grinder Guide.pdf", index: "manuals", namespace: "grinder", score: 0.88, page: "17"),
        passage("S4", "In the 8-week trial, machines on hard water built up twice as much scale as those on filtered water.", document: "research/Water hardness and scale 2024.pdf", index: "research", namespace: "", score: 0.71, page: "9"),
    ]

    static let secondPassages: [SearchResultModel] = [
        passage("S1", "Connect over USB-C and run `aster-cli export --log shots --format csv` to save every shot with its temperature and pressure.", document: "manuals/Aster Duo User Manual.pdf", index: "manuals", namespace: "espresso", score: 0.84, page: "88"),
    ]

    private static func longTableConversation() -> [ChatMessage] {
        let start = Date().addingTimeInterval(-60)
        return [
            ChatMessage(role: .user, text: "What's in each of my indexes?", createdAt: start),
            ChatMessage(
                role: .assistant,
                text: """
                The search results show **three indexes**:

                | Index / namespace | Content found |
                |:--|:--|
                | `manuals` | The **Aster Duo User Manual**, covering descaling, the water filter, brew temperature and the shot log export over USB-C [S1] |
                | `research` | A 2024 trial of water hardness and scale, with results for filtered, soft and hard water over 8 weeks [S4] |
                | `recipes` | Family recipes and weekly meal plans |

                This covers what the searches returned, not every document in each index.
                """,
                sources: firstPassages,
                createdAt: start.addingTimeInterval(6)
            ),
        ]
    }

    /// A café's equipment manuals: invented machines and brands, so no real product's instructions
    /// appear in screenshots
    private static func conversation() -> [ChatMessage] {
        let start = Date().addingTimeInterval(-240)
        return [
            ChatMessage(
                role: .user,
                text: "How often should the espresso machine be descaled, and how does that compare with cleaning the grinder?",
                createdAt: start
            ),
            ChatMessage(
                role: .assistant,
                text: """
                ## Maintenance intervals

                The **Aster Duo** needs descaling every **3 months** on soft water, or **monthly** when the water is harder than 120 ppm [S1]. The **Fenn 64** burrs need brushing every **2 weeks** [S3].

                | Machine | Task | Every |
                |:--------|:-----|:-----:|
                | Aster Duo | Descale | 1 to 3 months |
                | Fenn 64 | Brush burrs | 2 weeks |

                ### Before you descale
                1. Empty the drip tray and remove the portafilter [S2]
                2. Flush with clean water twice afterwards

                > Never descale with vinegar: it degrades the gaskets [S2].

                Hard water left *twice as much scale* after 8 weeks [S4].
                """,
                citations: firstPassages.map(\.sourceDocument),
                citationScopes: firstPassages.map { $0.scopeLabel ?? "" },
                sources: firstPassages,
                createdAt: start.addingTimeInterval(8)
            ),
            ChatMessage(
                role: .user,
                text: "How do I export the shot log from the machine?",
                createdAt: start.addingTimeInterval(120)
            ),
            ChatMessage(
                role: .assistant,
                text: """
                Connect the machine over USB-C, then run:

                ```bash
                aster-cli export --log shots --format csv
                ```

                Each row is one shot, with its temperature and pressure [S1].
                """,
                citations: secondPassages.map(\.sourceDocument),
                citationScopes: secondPassages.map { $0.scopeLabel ?? "" },
                sources: secondPassages,
                createdAt: start.addingTimeInterval(126)
            ),
        ]
    }
}
#endif
