# App Store

**Last updated:** 2026-10-01, for 3.1

The App Store listing lives in files in this repo and goes to App Store Connect through its API.
The steps are in `CLAUDE.md` under "App Store"; this page says what each file holds.

## Listing

[`scripts/asc/listing-3.1.json`](scripts/asc/listing-3.1.json) is the 3.1 listing: subtitle, promotional
text, keywords, description, What's New, support and marketing URLs, and copyright.
`scripts/asc/release.py listing` checks Apple's limits (subtitle 30, promotional text 170, keywords 100,
description and What's New 4,000) before it sends anything.

What the copy may claim is what the app does today:

- Answers cite passages with tags such as [S1]; a tag opens the passage.
- Search widths: Auto (up to five indexes or namespaces per question), Everything, One index.
- Documents are read and split on the iPhone, embedded with OpenAI, stored in the person's Pinecone index.
- Answer settings follow the selected model (`Core/Models/ModelLimits.swift`).
- Settings > Advanced > Endpoints lists the endpoints the app calls.
- Keys stay in the Keychain; no account, analytics or server of ours; answers are requested with `store: false`.

Not to claim: hybrid keyword search (documents are uploaded with dense vectors only), anything on-device
beyond reading and splitting files and recognizing text in images, prices of any kind.

Name `OpenCone`; primary category Developer Tools, secondary Productivity. Privacy policy:
`https://github.com/Gunnarguy/OpenCone/blob/main/PRIVACY.md`.

## Screenshots

Eight 1320 x 2868 PNGs in the 6.9-inch set (`APP_IPHONE_67` in the API), made by
[`scripts/appstore_screenshots.py`](scripts/appstore_screenshots.py) from demo-mode captures on the
`OpenCone shots` simulator. The script holds the captions and their order. The demo content is an
invented café's equipment manuals, so no real product or brand appears.

## App Review

The review notes in App Store Connect start with the reviewer's OpenAI key, Pinecone key and Pinecone
project ID. They stay there and never go into this repo. Below them, the steps from
[`scripts/asc/review-steps-3.1.txt`](scripts/asc/review-steps-3.1.txt) walk through the welcome
screens, Ask, a follow-up, Documents and Settings.
