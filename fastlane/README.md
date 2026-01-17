fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios build

```sh
[bundle exec] fastlane ios build
```

Build the app for App Store submission

### ios release

```sh
[bundle exec] fastlane ios release
```

Submit to App Store Connect for review

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Upload to TestFlight for beta testing

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Upload App Store metadata without a binary

### ios bump

```sh
[bundle exec] fastlane ios bump
```

Increment build number

### ios validate

```sh
[bundle exec] fastlane ios validate
```

Validate app metadata and screenshots

### ios sync_metadata

```sh
[bundle exec] fastlane ios sync_metadata
```

Sync metadata from App Store Connect to local files

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
