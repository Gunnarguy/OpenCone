import Foundation

/// Sample content for screenshots and checks of the interface without keys. Launched with
/// `-OpenConeDemo`, the app opens on sample indexes and a sample conversation; it makes no requests
/// unless a question is sent, and saves no settings or keys (the settings stay in memory and the
/// keys aren't checked). `-OpenConeDemoScreen <name>` also opens one screen (empty, scope,
/// scope-one, answer-settings, models, sources, passage, settings, documents, index-details, document).
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
                summary: "Service manuals for infusion pumps, one namespace per manufacturer.",
                namespaces: [("baxter", 412), ("bd", 236), ("", 18)],
                model: "text-embedding-3-small",
                dimension: 1536
            ),
            profile(
                "research",
                summary: "Clinical papers on medication safety and infusion errors, 2019 to 2026.",
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
        search.indexDimension = 1536
        search.indexMetric = "cosine"
        search.namespaces = ["", "baxter", "bd"]
        search.namespaceVectorCounts = ["": 18, "baxter": 412, "bd": 236]
        search.selectedNamespace = nil
        search.hasLoadedIndexes = true
        await search.setIndex("recipes", included: false)

        switch DemoMode.screen {
        case "scope-one":
            settings.searchScope = .oneIndex
        case "empty", "scope":
            settings.searchScope = .auto
        default:
            break
        }

        guard DemoMode.screen != "empty" else { return }
        search.messages = conversation()
    }

    /// Sample documents in every state, in the "manuals" index
    static func seedDocuments(_ documents: DocumentsViewModel) {
        documents.needsSecurityConsent = false
        documents.pineconeIndexes = ["manuals", "research", "recipes", "legacy-notes"]
        documents.selectedIndex = "manuals"
        documents.namespaces = ["", "baxter", "bd"]
        documents.selectedNamespace = "baxter"
        documents.indexDimension = 1536
        documents.indexStats = IndexStatsResponse(
            namespaces: ["": NamespaceStats(vectorCount: 18), "baxter": NamespaceStats(vectorCount: 412), "bd": NamespaceStats(vectorCount: 236)],
            dimension: 1536,
            totalVectorCount: 666
        )
        documents.indexMetadata = IndexDescribeResponse(
            name: "manuals",
            dimension: 1536,
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
            document("Baxter Sigma Spectrum Service Manual.pdf", mime: "application/pdf", size: 8_912_384, chunks: 168, namespace: "baxter", minutesAgo: 2_880),
            document("BD Alaris 8015 Technical Manual.pdf", mime: "application/pdf", size: 6_104_221, chunks: 124, namespace: "bd", minutesAgo: 1_440),
            document("Filter change checklist.md", mime: "text/markdown", size: 6_240, minutesAgo: 12),
            document("Occlusion alarm label.jpg", mime: "image/jpeg", size: 1_843_200, minutesAgo: 9),
            document("Pump fleet inventory.csv", mime: "text/csv", size: 48_210, error: "No text could be read from the file.", minutesAgo: 30),
        ]
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
        passage("S1", "Replace the air-in-line filter every 96 hours of use, or sooner if the occlusion alarm sounds twice in one shift.", document: "manuals/Baxter Sigma Spectrum Service Manual.pdf", index: "manuals", namespace: "baxter", score: 0.91, page: "142"),
        passage("S2", "Pause the infusion and clamp the line before opening the filter housing. Never reuse a filter after a line disconnect.", document: "manuals/Baxter Sigma Spectrum Service Manual.pdf", index: "manuals", namespace: "baxter", score: 0.86, page: "143"),
        passage("S3", "The Alaris in-line filter is rated for 120 hours. Log each change in the device history record.", document: "manuals/BD Alaris 8015 Technical Manual.pdf", index: "manuals", namespace: "bd", score: 0.88, page: "77"),
        passage("S4", "Filter changes past the rated interval were linked to 14% of downstream occlusion alarms in the study period.", document: "research/Infusion pump alarm study 2024.pdf", index: "research", namespace: "", score: 0.71, page: "9"),
    ]

    static let secondPassages: [SearchResultModel] = [
        passage("S1", "From the service port, `svc reset --hard --confirm` clears the occlusion log and restarts the pump.", document: "manuals/BD Alaris 8015 Technical Manual.pdf", index: "manuals", namespace: "bd", score: 0.84, page: "201"),
    ]

    private static func conversation() -> [ChatMessage] {
        let start = Date().addingTimeInterval(-240)
        return [
            ChatMessage(
                role: .user,
                text: "How often does the Baxter pump need a new filter, and how does that compare with the BD pump?",
                createdAt: start
            ),
            ChatMessage(
                role: .assistant,
                text: """
                ## Filter intervals

                The **Baxter Sigma Spectrum** needs a new air-in-line filter every **96 hours** of use [S1], while the **BD Alaris** filter is rated for **120 hours** [S3].

                | Pump | Interval | Source |
                |:-----|:--------:|-------:|
                | Baxter Sigma | 96 h | S1 |
                | BD Alaris | 120 h | S3 |

                ### Before you change it
                1. Pause the infusion and clamp the line [S2]
                2. Wipe the port with alcohol for 15 seconds
                   - let it dry fully
                3. Record the change in the device log [S3]

                > Never reuse a filter after a line disconnect [S2].

                The research index adds that late changes were linked to *14% of occlusion alarms* [S4].
                """,
                citations: firstPassages.map(\.sourceDocument),
                citationScopes: firstPassages.map { $0.scopeLabel ?? "" },
                sources: firstPassages,
                createdAt: start.addingTimeInterval(8)
            ),
            ChatMessage(
                role: .user,
                text: "What's the reset command over the service port?",
                createdAt: start.addingTimeInterval(120)
            ),
            ChatMessage(
                role: .assistant,
                text: """
                From the BD service port, send:

                ```bash
                svc reset --hard --confirm
                ```

                It also clears the occlusion log, so export the log first if you need it [S1].
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
