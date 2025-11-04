import Foundation

/// Service for interacting with Pinecone vector database
class PineconeService {
    
    private let logger = Logger.shared
    private let apiKey: String
    private let projectId: String
    private let baseURL = "https://api.pinecone.io"
    private var indexHost: String?
    private var currentIndex: String?

    // Location and metadata cache
    private let cloud: String
    private let region: String
    private var indexHostCache: [String: (host: String, ts: Date)] = [:]
    private let hostCacheTTL: TimeInterval = 300 // 5 minutes
    
    // Network session management
    private let session: URLSession
    
    // Retry configuration
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 1.0 // Base delay in seconds
    
    // Rate limiting
    private var lastRequestTime: Date?
    private let minRequestInterval: TimeInterval = 0.1 // 100ms between requests

    // Health / Circuit breaker
    private enum HealthStatus {
        case unknown, healthy, unhealthy
    }
    private var healthStatus: HealthStatus = .unknown
    private var consecutiveHealthFailures: Int = 0
    private var circuitOpenUntil: Date? = nil
    private let healthFailureThreshold: Int = 2
    private let circuitOpenSeconds: TimeInterval = 20

    /// Whether the circuit is currently open due to recent consecutive failures.
    var isCircuitOpen: Bool {
        if let until = circuitOpenUntil {
            return Date() < until
        }
        return false
    }
    
    init(apiKey: String, projectId: String) {
        self.apiKey = apiKey
        self.projectId = projectId

        // Load location preferences from secure store
        let store = SecureSettingsStore.shared
        self.cloud = store.getPineconeCloud()
        self.region = store.getPineconeRegion()
        
        // Configure session with better timeout and caching policies
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        configuration.requestCachePolicy = .reloadRevalidatingCacheData
        configuration.urlCache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 50_000_000, diskPath: "pinecone_cache")
        
