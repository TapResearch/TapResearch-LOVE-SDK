# TapResearch LÖVE SDK for Android

These are instructions to integrate the TapResearch SDK into your love2d Android app written in lua.

# Before we begin

We assume you have already properly cloned https://github.com/love2d/love-android/
and have a working love2d Android game written in lua.

We have also provided an [example lua game and API file](https://github.com/TapResearch/TapResearch-LOVE-SDK/blob/master/src/scripts/tapexample)
in `TapResearch-LOVE-SDK/src/scripts/tapexample/` 

| File            | Purpose                      |
|-----------------|------------------------------|
| main.lua        | Sample Game File             |
| tapresearch.lua | Contains the TapResearch API |

 `main.lua` shows how to use the TapResearch API in detail starting with initialization and waiting
for the SDK Ready event.  The API Token and user-identifier provided in the sample are test values
 and will work for demonstration purposes.

# Integration Instructions

Follow these instructions to integrate the TapResearch SDK into your love2d Android app.

## 1. Copy our `tapresearch.lua` file

Copy `TapResearch-LOVE-SDK/src/scripts/tapexample/tapresearch.lua` to your Android app `src/embed/assets` directory.

It contains all the TapResearch API in lua.

## 2. Copy our `tapresearch_bindings_android.cpp` file  

Copy `TapResearch-LOVE-SDK/platform/android/app/src/main/cpp/love/src/modules/tapresearch/tapresearch_bindings_android.cpp` 
to your Android `app/src/main/cpp/love/src/modules/tapresearch` directory.  If the directory does not exist, create it.

## 3. Manually edit love.cpp

For reference, open our [`TapResearch-LOVE-SDK/platform/android/app/src/main/cpp/love/src/modules/love/love.cpp`](https://github.com/TapResearch/TapResearch-LOVE-SDK/blob/master/platform/android/app/src/main/cpp/love/src/modules/love/love.cpp) file.

Search for `tapresearch` keyword.  You will find 2 matches:  

```
extern int luaopen_tapresearch_native(lua_State* L);
```

**AND..**

```
static const luaL_Reg modules[] = {
        { "tapresearch_native", luaopen_tapresearch_native },
```        

Manually patch these blocks into your Android `app/src/main/cpp/love/src/modules/love/love.cpp` file.

## 4. Manually edit CMakeLists.txt

For reference, open our [`TapResearch-LOVE-SDK/platform/android/app/src/main/cpp/love/CMakeLists.txt`](https://github.com/TapResearch/TapResearch-LOVE-SDK/blob/master/platform/android/app/src/main/cpp/love/CMakeLists.txt) file.

Search for `love_tapresearch_root` keyword.  You will find several matches:

First, you will find the following block:

```
#
# tapresearch
#

add_library(love_tapresearch_root STATIC
src/modules/tapresearch/tapresearch_bindings_android.cpp
)
target_link_libraries(love_tapresearch_root PUBLIC
lovedep::Lua
lovedep::SDL
)
```

**AND..** further down you will find another match:

```
set(LIBLOVE_DEPENDENCIES
	love_tapresearch_root
```

Manually patch these blocks to your own Android `app/src/main/cpp/love/CMakeLists.txt` file.

## 5. Copy our TapResearchLoveBridge.java file

Copy our `TapResearch-LOVE-SDK/platform/android/app/src/main/java/com/tapresearch/love/TapResearchLoveBridge.java` to your 
Android `app/src/main/java/com/tapresearch/love/TapResearchLoveBridge.java`  

## 6. Edit **your** GameActivity.java file

In the `onCreate()` method, add the following as the first line:

```
com.tapresearch.love.TapResearchLoveBridge.setActivity(this);
```

It should look something like:
```
@Override
protected void onCreate(Bundle savedInstanceState) {
  com.tapresearch.love.TapResearchLoveBridge.setActivity(this);
  ...
  ...
}
```

For reference, take a look at our [`GameActivity.java`](https://github.com/TapResearch/TapResearch-LOVE-SDK/blob/master/platform/android/app/src/main/java/org/love2d/android/GameActivity.java)

## 7.  Edit your Android `app/build.gradle`

Add TapResearch SDK dependencies to your Android `app/build.gradle`

```
    // required by TapResearch SDK
    implementation 'com.tapresearch:tapsdk:3.8.0--beta05'
    implementation 'org.jetbrains.kotlinx:kotlinx-serialization-json:1.5.0'
    implementation 'androidx.lifecycle:lifecycle-process:2.6.1'
    implementation 'com.google.android.gms:play-services-ads-identifier:18.1.0'
    implementation 'androidx.core:core-ktx:1.10.1'
    implementation 'com.google.android.gms:play-services-appset:16.1.0'
```

For reference, take a look at our [android/app/build.gradle](https://github.com/TapResearch/TapResearch-LOVE-SDK/blob/master/platform/android/app/build.gradle)

Note: You should remove any duplicate dependencies and keep the more recent version.

## 8. Finally, add TapResearch functionality to your Android lua game

Reference our example [`main.lua`](https://github.com/TapResearch/TapResearch-LOVE-SDK/blob/master/src/scripts/tapexample/main.lua)

Basic flow:
- Initialize the SDK
- Wait for SDK Ready
- Show Survey Wall