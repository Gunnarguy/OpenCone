# Fastlane for OpenCone

Automates App Store submissions and metadata management for OpenCone.

## Setup

1. **Install fastlane** (if not already installed):

   ```bash
   brew install fastlane
   ```

2. **Configure App Store Connect API key** (recommended):
   - Go to App Store Connect → Users and Access → Integrations → Keys
   - Create a new key with Admin role
   - Download the `.p8` file
   - Copy `.env.example` to `.env` and fill in:
     ```bash
     APP_STORE_CONNECT_API_KEY_ID=YOUR_KEY_ID
     APP_STORE_CONNECT_ISSUER_ID=YOUR_ISSUER_ID
     APP_STORE_CONNECT_API_KEY_PATH=/path/to/AuthKey_XXXXX.p8
     ```

3. **Or use Apple ID auth** (for manual runs):
   ```bash
   export FASTLANE_USER=your@apple.id
   ```

## Available Lanes

| Lane                     | Description                                                              |
| ------------------------ | ------------------------------------------------------------------------ |
| `fastlane metadata`      | Upload App Store metadata (description, keywords, etc.) without a binary |
| `fastlane beta`          | Build and upload to TestFlight                                           |
| `fastlane release`       | Build and upload to App Store Connect                                    |
| `fastlane build`         | Build IPA for App Store                                                  |
| `fastlane bump`          | Increment build number                                                   |
| `fastlane validate`      | Validate metadata before upload                                          |
| `fastlane sync_metadata` | Download current metadata from App Store Connect                         |

## Usage

### Upload metadata only (no binary):

```bash
cd /path/to/OpenCone
fastlane metadata
```

### Upload to TestFlight:

```bash
fastlane beta
```

### Full App Store release:

```bash
fastlane release
```

## Metadata Structure

```
fastlane/
├── metadata/
│   ├── copyright.txt
│   ├── en-US/
│   │   ├── description.txt
│   │   ├── keywords.txt
│   │   ├── marketing_url.txt
│   │   ├── name.txt
│   │   ├── primary_category.txt
│   │   ├── privacy_url.txt
│   │   ├── promotional_text.txt
│   │   ├── release_notes.txt
│   │   ├── secondary_category.txt
│   │   ├── subtitle.txt
│   │   └── support_url.txt
│   └── review_information/
│       ├── email_address.txt
│       ├── first_name.txt
│       ├── last_name.txt
│       ├── notes.txt
│       └── phone_number.txt
└── screenshots/
    └── en-US/
        └── (iPhone screenshots here)
```

## Troubleshooting

- **Authentication issues**: Ensure your API key has Admin permissions
- **Metadata validation errors**: Run `fastlane validate` to check before uploading
- **Build failures**: Make sure provisioning profiles are set up correctly in Xcode

## Related Docs

- [APP_STORE.md](../APP_STORE.md) - Full submission copy and reviewer notes
- [Fastlane docs](https://docs.fastlane.tools)
