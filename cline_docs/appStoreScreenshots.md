# App Store Screenshot Checklist

**Last updated:** 2025-11-12

This guide captures the four screenshot scenes required for OpenCone's App Store submission. Screenshots should be taken on a 6.7" device class (e.g., iPhone 17 Pro Max) and exported at native resolution (1290 x 2796). Use the helper script `scripts/capture_screenshots.sh` to manage staging and file naming.

## Prerequisites

- Xcode 16+ with the target simulator installed (e.g., *iPhone 17 Pro*).
- Reviewer/test API keys set so the app can ingest documents and run searches.
- A clean build with current assets (`scripts/preflight_check.sh` should pass).

## Capture Flow

1. Start the simulator: `open -a Simulator`.
2. In a terminal, run: `./scripts/capture_screenshots.sh /path/to/output`.
3. For each prompt, stage the described UI in the simulator, then press **Return** to capture the PNG.

| File Name | Description | Notes |
|-----------|-------------|-------|
| `welcome.png` | Welcome/onboarding screen with credential fields. | Make sure the OpenAI & Pinecone inputs are visible with placeholder text. |
| `documents.png` | Documents tab after importing the sample PDF. | Show at least one processed document tile with progress complete. |
| `processing.png` | Logs tab while ingestion is running. | Trigger a re-import to display live log entries and progress badge. |
| `search.png` | Search tab streaming an answer. | Submit the sample query, ensure sourced snippets are visible, and the streaming indicator is active when possible. |

## Post-Capture Tasks

- Open each PNG in Preview and confirm the resolution is 1290 x 2796.
- Export additional sizes if required (e.g., 6.1" device) using Preview or `sips`.
- Add the screenshots to App Store Connect under **App Store > iOS App > App Preview & Screenshots**. Maintain the order above so reviewers see the onboarding context first.
- Archive the originals by committing them to a release-specific branch or storing them in the shared marketing drive.

## Troubleshooting

- **Simulator not found** – Override the device name with `OPEN_CONE_SCREENSHOT_DEVICE="iPhone 16 Pro Max" ./scripts/capture_screenshots.sh ...`.
- **Streaming answer paused** – Re-run the query; ensure the Pinecone namespace contains ingested documents and network connectivity is active.
- **Blurry text** – Disable simulator pixel scaling (**Window > Physical Size**) before capturing.
