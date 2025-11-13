# Security & Secret Handling Guide

**Last updated:** 2025-11-12

OpenCone keeps sensitive credentials out of source control and Production builds by combining Keychain storage, runtime validation, and repository automation. Use this document when preparing builds for TestFlight or App Store submission.

## Credential Storage

- **On device** – API keys provided in the Welcome or Settings flows are persisted in the iOS Keychain via `SecureSettingsStore`. They are never stored in bundled resources or `UserDefaults`.
- **Reset path** – Settings → Data & Privacy exposes a "Reset Stored Keys & Preferences" button. This calls `SecureSettingsStore.clearSecretsAndPreferences()` to remove keys and related preferences, resets conversation history, and re-enables the security-scoped bookmark consent banner.
- **Environment variables** – Development builds may use `OPENAI_API_KEY`, `PINECONE_API_KEY`, and `PINECONE_PROJECT_ID` environment variables for convenience. These must be cleared before archiving Release builds.

## Release Guard

`OpenConeApp.enforceNoBundledSecrets()` runs during app initialization and, in non-Debug builds, triggers a `fatalError` if the configuration detects non-empty OpenAI or Pinecone environment variables. This prevents Release/TestFlight binaries from launching with developer-owned secrets.

## Repository Checks

Two scripts located in `scripts/` support pre-submission hygiene:

- `secret_scan.py` – Recursively scans the repository for high-risk token patterns (`sk-`, `pcsk_`, bearer tokens). The script returns exit code 1 if any matches are found.
- `preflight_check.sh` – Runs the secret scan, asserts required `Info.plist` privacy usage descriptions exist, ensures `PRIVACY.md` plus `AppReviewNotes.md` include a "Last updated" line, and executes `xcodebuild test` against the default `platform=iOS Simulator,name=iPhone 17`. Override the destination with `OPEN_CONE_TEST_DESTINATION="platform=<custom destination>"` or set `SKIP_TESTS=1` if you must temporarily bypass tests (not recommended).

```bash
scripts/preflight_check.sh
```

## CI Recommendations

- Add a GitHub Actions (or other CI) job that executes `scripts/preflight_check.sh` on pull requests targeting release branches (set `OPEN_CONE_TEST_DESTINATION` to a simulator available on the runner).
- Block merges that reintroduce secrets, remove mandatory privacy strings, or cause the automated tests to fail.

## Contact

For security issues or suspected credential exposure, email [security@opencone.app](mailto:security@opencone.app).