        self.session = URLSession(configuration: configuration)
    }
    
    /// Set the current index
    /// - Parameter indexName: Name of the index
    func setCurrentIndex(_ indexName: String) async throws {
        self.currentIndex = indexName
        try await getIndexHost(for: indexName)

        // Reset health/circuit state when switching indexes
        self.healthStatus = .unknown
        self.consecutiveHealthFailures = 0
        self.circuitOpenUntil = nil
        
        // Validate that we have a host after setting index
        guard indexHost != nil else {
            throw PineconeError.noIndexSelected
        }
        
        logger.log(level: .info, message: "Successfully set current index to '\(indexName)'")
    }

    /// Describe a Pinecone index to get its details, including dimension
    /// - Parameter name: Name of the index
    /// - Returns: Full description of the index
    func describeIndex(name: String) async throws -> IndexDescribeResponse {
        let endpoint = "\(baseURL)/indexes/\(name)"
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.addValue(projectId, forHTTPHeaderField: "X-Project-Id")
        request.addValue("2024-07", forHTTPHeaderField: "Api-Version")
        
        var result: IndexDescribeResponse?
        
        try await withRetries(maxRetries: maxRetries) {
            do {
                try await self.applyRateLimit()
                
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw PineconeError.invalidResponse
                }
                
                if httpResponse.statusCode != 200 {
                    let errorResponse = try? JSONDecoder().decode(PineconeErrorResponse.self, from: data)
                    let message = errorResponse?.message ?? String(data: data, encoding: .utf8) ?? "Unknown error"
                    logger.log(level: .error, message: "Pinecone API error (describeIndex): Status \(httpResponse.statusCode), Message: \(message)")
                    
                    if self.shouldRetry(statusCode: httpResponse.statusCode) {
                        throw PineconeError.retryableError(statusCode: httpResponse.statusCode)
                    } else {
                        throw PineconeError.requestFailed(statusCode: httpResponse.statusCode, message: message)
                    }
                }
                
                result = try JSONDecoder().decode(IndexDescribeResponse.self, from: data)
            } catch {
                if let pineconeError = error as? PineconeError, case .retryableError = pineconeError {
                    throw error
                } else {
                    logger.log(level: .error, message: "Failed to describe index: \(error.localizedDescription)")
                    throw error
                }
            }
        }
        
        guard let indexDescription = result else {
            throw PineconeError.requestFailed(statusCode: 0, message: "Failed to describe index: Unknown error")
        }
        
        return indexDescription
    }
    
    /// Get the host URL for a Pinecone index
    /// - Parameter indexName: Name of the index
    /// - Returns: Host URL
    private func getIndexHost(for indexName: String) async throws {
        // Serve from cache if fresh
        if let cached = indexHostCache[indexName], Date().timeIntervalSince(cached.ts) < hostCacheTTL {
            self.indexHost = cached.host
            logger.log(level: .info, message: "Using cached host for index '\(indexName)': \(cached.host)")
            return
        }

        let endpoint = "\(baseURL)/indexes/\(indexName)"
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // Use both API Key and Project ID for JWT authentication
        request.addValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.addValue(projectId, forHTTPHeaderField: "X-Project-Id")
        // Standardize API version header
        request.addValue("2024-07", forHTTPHeaderField: "Api-Version")
        
        // Use retry mechanism for this critical operation
        try await withRetries(maxRetries: maxRetries) {
            do {
                // Apply rate limiting
                try await self.applyRateLimit()
                
                let (data, response) = try await session.data(for: request)
                
                guard !data.isEmpty else {
                    throw PineconeError.emptyResponse
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw PineconeError.invalidResponse
                }
                
                if httpResponse.statusCode != 200 {
                    let errorResponse = try? JSONDecoder().decode(PineconeErrorResponse.self, from: data)
                    let message = errorResponse?.message ?? String(data: data, encoding: .utf8) ?? "Unknown error"
                    logger.log(level: .error, message: "Pinecone API error (getIndexHost): Status \(httpResponse.statusCode), Message: \(message)")
                    
                    // Determine if we should retry based on status code
                    if self.shouldRetry(statusCode: httpResponse.statusCode) {
                        throw PineconeError.retryableError(statusCode: httpResponse.statusCode)
                    } else {
                        throw PineconeError.requestFailed(statusCode: httpResponse.statusCode, message: message)
                    }
                }
                
                let indexInfo = try JSONDecoder().decode(IndexDescribeResponse.self, from: data)
                self.indexHost = indexInfo.host
                // Cache the host with timestamp
                indexHostCache[indexName] = (host: indexInfo.host, ts: Date())
                logger.log(level: .info, message: "Index host set to: \(indexInfo.host)")
            } catch {
                // Log the error and rethrow for retry mechanism to handle
                logger.log(level: .error, message: "Failed to get index host: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    /// List all available Pinecone indexes
    /// - Returns: Array of index names
    func listIndexes() async throws -> [String] {
        let endpoint = "\(baseURL)/indexes"
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.addValue(projectId, forHTTPHeaderField: "X-Project-Id")
        request.addValue("2024-07", forHTTPHeaderField: "Api-Version")
        
        var result: IndexListResponse?
        
        try await withRetries(maxRetries: maxRetries) {
            do {
                try await self.applyRateLimit()
                
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw PineconeError.invalidResponse
                }
                
                if httpResponse.statusCode != 200 {
                    let errorResponse = try? JSONDecoder().decode(PineconeErrorResponse.self, from: data)
                    let message = errorResponse?.message ?? String(data: data, encoding: .utf8) ?? "Unknown error"
                    logger.log(level: .error, message: "Pinecone API error (listIndexes): Status \(httpResponse.statusCode), Message: \(message)")
                    
                    if self.shouldRetry(statusCode: httpResponse.statusCode) {
                        throw PineconeError.retryableError(statusCode: httpResponse.statusCode)
                    } else {
                        throw PineconeError.requestFailed(statusCode: httpResponse.statusCode, message: message)
                    }
                }
                
                result = try JSONDecoder().decode(IndexListResponse.self, from: data)
            } catch {
                if let pineconeError = error as? PineconeError, case .retryableError = pineconeError {
                    throw error // Let withRetries handle it
                } else {
                    logger.log(level: .error, message: "Failed to list indexes: \(error.localizedDescription)")
                    throw error
                }
            }
        }
        
        guard let indexList = result else {
            throw PineconeError.requestFailed(statusCode: 0, message: "Failed to list indexes: Unknown error")
        }
        
        return indexList.indexes.map { $0.name }
    }
    
    /// Create a new Pinecone index
    /// - Parameters:
    ///   - name: Name of the index
    ///   - dimension: Dimension of the vectors
    /// - Returns: Response from the Pinecone API
    func createIndex(name: String, dimension: Int) async throws -> IndexCreateResponse {
        let endpoint = "\(baseURL)/indexes"
        
        let body: [String: Any] = [
            "name": name,
            "dimension": dimension,
            "metric": "cosine",
            "spec": [
                "serverless": [
                    "cloud": self.cloud,
                    "region": self.region
                ]
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            throw PineconeError.invalidRequestData
        }
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.addValue(projectId, forHTTPHeaderField: "X-Project-Id")
        request.addValue("2024-07", forHTTPHeaderField: "Api-Version")
        request.httpBody = jsonData
        
        var result: IndexCreateResponse?
        
        try await withRetries(maxRetries: maxRetries) {
            do {
                try await self.applyRateLimit()
                
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw PineconeError.invalidResponse
                }
                
                if httpResponse.statusCode != 201 && httpResponse.statusCode != 200 {
                    let errorResponse = try? JSONDecoder().decode(PineconeErrorResponse.self, from: data)
                    let message = errorResponse?.message ?? String(data: data, encoding: .utf8) ?? "Unknown error"
                    logger.log(level: .error, message: "Pinecone API error (createIndex): Status \(httpResponse.statusCode), Message: \(message)")
                    
                    if self.shouldRetry(statusCode: httpResponse.statusCode) {
                        throw PineconeError.retryableError(statusCode: httpResponse.statusCode)
                    } else {
                        throw PineconeError.requestFailed(statusCode: httpResponse.statusCode, message: message)
                    }
                }
                
                result = try JSONDecoder().decode(IndexCreateResponse.self, from: data)
            } catch {
                if let pineconeError = error as? PineconeError, case .retryableError = pineconeError {
                    throw error // Let withRetries handle it
                } else {
                    logger.log(level: .error, message: "Failed to create index: \(error.localizedDescription)")
                    throw error
                }
            }
        }
        
        guard let indexCreateResponse = result else {
            throw PineconeError.requestFailed(statusCode: 0, message: "Failed to create index: Unknown error")
        }
        
        return indexCreateResponse
    }
    
    /// Check if an index is ready for use
    /// - Parameter name: Name of the index
    /// - Returns: True if the index is ready
    func isIndexReady(name: String) async throws -> Bool {
        let endpoint = "\(baseURL)/indexes/\(name)"
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.addValue(projectId, forHTTPHeaderField: "X-Project-Id")
        request.addValue("2024-07", forHTTPHeaderField: "Api-Version")
        
        var result: Bool = false
        
        try await withRetries(maxRetries: maxRetries) {
            do {
                try await self.applyRateLimit()
                
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw PineconeError.invalidResponse
                }
                
                if httpResponse.statusCode != 200 {
                    let errorResponse = try? JSONDecoder().decode(PineconeErrorResponse.self, from: data)
                    let message = errorResponse?.message ?? String(data: data, encoding: .utf8) ?? "Unknown error"
                    logger.log(level: .error, message: "Pinecone API error (isIndexReady): Status \(httpResponse.statusCode), Message: \(message)")
                    
                    if self.shouldRetry(statusCode: httpResponse.statusCode) {
                        throw PineconeError.retryableError(statusCode: httpResponse.statusCode)
                    } else {
                        throw PineconeError.requestFailed(statusCode: httpResponse.statusCode, message: message)
                    }
                }
                
                let indexInfo = try JSONDecoder().decode(IndexDescribeResponse.self, from: data)
                result = indexInfo.status.state == "Ready"
            } catch {
                if let pineconeError = error as? PineconeError, case .retryableError = pineconeError {
                    throw error
                } else {
                    logger.log(level: .error, message: "Failed to check index status: \(error.localizedDescription)")
                    throw error
                }
            }
        }
        
        return result
    }
    
    /// Wait for an index to become ready
    /// - Parameters:
    ///   - name: Name of the index
    ///   - timeout: Timeout in seconds
    ///   - pollInterval: Polling interval in seconds
    /// - Returns: True if the index became ready within the timeout
    func waitForIndexReady(name: String, timeout: Int = 60, pollInterval: Int = 2) async throws -> Bool {
        let startTime = Date().timeIntervalSince1970
        var attempts = 0
        let maxAttempts = timeout / pollInterval
        
        while Date().timeIntervalSince1970 - startTime < Double(timeout) {
            do {
                let isReady = try await isIndexReady(name: name)
                if isReady {
                    logger.log(level: .info, message: "Index '\(name)' is now ready")
                    return true
                }
                
                attempts += 1
                logger.log(level: .info, message: "Waiting for index '\(name)' to be ready (attempt \(attempts)/\(maxAttempts))")
            } catch PineconeError.retryableError(let statusCode) {
                // For retryable errors, we just log and continue polling
                logger.log(level: .warning, message: "Retryable error checking index status (code: \(statusCode)). Will retry in \(pollInterval) seconds.")
            } catch {
                // For other errors, log but continue polling
                logger.log(level: .warning, message: "Error checking index status: \(error.localizedDescription)")
            }
            
            try await Task.sleep(nanoseconds: UInt64(pollInterval) * 1_000_000_000)
        }
        
        logger.log(level: .warning, message: "Timeout reached waiting for index '\(name)' to become ready")
        return false
    }
    
    /// Quick preflight health check for index host with short timeouts.
    /// - Returns: true if healthy (HTTP 200); false for non-200 or any error.
    func healthCheck() async -> Bool {
        // If the circuit is open, fail fast.
        if isCircuitOpen {
            logger.log(level: .warning, message: "Pinecone circuit open; skipping health check")
            return false
        }
        guard let indexHost = indexHost, let _ = currentIndex else {
            logger.log(level: .warning, message: "No index selected; health check failed")
            return false
        }
        let endpoint = "https://\(indexHost)/describe_index_stats"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.addValue(projectId, forHTTPHeaderField: "X-Project-Id")
        request.addValue("2024-07", forHTTPHeaderField: "Api-Version")

        // Short timeout session for preflight
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 5.0
        cfg.timeoutIntervalForResource = 5.0
        cfg.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let shortSession = URLSession(configuration: cfg)

        do {
            let (_, response) = try await shortSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                markHealthFailure(reason: "Invalid response in health check")
                return false
            }
            if httpResponse.statusCode == 200 {
                markHealthSuccess()
                return true
            } else {
                markHealthFailure(reason: "Health check non-200: \(httpResponse.statusCode)")
                return false
            }
        } catch {
            markHealthFailure(reason: "Health check error: \(error.localizedDescription)")
            return false
        }
    }

    private func markHealthSuccess() {
        if consecutiveHealthFailures > 0 || healthStatus != .healthy {
            logger.log(level: .info, message: "Pinecone health OK; closing circuit if open")
        }
        healthStatus = .healthy
        consecutiveHealthFailures = 0
        circuitOpenUntil = nil
    }

    private func markHealthFailure(reason: String) {
        consecutiveHealthFailures += 1
        healthStatus = .unhealthy
        logger.log(level: .warning, message: "Pinecone health failure (\(consecutiveHealthFailures)/\(healthFailureThreshold)): \(reason)")
        if consecutiveHealthFailures >= healthFailureThreshold {
            circuitOpenUntil = Date().addingTimeInterval(circuitOpenSeconds)
            logger.log(level: .warning, message: "Pinecone circuit opened for \(Int(circuitOpenSeconds))s")
        }
    }

    /// List namespaces for the current index
    /// - Returns: Array of namespace names
    func listNamespaces() async throws -> [String] {
        guard let indexHost = indexHost, let _ = currentIndex else {
            throw PineconeError.noIndexSelected
        }
        
        let endpoint = "https://\(indexHost)/describe_index_stats"
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.addValue(projectId, forHTTPHeaderField: "X-Project-Id")
        request.addValue("2024-07", forHTTPHeaderField: "Api-Version")
        
        var result: IndexStatsResponse?
        
        try await withRetries(maxRetries: maxRetries) {
            do {
                try await self.applyRateLimit()
                
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw PineconeError.invalidResponse
                }
                
                if httpResponse.statusCode != 200 {
                    let errorResponse = try? JSONDecoder().decode(PineconeErrorResponse.self, from: data)
                    let message = errorResponse?.message ?? String(data: data, encoding: .utf8) ?? "Unknown error"
                    logger.log(level: .error, message: "Pinecone API error (listNamespaces): Status \(httpResponse.statusCode), Message: \(message)")
                    
                    if self.shouldRetry(statusCode: httpResponse.statusCode) {
                        throw PineconeError.retryableError(statusCode: httpResponse.statusCode)
                    } else {
                        throw PineconeError.requestFailed(statusCode: httpResponse.statusCode, message: message)
                    }
                }
                
                result = try JSONDecoder().decode(IndexStatsResponse.self, from: data)
            } catch {
                if let pineconeError = error as? PineconeError, case .retryableError = pineconeError {
                    throw error
                } else {
                    logger.log(level: .error, message: "Failed to list namespaces: \(error.localizedDescription)")
                    throw error
                }
            }
        }
        
        guard let indexStats = result else {
            throw PineconeError.requestFailed(statusCode: 0, message: "Failed to list namespaces: Unknown error")
        }
        
        return Array(indexStats.namespaces.keys)
    }
    
    /// Upsert vectors to the current index
    /// - Parameters:
    ///   - vectors: Array of vectors to upsert
    ///   - namespace: Namespace to upsert to
    ///   - progressCallback: Optional closure to report batch progress (batchIndex, totalBatches)
    /// - Returns: Upsert response from Pinecone
    func upsertVectors(
        _ vectors: [PineconeVector],
        namespace: String? = nil,
        progressCallback: ((Int, Int) async -> Void)? = nil // Add optional callback
    ) async throws -> UpsertResponse {
        guard let indexHost = indexHost else {
            throw PineconeError.noIndexSelected
        }
        
        // Break vectors into batches to avoid oversized requests
        let batchSize = 100 // Pinecone recommends batches of 100
        let batches = stride(from: 0, to: vectors.count, by: batchSize).map {
            Array(vectors[$0..<min($0 + batchSize, vectors.count)])
        }
        
        var totalUpserted = 0
        let totalBatches = batches.count
        
        // Report initial progress if callback exists
        if totalBatches > 0 {
            await progressCallback?(0, totalBatches)
        }
        
        // Process each batch
        for (batchIndex, batch) in batches.enumerated() {
            // Removed logger.log call here to avoid duplication with DocumentsViewModel
            
            let endpoint = "https://\(indexHost)/vectors/upsert"
            
            var body: [String: Any] = [
                "vectors": batch.map { vector in
                    [
                        "id": vector.id,
                        "values": vector.values,
                        "metadata": vector.metadata
                    ]
                }
            ]
            
            if let namespace = namespace {
                body["namespace"] = namespace
            }
            
            guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
                throw PineconeError.invalidRequestData
            }
            
            var request = URLRequest(url: URL(string: endpoint)!)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue(apiKey, forHTTPHeaderField: "Api-Key")
            request.addValue(projectId, forHTTPHeaderField: "X-Project-Id")
            request.addValue("2024-07", forHTTPHeaderField: "Api-Version")
            request.httpBody = jsonData
            
            // Use retry mechanism for this operation
            try await withRetries(maxRetries: maxRetries) {
                do {
                    // Apply rate limiting
                    try await self.applyRateLimit()
                    
                    let (data, response) = try await session.data(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw PineconeError.invalidResponse
                    }
                    
                    if httpResponse.statusCode != 200 {
                        let errorResponse = try? JSONDecoder().decode(PineconeErrorResponse.self, from: data)
                        let message = errorResponse?.message ?? String(data: data, encoding: .utf8) ?? "Unknown error"
                        logger.log(level: .error, message: "Pinecone API error (upsertVectors): Status \(httpResponse.statusCode), Message: \(message)")
                        
                        // Determine if we should retry based on status code
                        if self.shouldRetry(statusCode: httpResponse.statusCode) {
                            throw PineconeError.retryableError(statusCode: httpResponse.statusCode)
                        } else {
                            throw PineconeError.requestFailed(statusCode: httpResponse.statusCode, message: message)
                        }
                    }
                    
                    let upsertResponse = try JSONDecoder().decode(UpsertResponse.self, from: data)
                    totalUpserted += upsertResponse.upsertedCount
                    // Removed logger.log call here to avoid duplication with DocumentsViewModel
                    
                    // Report progress after successful batch upsert
                    await progressCallback?(batchIndex, totalBatches)
                    
                } catch {
                    logger.log(level: .error, message: "Failed to upsert vectors batch \(batchIndex + 1): \(error.localizedDescription)")
                    throw error // Rethrow to let the caller handle it (ViewModel)
                }
            }
            
            // Add a small delay between batches to avoid overwhelming the API
            if batchIndex < totalBatches - 1 {
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }
        }
        
        return UpsertResponse(upsertedCount: totalUpserted)
    }
    
    /// Query the current index
    /// - Parameters:
    ///   - vector: Query vector
    ///   - topK: Number of results to return
    ///   - namespace: Namespace to query
    /// - Returns: Query response from Pinecone
    func query(vector: [Float], topK: Int = 10, namespace: String? = nil, filter: [String: Any]? = nil) async throws -> QueryResponse {
        guard let indexHost = indexHost else {
            throw PineconeError.noIndexSelected
        }
        
        let endpoint = "https://\(indexHost)/query"
        
        var body: [String: Any] = [
            "vector": vector,
            "topK": topK,
            "includeMetadata": true
        ]
        
        if let namespace = namespace {
            body["namespace"] = namespace
        }
        
        if let filter = filter {
            body["filter"] = filter
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            throw PineconeError.invalidRequestData
        }
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.addValue(projectId, forHTTPHeaderField: "X-Project-Id")
        request.addValue("2024-07", forHTTPHeaderField: "Api-Version")
        request.httpBody = jsonData
        
        // Use retry mechanism for query operations
        var result: QueryResponse?
        
        try await withRetries(maxRetries: maxRetries) {
            do {
                // Apply rate limiting
                try await self.applyRateLimit()
                
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw PineconeError.invalidResponse
                }
                
                if httpResponse.statusCode != 200 {
                    let errorResponse = try? JSONDecoder().decode(PineconeErrorResponse.self, from: data)
                    let message = errorResponse?.message ?? String(data: data, encoding: .utf8) ?? "Unknown error"
                    logger.log(level: .error, message: "Pinecone API error (query): Status \(httpResponse.statusCode), Message: \(message)")
                    
                    // Determine if we should retry based on status code
                    if self.shouldRetry(statusCode: httpResponse.statusCode) {
                        throw PineconeError.retryableError(statusCode: httpResponse.statusCode)
                    } else {
                        throw PineconeError.requestFailed(statusCode: httpResponse.statusCode, message: message)
                    }
                }
                
                do {
                    result = try JSONDecoder().decode(QueryResponse.self, from: data)
                } catch {
                    let raw = String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
                    logger.log(level: .error, message: "Pinecone decode error (query). Raw response: \(raw)")
                    throw error
                }
            } catch {
                if let pineconeError = error as? PineconeError, case .retryableError = pineconeError {
                    // This will be caught by withRetries for retry
                    throw error
                } else {
                    logger.log(level: .error, message: "Failed to query: \(error.localizedDescription)")
                    throw error
                }
            }
        }
        
        guard let queryResponse = result else {
            throw PineconeError.requestFailed(statusCode: 0, message: "Query failed with unknown error")
        }
        
        return queryResponse
    }
}

