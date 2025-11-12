import Foundation
import CryptoKit

/// Utility helpers for preparing document files during ingestion.
struct DocumentFileUtilities {
    /// Characters that should be stripped from file names when persisting to the sandbox.
    private static let disallowedCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>")

    /// Sanitizes the supplied file name so it can be safely written to disk.
    /// - Parameter name: Original file name selected by the user.
    /// - Returns: Sanitized name with problematic characters replaced by underscores.
    static func sanitizeFilename(_ name: String) -> String {
        name.components(separatedBy: disallowedCharacters).joined(separator: "_")
    }

    /// Generates a unique destination URL by appending numeric suffixes while the chosen name exists.
    /// - Parameters:
    ///   - fileName: Candidate file name (already sanitized).
    ///   - directory: Directory the file should live in.
    ///   - fileManager: File manager used to inspect the directory. Defaults to `.default` for production usage.
    static func makeUniqueDestinationURL(
        basedOn fileName: String,
        within directory: URL,
        fileManager: FileManager = .default
    ) -> URL {
        let baseName = (fileName as NSString).deletingPathExtension
        let fileExtension = (fileName as NSString).pathExtension

        var candidateURL = directory.appendingPathComponent(fileName)
        var counter = 1

        while fileManager.fileExists(atPath: candidateURL.path) {
            let suffix = "-\(counter)"
            let candidateName: String

            if fileExtension.isEmpty {
                candidateName = baseName + suffix
            } else {
                candidateName = baseName + suffix + "." + fileExtension
            }

            candidateURL = directory.appendingPathComponent(candidateName)
            counter += 1
        }

        return candidateURL
    }
}

/// Helper for producing stable document identifiers used during deduplication.
struct DocumentIdentifierBuilder {
    /// Generates a deterministic identifier for a document based on its location and metadata.
    /// - Parameters:
    ///   - url: Source URL returned by the document picker.
    ///   - fileSize: Recorded file size in bytes.
    ///   - creationDate: Optional creation date from file attributes.
    ///   - modificationDate: Optional modification date from file attributes.
    /// - Returns: A 32-character lowercase hex string derived from a SHA-256 digest.
    static func makeIdentifier(
        url: URL,
        fileSize: Int64,
        creationDate: Date?,
        modificationDate: Date?
    ) -> String {
        let normalizedPath = url.standardizedFileURL.path.lowercased()
        let creation = creationDate?.timeIntervalSince1970 ?? 0
        let modification = modificationDate?.timeIntervalSince1970 ?? 0
        let fingerprint = "\(normalizedPath)::\(fileSize)::\(creation)::\(modification)"
        let digest = SHA256.hash(data: Data(fingerprint.utf8))
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }
}
