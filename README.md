
# TapResearch-LOVE-SDK v3.8.0--beta01
---

The TapResearchSDK v3.8.0--beta01 LÖVE 2D package contains:
* iOS SDK v3.8.0--beta02

For additional information, please see the [TapResearch LÖVE SDK integration guide](https://supply-docs.tapresearch.com/docs/3.x/basic-integration/sdk-integration/love).

---

This folder contains the redistributable TapResearch SDK components for integrating TapResearch with a LÖVE iOS project.

## Install

From this folder, run:

```sh
ruby tools/install_tapresearch_love.rb --love-root /path/to/love --game-root /path/to/your/game
```

The installer copies the native bridge, patches LÖVE's native Lua module registration, copies the iOS `TapResearchSDK.xcframework`, updates supported Xcode projects, and copies `tapresearch.lua` into your game folder.

See `platform/xcode/Integration.md` for the full integration guide.

## Android Integration Instructions

Please see [TapResearch LÖVE SDK Android integration guide](./platform/android/README.md)

## Other platforms:

[TapResearch Android SDK](https://supply-docs.tapresearch.com/docs/3.x/basic-integration/sdk-integration/android)

[TapResearch iOS SDK](https://supply-docs.tapresearch.com/docs/3.x/basic-integration/sdk-integration/ios)

[TapResearch Unity SDK](https://supply-docs.tapresearch.com/docs/3.x/basic-integration/sdk-integration/unity)  

[TapResearch React Native SDK integration guide](https://supply-docs.tapresearch.com/docs/3.x/basic-integration/sdk-integration/react-native)