// MARK: - Response Models

struct IndexListResponse: Codable {
    let indexes: [IndexInfo]
}

struct IndexInfo: Codable {
    let name: String
    let dimension: Int?
    let metric: String?
    let host: String?
    let spec: IndexSpec?
}

struct IndexSpec: Codable {
    let serverless: ServerlessSpec?
}

struct ServerlessSpec: Codable {
    let cloud: String?
    let region: String?
}

struct IndexCreateResponse: Codable {
    let name: String
    let dimension: Int
    let metric: String
    let host: String?
    let status: IndexStatus?
}

struct IndexDescribeResponse: Codable {
    let name: String
    let dimension: Int
    let metric: String
    let host: String
    let status: IndexStatus
}

struct IndexStatus: Codable {
    let state: String
    let ready: Bool
}

struct IndexStatsResponse: Codable {
    let namespaces: [String: NamespaceStats]
    let dimension: Int
    let totalVectorCount: Int
    
    enum CodingKeys: String, CodingKey {
        case namespaces
        case dimension
        case totalVectorCount = "totalVectorCount"
    }
}

struct NamespaceStats: Codable {
    let vectorCount: Int
}

struct UpsertResponse: Codable {
    let upsertedCount: Int
}

enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? container.decode(Double.self) {
            self = .number(n)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let arr = try? container.decode([JSONValue].self) {
            self = .array(arr)
        } else if let obj = try? container.decode([String: JSONValue].self) {
            self = .object(obj)
        } else {
            throw DecodingError.typeMismatch(JSONValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSONValue"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        case .bool(let b): try container.encode(b)
        case .object(let o): try container.encode(o)
        case .array(let a): try container.encode(a)
        case .null: try container.encodeNil()
        }
    }

    // Convenience accessors
    var string: String? {
        switch self {
        case .string(let s): return s
        case .number(let n): return String(n)
        case .bool(let b): return b ? "true" : "false"
        default: return nil
        }
    }
}

