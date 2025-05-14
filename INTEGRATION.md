# LÖVE 2D

This document is also available online at [TapResearch Documentation](https://supply-docs.tapresearch.com/docs/3.x/basic-integration/sdk-integration/love).

# Integrating TapResearch with the LÖVE 2D engine

:::info
The steps outlined in this document use LÖVE engine 11.5 and TapResearchSDK 3.6.0--rc8 or higher (3.5.0 and up will work but do not contain specific support for LÖVE).
:::
 
To integrate the TapResearchSDK we need to include the SDK, some source files, modify `liblove/modules/love/love.cpp` and modify the game’s Lua code.

## Steps to add TapResearch

Download and unarchive the `TapResearch-LOVE-SDK.zip` file and open the folder.

### Add module source

Copy the `tapresearch` folder into the `modules` folder in your LÖVE source folder, usually `src/modules`. This folder should contain 3 files:`TapResearchLoveBridge.h` and `TapResearchLoveBRidge.mm` that containt eh Objective-C to SDK bridge and`tapresearch_bindings.mm` to expose SDK functionality to Lua
In Xcode add this folder into the **modules** group in the Xcode file panel in the **liblove** group.

### Add the module to LÖVE

#### Register TapResearchSDK `luaopen` function
 
Open `love.cpp` and look for the `extern "C"` block that includes a number of `extern int luaopen_love_...` definitions and add `extern int luaopen_tapresearch_native(lua_State* L);` at the start. You should end up with something that looks like:

```c
extern "C"
{
extern int luaopen_tapresearch_native(lua_State* L);
#if defined(LOVE_ENABLE_AUDIO)
extern int luaopen_love_audio(lua_State*);
#endif
#if defined(LOVE_ENABLE_DATA)
extern int luaopen_love_data(lua_State*);
#endif
    ...
    ...
}
```

#### Register the TapResearch module

Find the `static const luaL_Reg modules[] = {` block and add `{ "tapresearch_native", luaopen_tapresearch_native },` at the start. You should end up with something like: 

```c
static const luaL_Reg modules[] = {
    { "tapresearch_native", luaopen_tapresearch_native },
#if defined(LOVE_ENABLE_AUDIO)
    { "love.audio", luaopen_love_audio },
#endif
#if defined(LOVE_ENABLE_DATA)
    { "love.data", luaopen_love_data },
#endif
    ...
    ...
};
```

## Additional steps for Android

## Additional steps for iOS

### Add the TapResearchSDK

The TapResearch module bridge bindings are compatible with iOS TapResearchSDK **3.5.0** and higher, though only **3.6.0--rc8** or higher includes direct support for LÖVE.
The `TapResearch-LOVE-SDK.zip` includes a TapResearchSDK.xcframework of version **3.6.0--rc8** or later, always check if there is a newer version available. 

#### Adding TapResearchSDK manually

Download the SDK from [TapResearch Github](https://github.com/TapResearch/TapResearch-iOS-SDK/releases) then copy TapResearchSDK.xcframework to `platform/xcode` and drag the SDK into the Xcode project into the **Frameworks** group. If Xcode asks to add it to macOS or iOS only select iOS.

#### Adding TapResearchSDK using SPM

If you are using a `Package.swift` file add a dependency for the TapResearchSDK version that you need:

```swift
depencencies: [
	.package(name: "TapResearchSDK", url: "https://github.com/TapResearch/TapResearch-iOS-SDK", exact: "3.6.0--rc8")
]
```

If you are using the Xcode SPM interface then add TapResearchSDK from [TapResearch Github](https://github.com/TapResearch/TapResearch-iOS-SDK) and use "Exact Version" from the version drop-down and enter the required version.

#### Adding TapResearchSDK using Cocoapods

If you are using Cocoapods then add `pod 'TapResearch', '3.6.0--rc8'` with the version you need to your game's iOS target.

### Addtional steps in Xcode for framework

Under the **General** tab for the love-ios target Make sure that `TapResearchSDK.xcframework` was added to the "Frameworks, Libraries, and Embedded Content" section and marked as "Embed & Sign".

Under the **Build Phases** tab for the love-ios target make sure that `TapResearchSDK.xcframework` is listed in "Link Binary With Libraries" as "Required". 

## Modify your game

In the `TapResearch-LOVE-SDK.zip` you will find a `tapexample` folder that includes the following files:
- tapresearch.lua
- config.lua
- main.lua
 
#### tapresearch.lua 
tapresearch.lua contains the Lua component of the TapResearchSDK bridge and should be included **unmodified** in your game's source folder. In our example we include it at the top-level with the main.lua file.
 
#### config.lua
config.lua contains some basic configuration for our test game.

#### main.lue
main.lua is our test game and just shows a menu of buttons that present various types of TapResearch content, a button that sends some pre-prepared user attributes and a status label.

# Integrating TapResearch with your game

### Initialization

Before we can initialize or use any TapResearch SDK functionality we need to require tapresearch, add at the top with any other require statements:

```c
tap = require("tapresearch")
```

Initialize the SDK in your `load()` function:

```c
tap.initialize("YOUR_API_TOKEN", "THE_USER_IDENTIFIER")
```

### Showing content

When the SDK is ready you can start showing TapResearch content.

To show a placement check if the placement can be shown using `canShowcontent("placement tag")` and then call `showContent("placement tag")`:

```c
	if tap.isReady() then
		tap.showContent(placementTag)
	end
``` 

You should set content shown and dismissed callbacks if you want to be notified when content has been showns or has been dismissed. Set these before callins `showContent()`:

```c 
	tap.onContentShown = function(placement)
		print("[TapResearch-Lua] Content shown for: " .. placement)
	end
	tap.onContentDismissed = function(placement) 
		print("[TapResearch-Lua] Content dismissed for: " .. placement)
	end
```

For more information about callbacks see [Content Callbacks](#content-callbacks) below.
 
#### Passing custom parameters
showContentWithCustomParameters

### Callbacks

The TapResearchSDK will notify the bridge and game when certain SDK events occur, this includes callbacks for rewards, content show or dismissed and also errors.

#### Reward Callback

When a player completes surveys they receive rewards, these rewards are sent to the game using a callback with an array of rewards.

Your game will not receive rewards until a reward callback has been set. To do this, first define your reward callback:

```c
function tapRewardHandler(rewards)
	print("[TapResearchSDK-Lua] Got rewards!")
	for _, reward in ipairs(rewards) do
		-- Iterate through rewards
	end
end
```

Set your reward callback after the SDK has been initialized:

```c
tap.setOnRewardReceived(tapRewardHandler)
```

If your reward callback is attached to a temporary object or you don't need to listen for rewards anymore then you should call `setOnRewardReceived` with `nil` so that the SDK understands not to send rewards. When next a reward callback is set any outstanding rewards will be sent to the game.

#### Quick Question Response Callback

When a player completes a Quick Question then response details are sent to the game using a callback with a payload with response details.

Your game will not receive Quick Question response payloads until a callback has been set. To do this, first define your callback:

```c
function tapQQResponseHandler(response)
	print("[TapResearchSDK-Lua] Got QQ response!")
	-- handle the response
end
```

Set your Quick Question callback, after the SDK has been initialized:

```c
tap.setOnQuickQuestionResponse(tapQQResponseHandler)
```

If your Quick Question callback is attached to an object that can be destroyed then you should call `setOnQuickQuestionResponse` with `nil` before it is destroyed so that the SDK understands not to send Quick Question response.

#### Content Callbacks

Before showing any TapResearch content you should set content shown and content dismissed callbacks.
You can do this by setting an inline function or pre-defined function.

```c
tap.onContentShown = function(placement)
	-- Perhaps pause animation, etc...
end
tap.onContentDismissed = function(placement) 
	-- Perhaps unpause animation, etc...
end
```

Or 

```c
function onTapContentShown(placement)
	-- Perhaps pause animations, etc...
end

function onTapContentDismissed(placement) 
	-- Perhaps unpause animations, etc...
end

function whenShowingPlacement() 
	tap.onContentShown= onTapContentShown
	tap.onContentDismissed = onTapContentDismissed
	-- continue on to show the placement
end
```

The content callbacks pass the placement tag for which content was shown or dismissed.

#### SDK Ready

```c
function onTapSdkReady() 
	-- SDK is ready to accept commands
end

...

tap.onSdkReady = onTapSDKReady
```

#### SDK Error

The SDK requires a callback set for any errors that may occur.

```c
function onTapSdkError(error, code)
	-- Handle the error (string) and error code (number)
end

...

tap.onSdkError = onTapSdkError
```

### Check if the SDK is ready

You can check if the SDK is ready to take your instructions by calling `isReady()` which returns true if ready or false if not.

```c
if tap.isReady() then
	-- Do something
end
```

### Send User Attributes

User attributes are used to target specific users with surveys. They can be set at any time and we will use the most recent values when determining which surveys to show. You can also opt to clear previously-set user attributes.

Use `sendUserAttributes()` to send user attributes:

```c
	tap.sendUserAttributes({
		user_type = "vip",
		seed_number = 500
	}, false) -- use true to clear perviously-set user attributes 
```

The keys must be strings and the values must be one of:
String, Float or Integer. 
If you want to use a date, please stringify an ISO8601 date or use a timestamp.

:::info
User attributes prefixed with `tapresearch_` are reserved for internal use. Please do not use this prefix for user attributes as doing so will result in an error
:::

You can send user attributes as soon as the SDK is ready.

We suggest sending as many attributes as you think that you'll want to target on for surveys, special awards, etc.

#### Send User Attributes when initializing

You can also send user attributes at initialization time using `initializeWithUserAttributes()`. 

:::info 
If user attributes are known at SDK initialization, it is preferable to pass them using `initializeWithUserAttributes()` compared to using `sendUserAttributes()`. This will result in quicker load times for targeted content.
:::

```c
initializeWithUserAttributes("YOUR_API_TOKEN", "THE_USER_IDENTIFIER", {
		user_type = "vip",
		seed_number = 500
	}, true)
```

### Set User Identifier

While we expect a user identifier when the SDK gets initialized you can set a new user identifier at any time using `setUserIdentifier()`:

```c
tap.setUserIdentifier("NEW_USER_IDENTIFIER")
```

### Callback data structures

#### Rewards

You can see an example usage of reward structures in `function tapRewardHandler(rewards)` in the example game's `main.lua` file.
The reward stuctures passed using the reward callback have the following values:

```c
transactionIdentifier -- a string
placementTag          -- a string
placementIdentifier   -- a string
payoutEvent           -- a string
currencyName          -- a string
rewardAmount          -- a floating point value
```

#### Quick Question response

An example usage of this can be seen in `function tapQQResponseHandler(payload)` in the example game's `main.lua` file.

```c
survey_identifier         -- string
app_name                  -- string
api_token                 -- string
sdk_version               -- string
platform                  -- string
placement_tag             -- string
user_identifier           -- string
user_locale               -- string
seen_at                   -- string
questions                 -- an array of questions
    question_identifier   -- string
    question_text         -- string
    question_type         -- string
    rating_scale_size     -- number, default 0
    user_answer           -- an optional answer object
        value             -- string
        identifiers       -- an array of strings
target_audience           -- targetting details
    filter_attribute_name -- string
    filter_operator       -- string
    filter_value          -- string
    user_value            -- string
complete                  -- completion details
    complete_identifier   -- string
    completed_at          -- string
```    

