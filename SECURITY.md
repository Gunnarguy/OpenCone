# OpenCone Security Policy

This document describes the security architecture of OpenCone, the credential handling models, network boundaries, and pre-release security verification workflows.

---

## 1. Supported Versions & Status

We actively support the following versions of OpenCone:

| Version | Status | Supported Swift/iOS | Updates |
|---|---|---|---|
| 2.2.x | Active / Production | iOS 17.0+ / Xcode 16.0+ | Security patches & dependency updates |
| < 2.2.0 | Legacy | iOS 16.x | Critical vulnerability fixes only |

---

## 2. Secret Storage Model

OpenCone does not store user API keys, tokens, or project configuration identifiers in plain-text storage (such as settings plist files or UserDefaults configuration bundles).
- **Secure Enclave Keychain**: All secret strings—specifically the OpenAI API Key, the Pinecone API Key, and the Pinecone Project ID—are written to the iOS Keychain via our custom `SecureSettingsStore` manager.
- **Biometric Enclave Integration**: Access is restricted to the application process sandbox, matching Apple's default Keychain access groups.
- **Wipe and Purge**: Triggering the **Reset Stored Keys & Preferences** action inside Settings completely removes keys from the Keychain and revokes security bookmarks.

---

## 3. Local Storage Risks & Sandbox Boundaries

All imported documents are copied to the application's local sandbox directories (`Library/Caches` or `Documents` depending on user settings).
- **iOS Sandbox Isolation**: The files are completely isolated from other applications running on the iOS device.
- **Security-Scoped Bookmarks**: The file URLs are persisted using security-scoped bookmark records. While bookmarks allow the app to re-read files across launches, the actual file content is never shared outside of the Sandbox.
- **Recommendation**: To keep local documents secure on your device, users must enforce hardware passcodes and enable FaceID/TouchID unlock options on their iOS device.

---

## 4. Network Boundary & API Transit

OpenCone communicates with external endpoints strictly using encrypted **HTTPS (TLS 1.2/1.3)** connections:
- **Direct Client-to-API**: The application speaks directly to OpenAI's endpoint (`api.openai.com`) and Pinecone's serverless endpoints. There is no middle proxy server, third-party relay, or custom collection endpoint.
- **Stateless Transfers**: Text segments and embeddings are transmitted to remote APIs to generate vectors or parse completions, and are not persisted inside OpenCone after requests are finalized.
- **Microphone Transit**: When utilizing Speech Input, raw audio coordinates are processed locally when possible or streamed directly to Apple's Speech Recognition endpoints.

---

## 5. Logging Policy

OpenCone logs diagnostic info to a centralized `Logger.shared` singleton.
- **Strict Privacy Mappings**: Log messages never record raw document bodies, full query strings, or Keychain keys.
- **Anonymized Metadata**: Logs only contain file names, sizes, processing status transitions, and network transaction codes.
- **Local Logs only**: Diagnostic log buffers reside exclusively in the volatile memory of the active device process and can be cleared by the user. They are never automatically uploaded to any backend telemetry service.

---

## 6. Release Build Protection

To prevent accidental developer credentials from leaking into production App Store archives:
- **Compile-Time Env Checks**: During initialization, `OpenConeApp` runs `enforceNoBundledSecrets()`.
- **Fatal Error Guard**: If non-empty environment parameters (`OPENAI_API_KEY`, `PINECONE_API_KEY`) are detected in non-debug targets, the app throws a `fatalError` and shuts down immediately.

---

## 7. Vulnerability Reporting Process

If you discover a vulnerability or suspect credential exposure within the codebase:
1. Do **not** open a public issue.
2. Email your findings directly to [security@opencone.app](mailto:security@opencone.app).
3. We will respond within 48 hours to acknowledge your report and coordinate a patch timeline.

---

## 8. Security Checklist for Future Changes

Developers committing modifications to OpenCone must follow this checklist:

- [ ] Assert that no hardcoded token placeholders (e.g. `sk-...` or `pcsk_...`) are checked into the codebase.
- [ ] Confirm that any new setting or parameter containing sensitive data is routed to the Keychain (`SecureSettingsStore`) instead of `UserDefaults`.
- [ ] Verify that new network requests use secure HTTPS endpoints.
- [ ] Run `python3 scripts/secret_scan.py` to verify no credentials exist in text formats.
- [ ] Execute `scripts/preflight_check.sh` locally to check for build errors and pass automated tests.