struct QueryResponse: Codable {
    let matches: [QueryMatch]
    let namespace: String?
}

struct QueryMatch: Codable {
    let id: String
    let score: Double
    let metadata: [String: JSONValue]?
}

struct PineconeErrorResponse: Codable {
    let message: String?
    let code: Int?
}

enum PineconeError: Error {
    case invalidRequestData
    case invalidResponse
    case requestFailed(statusCode: Int, message: String?)
    case noIndexSelected
    case rateLimitExceeded
    case retryableError(statusCode: Int)
    case maxRetriesExceeded
    case emptyResponse
}

// MARK: - Helper Methods

extension PineconeService {
    
    /// Apply rate limiting to avoid overwhelming the API
    private func applyRateLimit() async throws {
        // If this is the first request, no need to wait
        guard let lastRequest = lastRequestTime else {
            lastRequestTime = Date()
            return
        }
        
        let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
        
        // If we haven't waited the minimum interval, sleep for the remaining time
        if timeSinceLastRequest < minRequestInterval {
            let sleepTime = UInt64((minRequestInterval - timeSinceLastRequest) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: sleepTime)
        }
        
        // Update the last request time
        lastRequestTime = Date()
    }
    
    /// Check if an error is retryable based on status code
    private func shouldRetry(statusCode: Int) -> Bool {
        // 429 is rate limiting, 5xx are server errors
        return statusCode == 429 || (statusCode >= 500 && statusCode < 600)
    }
    
