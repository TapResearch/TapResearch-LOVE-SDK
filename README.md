# TapResearch LÖVE SDK v3.8.0--rc0

The TapResearchSDK v3.8.0--rc0 LÖVE package contains:
* Android SDK v3.8.0--rc2
* iOS SDK v3.8.0--rc1

For additional information, please see the [TapResearch iOS SDK integration guide](https://supply-docs.tapresearch.com/docs/3.x/basic-integration/sdk-integration/love).

## Setup

Create an [app](/supplier_dashboard/dashboard/apps/new) and grab your API Token.

## Download

https://github.com/TapResearch/TapResearch-LOVE-SDK

## Install

To install the SDK package into your LÖVE engine folder run the following command from the dowloaded TapResearch-LOVE-SDK package root:

```bash
ruby tools/install_tapresearch_love.rb \
  --love-root /path/to/love \
  --android-root /path/to/love-android \
  --game-root /path/to/your/game
```

You can preview the process without changing any files:
 ```bash
ruby tools/install_tapresearch_love.rb \
  --love-root /path/to/love \
  --android-root /path/to/love-android \
  --game-root /path/to/your/game \
  --dry-run
```

## Other platforms:

[TapResearch Android SDK](https://supply-docs.tapresearch.com/docs/3.x/basic-integration/sdk-integration/android)

[TapResearch iOS SDK](https://supply-docs.tapresearch.com/docs/3.x/basic-integration/sdk-integration/ios)

[TapResearch Unity SDK](https://supply-docs.tapresearch.com/docs/3.x/basic-integration/sdk-integration/unity)  

[TapResearch React Native SDK integration guide](https://supply-docs.tapresearch.com/docs/3.x/basic-integration/sdk-integration/react-native)