    /// Execute an operation with retry logic
    /// - Parameters:
    ///   - maxRetries: Maximum number of retry attempts
    ///   - operation: The async operation to execute
    private func withRetries(maxRetries: Int, operation: () async throws -> Void) async throws {
        var attempts = 0
        var lastError: Error?
        
        while attempts <= maxRetries {
            do {
                try await operation()
                return // Success, exit the retry loop
            } catch PineconeError.retryableError(let statusCode) {
                attempts += 1
                lastError = PineconeError.retryableError(statusCode: statusCode)
                
                if attempts <= maxRetries {
                    // Exponential backoff with jitter
                    let baseDelay = retryDelay * pow(2.0, Double(attempts - 1))
                    let jitter = Double.random(in: 0...0.3) * baseDelay
                    let totalDelay = baseDelay + jitter
                    
                    logger.log(level: .warning, message: "Retrying after error (attempt \(attempts)/\(maxRetries)): Status \(statusCode). Waiting \(String(format: "%.2f", totalDelay))s")
                    try await Task.sleep(nanoseconds: UInt64(totalDelay * 1_000_000_000))
                }
            } catch {
                // For non-retryable errors, fail immediately
                throw error
            }
        }
        
        // If we've exhausted our retries, throw the last error or a maxRetries error
        throw lastError ?? PineconeError.maxRetriesExceeded
    }
}
