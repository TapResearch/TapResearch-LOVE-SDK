#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "digest"
require "optparse"
require "pathname"

TAPRESEARCH_EXTERN = "extern int luaopen_tapresearch_native(lua_State* L);"
TAPRESEARCH_MODULE = '{ "tapresearch_native", luaopen_tapresearch_native },'
TAPRESEARCH_SDK_RELATIVE_PATH = "platform/xcode/TapResearchSDK.xcframework"
ANDROID_CMAKE_TARGET = <<~CMAKE

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

CMAKE
ANDROID_GRADLE_DEPENDENCIES = [
  "implementation 'com.tapresearch:tapsdk:3.8.0--beta05'",
  "implementation 'org.jetbrains.kotlinx:kotlinx-serialization-json:1.5.0'",
  "implementation 'androidx.lifecycle:lifecycle-process:2.6.1'",
  "implementation 'com.google.android.gms:play-services-ads-identifier:18.1.0'",
  "implementation 'androidx.core:core-ktx:1.10.1'",
  "implementation 'com.google.android.gms:play-services-appset:16.1.0'"
].freeze

# Describes how to invoke the TapResearch LOVE installer.
#
# @return [String] Human-readable command usage text.
def usage
  <<~USAGE
    Usage:
      ruby tools/install_tapresearch_love.rb --love-root /path/to/love [--game-root /path/to/game]

    Options:
      --love-root PATH        Required. Root of the LOVE source checkout to patch.
      --android-root PATH     Optional. Root of a love-android checkout to patch.
      --game-root PATH        Optional. Game source folder where tapresearch.lua should be copied.
      --sdk-root PATH         Optional. Root of this TapResearch LOVE SDK package.
      --dry-run              Print the planned changes without writing files.
      --skip-love-patch      Copy files without patching src/modules/love/love.cpp.
      --skip-module-copy     Patch love.cpp without copying src/modules/tapresearch.
      --skip-lua-copy        Do not copy tapresearch.lua to --game-root.
      --skip-sdk-copy        Do not copy TapResearchSDK.xcframework into the LOVE checkout.
      --skip-xcode-project   Do not update Xcode project files.
      --skip-android         Do not update the love-android checkout.
      --help                 Show this help text.
  USAGE
end

# Parses installer command line options.
#
# @param argv [Array<String>] Raw command line arguments.
# @return [Hash] Parsed installer options.
def parse_options(argv)
  options = {
    sdk_root: Pathname.new(__dir__).join("..").expand_path,
    dry_run: false,
    skip_love_patch: false,
    skip_module_copy: false,
    skip_lua_copy: false,
    skip_sdk_copy: false,
    skip_xcode_project: false,
    skip_android: false
  }

  parser = OptionParser.new do |opts|
    opts.banner = usage
    opts.on("--love-root PATH", "Root of the LOVE source checkout to patch.") { |path| options[:love_root] = Pathname.new(path).expand_path }
    opts.on("--android-root PATH", "Root of a LOVE Android checkout to patch.") { |path| options[:android_root] = Pathname.new(path).expand_path }
    opts.on("--game-root PATH", "Game folder where tapresearch.lua should be copied.") { |path| options[:game_root] = Pathname.new(path).expand_path }
    opts.on("--sdk-root PATH", "Root of this TapResearch LOVE SDK package.") { |path| options[:sdk_root] = Pathname.new(path).expand_path }
    opts.on("--dry-run", "Print planned changes without writing files.") { options[:dry_run] = true }
    opts.on("--skip-love-patch", "Do not patch src/modules/love/love.cpp.") { options[:skip_love_patch] = true }
    opts.on("--skip-module-copy", "Do not copy src/modules/tapresearch.") { options[:skip_module_copy] = true }
    opts.on("--skip-lua-copy", "Do not copy tapresearch.lua.") { options[:skip_lua_copy] = true }
    opts.on("--skip-sdk-copy", "Do not copy TapResearchSDK.xcframework.") { options[:skip_sdk_copy] = true }
    opts.on("--skip-xcode-project", "Do not update Xcode project files.") { options[:skip_xcode_project] = true }
    opts.on("--skip-android", "Do not update the LOVE Android checkout.") { options[:skip_android] = true }
    opts.on("--help", "Show this help text.") do
      puts usage
      exit 0
    end
  end

  parser.parse!(argv)
  options
end

# Verifies that Android-specific SDK package files exist.
#
# @param sdk_root [Pathname] Root of this TapResearch LOVE SDK package.
# @return [void]
def validate_android_sdk_root!(sdk_root)
  [
    "platform/android/app/src/main/cpp/love/src/modules/tapresearch/tapresearch_bindings_android.cpp",
    "platform/android/app/src/main/java/com/tapresearch/love/TapResearchLoveBridge.java"
  ].each do |relative_path|
    path = sdk_root.join(relative_path)
    abort_with_usage("missing Android integration file at #{path}") unless path.file?
  end
end

# Stops installation when a required path or option is missing.
#
# @param message [String] Explanation shown to the user.
# @return [void]
def abort_with_usage(message)
  warn "Error: #{message}"
  warn
  warn usage
  exit 1
end

# Creates a stable Xcode project object identifier.
#
# @param label [String] Stable label for the generated project object.
# @return [String] A 24-character uppercase hexadecimal Xcode object id.
def xcode_id(label)
  Digest::MD5.hexdigest("tapresearch-love-installer:#{label}")[0, 24].upcase
end

# Verifies that required TapResearch SDK package files exist.
#
# @param sdk_root [Pathname] Root of this TapResearch LOVE SDK package.
# @return [void]
def validate_sdk_root!(sdk_root)
  module_source = sdk_root.join("src/modules/tapresearch")
  lua_source = sdk_root.join("src/scripts/tapexample/tapresearch.lua")

  abort_with_usage("missing TapResearch module source at #{module_source}") unless module_source.directory?
  abort_with_usage("missing TapResearch Lua wrapper at #{lua_source}") unless lua_source.file?
end

# Returns true when the packaged TapResearchSDK.xcframework is available.
#
# @param sdk_root [Pathname] Root of this TapResearch LOVE SDK package.
# @return [Boolean] Whether the packaged iOS SDK framework exists.
def packaged_sdk_available?(sdk_root)
  sdk_root.join(TAPRESEARCH_SDK_RELATIVE_PATH).directory?
end

# Verifies that the target LOVE source checkout has the expected files.
#
# @param love_root [Pathname] Root of the LOVE source checkout.
# @return [void]
def validate_love_root!(love_root)
  abort_with_usage("--love-root is required") if love_root.nil?
  abort_with_usage("missing LOVE source root at #{love_root}") unless love_root.directory?

  love_cpp = love_root.join("src/modules/love/love.cpp")
  abort_with_usage("missing #{love_cpp}") unless love_cpp.file?
end

# Verifies that the target LOVE Android checkout has the expected app files.
#
# @param android_root [Pathname] Root of the love-android checkout.
# @return [void]
def validate_android_root!(android_root)
  abort_with_usage("missing LOVE Android source root at #{android_root}") unless android_root.directory?

  [
    "app/build.gradle",
    "app/src/main/cpp/love/CMakeLists.txt",
    "app/src/main/cpp/love/src/modules/love/love.cpp",
    "app/src/main/java/org/love2d/android/GameActivity.java"
  ].each do |relative_path|
    path = android_root.join(relative_path)
    abort_with_usage("missing #{path}") unless path.file?
  end
end

# Copies a file or directory unless running in dry-run mode.
#
# @param source [Pathname] Source path to copy from.
# @param destination [Pathname] Destination path to overwrite.
# @param dry_run [Boolean] Whether to report without writing.
# @return [void]
def copy_path(source, destination, dry_run:)
  if source.expand_path == destination.expand_path
    puts "Skipping copy because source and destination are the same: #{source}"
    return
  end

  puts "#{dry_run ? "Would copy" : "Copying"} #{source} -> #{destination}"
  return if dry_run

  FileUtils.rm_rf(destination)
  FileUtils.mkdir_p(destination.dirname)
  FileUtils.cp_r(source, destination)
end

# Inserts TapResearch's native luaopen declaration into LOVE's love.cpp.
#
# @param content [String] Original love.cpp contents.
# @return [Array(String, Boolean)] Updated contents and whether a change was made.
def insert_tapresearch_extern(content)
  return [content, false] if content.include?(TAPRESEARCH_EXTERN)

  marker = "extern \"C\"\n{"
  abort "Could not find extern \"C\" block in love.cpp" unless content.include?(marker)

  [content.sub(marker, "#{marker}\n#{TAPRESEARCH_EXTERN}"), true]
end

# Inserts TapResearch's package.preload registration into LOVE's module table.
#
# @param content [String] Original love.cpp contents.
# @return [Array(String, Boolean)] Updated contents and whether a change was made.
def insert_tapresearch_module(content)
  return [content, false] if content.include?(TAPRESEARCH_MODULE)

  marker = "static const luaL_Reg modules[] = {\n"
  abort "Could not find modules[] table in love.cpp" unless content.include?(marker)

  [content.sub(marker, "#{marker}\t#{TAPRESEARCH_MODULE}\n"), true]
end

# Patches LOVE's love.cpp so require("tapresearch_native") works in static builds.
#
# @param love_cpp [Pathname] Path to src/modules/love/love.cpp.
# @param dry_run [Boolean] Whether to report without writing.
# @return [Boolean] Whether love.cpp needed changes.
def patch_love_cpp(love_cpp, dry_run:)
  original = love_cpp.read
  updated, extern_changed = insert_tapresearch_extern(original)
  updated, module_changed = insert_tapresearch_module(updated)
  changed = extern_changed || module_changed

  if changed
    puts "#{dry_run ? "Would patch" : "Patching"} #{love_cpp}"
    love_cpp.write(updated) unless dry_run
  else
    puts "Already patched #{love_cpp}"
  end

  changed
end

# Patches a text file and reports whether a change was needed.
#
# @param path [Pathname] File to patch.
# @param dry_run [Boolean] Whether to report without writing.
# @yieldparam content [String] Original file content.
# @yieldreturn [Array(String, Boolean)] Updated content and whether it changed.
# @return [Boolean] Whether the file needed changes.
def patch_text_file(path, dry_run:)
  original = path.read
  updated, changed = yield(original)

  if changed
    puts "#{dry_run ? "Would patch" : "Patching"} #{path}"
    path.write(updated) unless dry_run
  else
    puts "Already patched #{path}"
  end

  changed
end

# Inserts the TapResearch Android CMake target and dependency.
#
# @param cmake_file [Pathname] Path to app/src/main/cpp/love/CMakeLists.txt.
# @param dry_run [Boolean] Whether to report without writing.
# @return [Boolean] Whether the file needed changes.
def patch_android_cmake(cmake_file, dry_run:)
  patch_text_file(cmake_file, dry_run: dry_run) do |content|
    updated = content.dup
    changed = false

    unless updated.include?("add_library(love_tapresearch_root STATIC")
      marker = "set(LIBLOVE_DEPENDENCIES\n"
      abort "Could not find LIBLOVE_DEPENDENCIES in Android CMakeLists.txt" unless updated.include?(marker)

      updated = updated.sub(marker, "#{ANDROID_CMAKE_TARGET}#{marker}")
      changed = true
    end

    unless updated.match?(/set\(LIBLOVE_DEPENDENCIES\n(?:.*\n)*?\tlove_tapresearch_root\b/)
      marker = "set(LIBLOVE_DEPENDENCIES\n"
      abort "Could not find LIBLOVE_DEPENDENCIES in Android CMakeLists.txt" unless updated.include?(marker)

      updated = updated.sub(marker, "#{marker}\tlove_tapresearch_root\n")
      changed = true
    end

    [updated, changed]
  end
end

# Inserts TapResearch Android SDK dependencies into app/build.gradle.
#
# @param gradle_file [Pathname] Path to app/build.gradle.
# @param dry_run [Boolean] Whether to report without writing.
# @return [Boolean] Whether the file needed changes.
def patch_android_gradle(gradle_file, dry_run:)
  patch_text_file(gradle_file, dry_run: dry_run) do |content|
    missing = ANDROID_GRADLE_DEPENDENCIES.reject { |dependency| content.include?(dependency) }
    next [content, false] if missing.empty?

    marker = "dependencies {\n"
    abort "Could not find dependencies block in Android build.gradle" unless content.include?(marker)

    block = "\n    // required by TapResearch SDK\n" + missing.map { |dependency| "    #{dependency}\n" }.join
    [content.sub(marker, "#{marker}#{block}"), true]
  end
end

# Inserts the TapResearch activity registration into GameActivity.onCreate.
#
# @param activity_file [Pathname] Path to GameActivity.java.
# @param dry_run [Boolean] Whether to report without writing.
# @return [Boolean] Whether the file needed changes.
def patch_android_game_activity(activity_file, dry_run:)
  marker = "com.tapresearch.love.TapResearchLoveBridge.setActivity(this);"

  patch_text_file(activity_file, dry_run: dry_run) do |content|
    next [content, false] if content.include?(marker)

    pattern = /(protected void onCreate\(Bundle savedInstanceState\) \{\n)/
    abort "Could not find GameActivity.onCreate in #{activity_file}" unless content.match?(pattern)

    [content.sub(pattern, "\\1        #{marker}\n"), true]
  end
end

# Updates a love-android checkout with the TapResearch bridge.
#
# @param sdk_root [Pathname] Root of this TapResearch LOVE SDK package.
# @param android_root [Pathname] Root of the love-android checkout.
# @param dry_run [Boolean] Whether to report without writing.
# @return [void]
def patch_android_project(sdk_root, android_root, dry_run:)
  validate_android_sdk_root!(sdk_root)
  validate_android_root!(android_root)

  copy_path(
    sdk_root.join("platform/android/app/src/main/cpp/love/src/modules/tapresearch/tapresearch_bindings_android.cpp"),
    android_root.join("app/src/main/cpp/love/src/modules/tapresearch/tapresearch_bindings_android.cpp"),
    dry_run: dry_run
  )
  copy_path(
    sdk_root.join("platform/android/app/src/main/java/com/tapresearch/love/TapResearchLoveBridge.java"),
    android_root.join("app/src/main/java/com/tapresearch/love/TapResearchLoveBridge.java"),
    dry_run: dry_run
  )
  copy_path(
    sdk_root.join("src/scripts/tapexample/tapresearch.lua"),
    android_root.join("app/src/embed/assets/tapresearch.lua"),
    dry_run: dry_run
  )

  patch_love_cpp(android_root.join("app/src/main/cpp/love/src/modules/love/love.cpp"), dry_run: dry_run)
  patch_android_cmake(android_root.join("app/src/main/cpp/love/CMakeLists.txt"), dry_run: dry_run)
  patch_android_gradle(android_root.join("app/build.gradle"), dry_run: dry_run)
  patch_android_game_activity(android_root.join("app/src/main/java/org/love2d/android/GameActivity.java"), dry_run: dry_run)
end

# Inserts a PBX object line after the matching section header.
#
# @param content [String] Original project.pbxproj contents.
# @param section [String] PBX section name.
# @param line [String] Object line to insert.
# @param marker [String] Unique text that identifies whether the line already exists.
# @return [Array(String, Boolean)] Updated contents and whether a change was made.
def insert_pbx_object(content, section, line, marker)
  return [content, false] if content.include?(marker)

  header = "/* Begin #{section} section */\n"
  abort "Could not find #{section} section in Xcode project" unless content.include?(header)

  [content.sub(header, "#{header}#{line}"), true]
end

# Normalizes older TapResearchSDK.xcframework project references to the installer-managed id and path.
#
# @param content [String] Original project.pbxproj contents.
# @param sdk_ref [String] Installer-managed PBXFileReference id for TapResearchSDK.xcframework.
# @return [Array(String, Boolean)] Updated contents and whether a change was made.
def normalize_tapresearch_sdk_reference(content, sdk_ref)
  pattern = /^\t\t([A-F0-9]{24}) \/\* TapResearchSDK\.xcframework \*\/ = \{isa = PBXFileReference; lastKnownFileType = wrapper\.xcframework; (?:name = TapResearchSDK\.xcframework; )?path = (?:ios\/libraries\/)?TapResearchSDK\.xcframework; sourceTree = "<group>"; \};\n/
  old_ids = content.scan(pattern).flatten.uniq
  return [content, false] if old_ids.empty?

  reference_line = "\t\t#{sdk_ref} /* TapResearchSDK.xcframework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.xcframework; path = TapResearchSDK.xcframework; sourceTree = \"<group>\"; };\n"
  updated = content.gsub(pattern, reference_line)
  old_ids.each do |old_id|
    updated = updated.gsub("#{old_id} /* TapResearchSDK.xcframework */", "#{sdk_ref} /* TapResearchSDK.xcframework */")
  end

  [updated, updated != content]
end

# Removes stale project references from the previous tapresearchlove module integration.
#
# @param content [String] Original project.pbxproj contents.
# @return [Array(String, Boolean)] Updated contents and whether a change was made.
def remove_legacy_tapresearchlove_references(content)
  legacy_comments = [
    "TapResearchLove.h",
    "TapResearchLove.mm",
    "wrap_TapResearchLove.h",
    "wrap_TapResearchLove.cpp",
    "dummy.swift",
    "liblove-ios-Bridging-Header.h"
  ]

  updated = content.gsub(/^\t\t[A-F0-9]{24} \/\* tapresearchlove \*\/ = \{\n(?:.*?\n)*?\t\t\};\n/m, "")
  legacy_comments.each do |comment|
    updated = updated.gsub(/^\t+.*\/\* #{Regexp.escape(comment)}(?: in Sources)? \*\/.*\n/, "")
  end
  updated = updated.gsub(/^\t+.*\/\* tapresearchlove \*\/,\n/, "")
  updated = updated.gsub(%r{^\t+\tSWIFT_OBJC_BRIDGING_HEADER = "\.\./\.\./src/modules/tapresearchlove/liblove-ios-Bridging-Header\.h";\n}, "")

  [updated, updated != content]
end

# Replaces a PBX project section after applying a section-local edit.
#
# @param content [String] Original project.pbxproj contents.
# @param section [String] PBX section name.
# @yieldparam section_content [String] Contents between the section markers.
# @yieldreturn [Array(String, Boolean)] Updated section contents and whether it changed.
# @return [Array(String, Boolean)] Updated project contents and whether a change was made.
def update_pbx_section(content, section)
  header = "/* Begin #{section} section */\n"
  footer = "/* End #{section} section */"
  start_index = content.index(header)
  finish_index = content.index(footer)
  abort "Could not find #{section} section in Xcode project" if start_index.nil? || finish_index.nil?

  body_start = start_index + header.length
  body = content[body_start...finish_index]
  updated_body, changed = yield(body)
  return [content, false] unless changed

  [content[0...body_start] + updated_body + content[finish_index..], true]
end

# Inserts a child reference into a PBXGroup by group comment.
#
# @param content [String] Original project.pbxproj contents.
# @param group_comment [String] PBXGroup comment, such as "modules" or "Frameworks".
# @param child_line [String] Child reference line to insert.
# @param marker [String] Unique text that identifies whether the child already exists.
# @return [Array(String, Boolean)] Updated contents and whether a change was made.
def insert_pbx_group_child(content, group_comment, child_line, marker)
  return [content, false] if content.include?(marker)

  update_pbx_section(content, "PBXGroup") do |section_content|
    pattern = /(\t\t[A-F0-9]{24} \/\* #{Regexp.escape(group_comment)} \*\/ = \{\n(?:.*?\n)*?\t\t\tchildren = \(\n)/m
    abort "Could not find #{group_comment} group in Xcode project" unless section_content.match?(pattern)

    [section_content.sub(pattern, "\\1#{child_line}"), true]
  end
end

# Inserts a build file reference into a named build phase.
#
# @param content [String] Original project.pbxproj contents.
# @param phase_section [String] PBX build phase section name.
# @param phase_comment [String] Build phase comment, such as "Sources" or "Frameworks".
# @param file_line [String] Build file reference line to insert.
# @param marker [String] Unique text that identifies whether the file already exists.
# @return [Array(String, Boolean)] Updated contents and whether a change was made.
def insert_pbx_phase_file(content, phase_section, phase_comment, file_line, marker)
  return [content, false] if content.include?(marker)

  pattern = /(\t\t[A-F0-9]{24} \/\* #{Regexp.escape(phase_comment)} \*\/ = \{\n\t\t\tisa = #{Regexp.escape(phase_section)};\n(?:.*?\n)*?\t\t\tfiles = \(\n)/m
  abort "Could not find #{phase_comment} build phase in Xcode project" unless content.match?(pattern)

  [content.sub(pattern, "\\1#{file_line}"), true]
end

# Returns the build phase id for a named native target and phase comment.
#
# @param content [String] Original project.pbxproj contents.
# @param target_name [String] PBXNativeTarget comment/name, such as "love-ios".
# @param phase_comment [String] Build phase comment, such as "Frameworks".
# @return [String] The 24-character build phase id.
def target_build_phase_id(content, target_name, phase_comment)
  target_pattern = /\t\t[A-F0-9]{24} \/\* #{Regexp.escape(target_name)} \*\/ = \{\n(?:.*?\n)*?\t\t};/m
  target_block = content[target_pattern]
  abort "Could not find #{target_name} target in Xcode project" unless target_block

  phase_match = target_block.match(/\t\t\t\t([A-F0-9]{24}) \/\* #{Regexp.escape(phase_comment)} \*,?\//)
  phase_match ||= target_block.match(/\t\t\t\t([A-F0-9]{24}) \/\* #{Regexp.escape(phase_comment)} \*\/,/)
  abort "Could not find #{phase_comment} build phase in #{target_name} target" unless phase_match

  phase_match[1]
end

# Inserts a build file reference into a specific build phase id.
#
# @param content [String] Original project.pbxproj contents.
# @param phase_section [String] PBX build phase section name.
# @param phase_id [String] Build phase object id.
# @param phase_comment [String] Build phase comment, such as "Frameworks".
# @param file_line [String] Build file reference line to insert.
# @param marker [String] Unique text that identifies whether the file already exists.
# @return [Array(String, Boolean)] Updated contents and whether a change was made.
def insert_pbx_phase_file_by_id(content, phase_section, phase_id, phase_comment, file_line, marker)
  return [content, false] if content.include?(marker)

  pattern = /(\t\t#{Regexp.escape(phase_id)} \/\* #{Regexp.escape(phase_comment)} \*\/ = \{\n\t\t\tisa = #{Regexp.escape(phase_section)};\n(?:.*?\n)*?\t\t\tfiles = \(\n)/m
  abort "Could not find #{phase_comment} build phase #{phase_id} in Xcode project" unless content.match?(pattern)

  [content.sub(pattern, "\\1#{file_line}"), true]
end

# Inserts a build phase reference into the liblove-ios native target.
#
# @param content [String] Original project.pbxproj contents.
# @param phase_line [String] Build phase reference line to insert.
# @param marker [String] Unique text that identifies whether the phase already exists.
# @return [Array(String, Boolean)] Updated contents and whether a change was made.
def insert_liblove_target_phase(content, phase_line, marker)
  return [content, false] if content.include?(marker)

  pattern = /(\t\t[A-F0-9]{24} \/\* liblove-ios \*\/ = \{\n(?:.*?\n)*?\t\t\tbuildPhases = \(\n(?:.*?\n)*?\t\t\t\t[A-F0-9]{24} \/\* CopyFiles \*\/,\n)/m
  abort "Could not find liblove-ios target build phases in Xcode project" unless content.match?(pattern)

  [content.sub(pattern, "\\1#{phase_line}"), true]
end

# Inserts a build phase reference into a named native target after an existing phase.
#
# @param content [String] Original project.pbxproj contents.
# @param target_name [String] PBXNativeTarget comment/name.
# @param after_phase_comment [String] Existing phase comment to insert after.
# @param phase_line [String] Build phase reference line to insert.
# @param marker [String] Unique text that identifies whether the phase already exists.
# @return [Array(String, Boolean)] Updated contents and whether a change was made.
def insert_target_phase_after(content, target_name, after_phase_comment, phase_line, marker)
  return [content, false] if content.include?(marker)

  pattern = /(\t\t[A-F0-9]{24} \/\* #{Regexp.escape(target_name)} \*\/ = \{\n(?:.*?\n)*?\t\t\tbuildPhases = \(\n(?:.*?\n)*?\t\t\t\t[A-F0-9]{24} \/\* #{Regexp.escape(after_phase_comment)} \*\/,\n)/m
  abort "Could not find #{target_name} target build phases in Xcode project" unless content.match?(pattern)

  [content.sub(pattern, "\\1#{phase_line}"), true]
end

# Updates platform/xcode/liblove.xcodeproj with TapResearch files and framework links.
#
# @param project_file [Pathname] Path to liblove.xcodeproj/project.pbxproj.
# @param dry_run [Boolean] Whether to report without writing.
# @return [Boolean] Whether the project needed changes.
def patch_liblove_xcode_project(project_file, dry_run:)
  content = project_file.read
  changes = []

  ids = {
    bindings_ref: xcode_id("liblove:tapresearch_bindings.mm:file"),
    bridge_header_ref: xcode_id("liblove:TapResearchLoveBridge.h:file"),
    bridge_ref: xcode_id("liblove:TapResearchLoveBridge.mm:file"),
    group: xcode_id("liblove:tapresearch:group"),
    bindings_build: xcode_id("liblove:tapresearch_bindings.mm:sources"),
    bridge_build: xcode_id("liblove:TapResearchLoveBridge.mm:sources"),
    sdk_ref: xcode_id("liblove:TapResearchSDK.xcframework:file"),
    sdk_framework_build: xcode_id("liblove:TapResearchSDK.xcframework:frameworks"),
    sdk_embed_build: xcode_id("liblove:TapResearchSDK.xcframework:embed"),
    embed_phase: xcode_id("liblove:TapResearchSDK.xcframework:embed_phase")
  }

  content, changed = remove_legacy_tapresearchlove_references(content)
  changes << changed

  content, changed = normalize_tapresearch_sdk_reference(content, ids[:sdk_ref])
  changes << changed

  [
    ["/* tapresearch_bindings.mm in Sources */ = {isa = PBXBuildFile;", "\t\t#{ids[:bindings_build]} /* tapresearch_bindings.mm in Sources */ = {isa = PBXBuildFile; fileRef = #{ids[:bindings_ref]} /* tapresearch_bindings.mm */; };\n"],
    ["/* TapResearchLoveBridge.mm in Sources */ = {isa = PBXBuildFile;", "\t\t#{ids[:bridge_build]} /* TapResearchLoveBridge.mm in Sources */ = {isa = PBXBuildFile; fileRef = #{ids[:bridge_ref]} /* TapResearchLoveBridge.mm */; };\n"],
    ["/* TapResearchSDK.xcframework in Frameworks */ = {isa = PBXBuildFile;", "\t\t#{ids[:sdk_framework_build]} /* TapResearchSDK.xcframework in Frameworks */ = {isa = PBXBuildFile; fileRef = #{ids[:sdk_ref]} /* TapResearchSDK.xcframework */; };\n"],
    ["/* TapResearchSDK.xcframework in Embed Frameworks */ = {isa = PBXBuildFile;", "\t\t#{ids[:sdk_embed_build]} /* TapResearchSDK.xcframework in Embed Frameworks */ = {isa = PBXBuildFile; fileRef = #{ids[:sdk_ref]} /* TapResearchSDK.xcframework */; settings = {ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }; };\n"]
  ].each do |marker, line|
    content, changed = insert_pbx_object(content, "PBXBuildFile", line, marker)
    changes << changed
  end

  [
    ["/* tapresearch_bindings.mm */ = {isa = PBXFileReference;", "\t\t#{ids[:bindings_ref]} /* tapresearch_bindings.mm */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.objcpp; path = tapresearch_bindings.mm; sourceTree = \"<group>\"; };\n"],
    ["/* TapResearchLoveBridge.h */ = {isa = PBXFileReference;", "\t\t#{ids[:bridge_header_ref]} /* TapResearchLoveBridge.h */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; path = TapResearchLoveBridge.h; sourceTree = \"<group>\"; };\n"],
    ["/* TapResearchLoveBridge.mm */ = {isa = PBXFileReference;", "\t\t#{ids[:bridge_ref]} /* TapResearchLoveBridge.mm */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.objcpp; path = TapResearchLoveBridge.mm; sourceTree = \"<group>\"; };\n"],
    ["/* TapResearchSDK.xcframework */ = {isa = PBXFileReference;", "\t\t#{ids[:sdk_ref]} /* TapResearchSDK.xcframework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.xcframework; path = TapResearchSDK.xcframework; sourceTree = \"<group>\"; };\n"]
  ].each do |marker, line|
    content, changed = insert_pbx_object(content, "PBXFileReference", line, marker)
    changes << changed
  end

  group_marker = "/* tapresearch */ ="
  group = <<~PBX
  \t\t#{ids[:group]} /* tapresearch */ = {
  \t\t\tisa = PBXGroup;
  \t\t\tchildren = (
  \t\t\t\t#{ids[:bindings_ref]} /* tapresearch_bindings.mm */,
  \t\t\t\t#{ids[:bridge_header_ref]} /* TapResearchLoveBridge.h */,
  \t\t\t\t#{ids[:bridge_ref]} /* TapResearchLoveBridge.mm */,
  \t\t\t);
  \t\t\tpath = tapresearch;
  \t\t\tsourceTree = "<group>";
  \t\t};
  PBX
  content, changed = insert_pbx_object(content, "PBXGroup", group, group_marker)
  changes << changed

  content, changed = insert_pbx_group_child(content, "modules", "\t\t\t\t#{ids[:group]} /* tapresearch */,\n", "/* tapresearch */,")
  changes << changed
  content, changed = insert_pbx_group_child(content, "Frameworks", "\t\t\t\t#{ids[:sdk_ref]} /* TapResearchSDK.xcframework */,\n", "/* TapResearchSDK.xcframework */,")
  changes << changed

  embed_phase = <<~PBX
  \t\t#{ids[:embed_phase]} /* Embed Frameworks */ = {
  \t\t\tisa = PBXCopyFilesBuildPhase;
  \t\t\tbuildActionMask = 8;
  \t\t\tdstPath = "";
  \t\t\tdstSubfolderSpec = 10;
  \t\t\tfiles = (
  \t\t\t\t#{ids[:sdk_embed_build]} /* TapResearchSDK.xcframework in Embed Frameworks */,
  \t\t\t);
  \t\t\tname = "Embed Frameworks";
  \t\t\trunOnlyForDeploymentPostprocessing = 1;
  \t\t};
  PBX
  content, changed = insert_pbx_object(content, "PBXCopyFilesBuildPhase", embed_phase, "#{ids[:embed_phase]} /* Embed Frameworks */ =")
  changes << changed
  content, changed = insert_liblove_target_phase(content, "\t\t\t\t#{ids[:embed_phase]} /* Embed Frameworks */,\n", "#{ids[:embed_phase]} /* Embed Frameworks */,")
  changes << changed
  content, changed = insert_pbx_phase_file(content, "PBXCopyFilesBuildPhase", "Embed Frameworks", "\t\t\t\t#{ids[:sdk_embed_build]} /* TapResearchSDK.xcframework in Embed Frameworks */,\n", "/* TapResearchSDK.xcframework in Embed Frameworks */,")
  changes << changed

  content, changed = insert_pbx_phase_file(content, "PBXSourcesBuildPhase", "Sources", "\t\t\t\t#{ids[:bindings_build]} /* tapresearch_bindings.mm in Sources */,\n", "/* tapresearch_bindings.mm in Sources */,")
  changes << changed
  content, changed = insert_pbx_phase_file(content, "PBXSourcesBuildPhase", "Sources", "\t\t\t\t#{ids[:bridge_build]} /* TapResearchLoveBridge.mm in Sources */,\n", "/* TapResearchLoveBridge.mm in Sources */,")
  changes << changed
  ios_frameworks_phase = target_build_phase_id(content, "liblove-ios", "Frameworks")
  content, changed = insert_pbx_phase_file_by_id(content, "PBXFrameworksBuildPhase", ios_frameworks_phase, "Frameworks", "\t\t\t\t#{ids[:sdk_framework_build]} /* TapResearchSDK.xcframework in Frameworks */,\n", "/* TapResearchSDK.xcframework in Frameworks */,")
  changes << changed

  changed = changes.any?
  if changed
    puts "#{dry_run ? "Would update" : "Updating"} #{project_file}"
    project_file.write(content) unless dry_run
  else
    puts "Already updated #{project_file}"
  end

  changed
end

# Updates platform/xcode/love.xcodeproj with the TapResearch framework link.
#
# @param project_file [Pathname] Path to love.xcodeproj/project.pbxproj.
# @param dry_run [Boolean] Whether to report without writing.
# @return [Boolean] Whether the project needed changes.
def patch_love_xcode_project(project_file, dry_run:)
  content = project_file.read
  changes = []
  ids = {
    sdk_ref: xcode_id("love:TapResearchSDK.xcframework:file"),
    sdk_framework_build: xcode_id("love:TapResearchSDK.xcframework:frameworks"),
    sdk_embed_build: xcode_id("love:TapResearchSDK.xcframework:embed"),
    embed_phase: xcode_id("love:TapResearchSDK.xcframework:embed_phase")
  }

  content, changed = normalize_tapresearch_sdk_reference(content, ids[:sdk_ref])
  changes << changed

  [
    ["/* TapResearchSDK.xcframework in Frameworks */ = {isa = PBXBuildFile;", "\t\t#{ids[:sdk_framework_build]} /* TapResearchSDK.xcframework in Frameworks */ = {isa = PBXBuildFile; fileRef = #{ids[:sdk_ref]} /* TapResearchSDK.xcframework */; };\n"],
    ["/* TapResearchSDK.xcframework in Embed Frameworks */ = {isa = PBXBuildFile;", "\t\t#{ids[:sdk_embed_build]} /* TapResearchSDK.xcframework in Embed Frameworks */ = {isa = PBXBuildFile; fileRef = #{ids[:sdk_ref]} /* TapResearchSDK.xcframework */; settings = {ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }; };\n"]
  ].each do |marker, line|
    content, changed = insert_pbx_object(content, "PBXBuildFile", line, marker)
    changes << changed
  end

  content, changed = insert_pbx_object(
    content,
    "PBXFileReference",
    "\t\t#{ids[:sdk_ref]} /* TapResearchSDK.xcframework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.xcframework; path = TapResearchSDK.xcframework; sourceTree = \"<group>\"; };\n",
    "/* TapResearchSDK.xcframework */ = {isa = PBXFileReference;"
  )
  changes << changed

  content, changed = insert_pbx_group_child(content, "Frameworks", "\t\t\t\t#{ids[:sdk_ref]} /* TapResearchSDK.xcframework */,\n", "/* TapResearchSDK.xcframework */,")
  changes << changed

  embed_phase = <<~PBX
  \t\t#{ids[:embed_phase]} /* Embed Frameworks */ = {
  \t\t\tisa = PBXCopyFilesBuildPhase;
  \t\t\tbuildActionMask = 2147483647;
  \t\t\tdstPath = "";
  \t\t\tdstSubfolderSpec = 10;
  \t\t\tfiles = (
  \t\t\t\t#{ids[:sdk_embed_build]} /* TapResearchSDK.xcframework in Embed Frameworks */,
  \t\t\t);
  \t\t\tname = "Embed Frameworks";
  \t\t\trunOnlyForDeploymentPostprocessing = 0;
  \t\t};
  PBX
  content, changed = insert_pbx_object(content, "PBXCopyFilesBuildPhase", embed_phase, "#{ids[:embed_phase]} /* Embed Frameworks */ =")
  changes << changed
  content, changed = insert_target_phase_after(content, "love-ios", "Resources", "\t\t\t\t#{ids[:embed_phase]} /* Embed Frameworks */,\n", "#{ids[:embed_phase]} /* Embed Frameworks */,")
  changes << changed

  ios_frameworks_phase = target_build_phase_id(content, "love-ios", "Frameworks")
  content, changed = insert_pbx_phase_file_by_id(content, "PBXFrameworksBuildPhase", ios_frameworks_phase, "Frameworks", "\t\t\t\t#{ids[:sdk_framework_build]} /* TapResearchSDK.xcframework in Frameworks */,\n", "/* TapResearchSDK.xcframework in Frameworks */,")
  changes << changed
  content, changed = insert_pbx_phase_file_by_id(content, "PBXCopyFilesBuildPhase", ids[:embed_phase], "Embed Frameworks", "\t\t\t\t#{ids[:sdk_embed_build]} /* TapResearchSDK.xcframework in Embed Frameworks */,\n", "/* TapResearchSDK.xcframework in Embed Frameworks */,")
  changes << changed

  changed = changes.any?
  if changed
    puts "#{dry_run ? "Would update" : "Updating"} #{project_file}"
    project_file.write(content) unless dry_run
  else
    puts "Already updated #{project_file}"
  end

  changed
end

# Updates supported Xcode project files in a LOVE checkout.
#
# @param love_root [Pathname] Root of the LOVE source checkout.
# @param dry_run [Boolean] Whether to report without writing.
# @return [void]
def patch_xcode_projects(love_root, dry_run:)
  liblove_project = love_root.join("platform/xcode/liblove.xcodeproj/project.pbxproj")
  love_project = love_root.join("platform/xcode/love.xcodeproj/project.pbxproj")

  if liblove_project.file?
    patch_liblove_xcode_project(liblove_project, dry_run: dry_run)
  else
    puts "Skipping liblove Xcode project update because #{liblove_project} was not found."
  end

  if love_project.file?
    patch_love_xcode_project(love_project, dry_run: dry_run)
  else
    puts "Skipping app Xcode project update because #{love_project} was not found."
  end
end

# Runs the TapResearch LOVE SDK installation.
#
# @param options [Hash] Parsed installer options.
# @return [void]
def install(options)
  validate_sdk_root!(options[:sdk_root])
  validate_love_root!(options[:love_root])

  unless options[:skip_module_copy]
    copy_path(
      options[:sdk_root].join("src/modules/tapresearch"),
      options[:love_root].join("src/modules/tapresearch"),
      dry_run: options[:dry_run]
    )
  end

  unless options[:skip_love_patch]
    patch_love_cpp(options[:love_root].join("src/modules/love/love.cpp"), dry_run: options[:dry_run])
  end

  if !options[:skip_sdk_copy] && packaged_sdk_available?(options[:sdk_root])
    copy_path(
      options[:sdk_root].join(TAPRESEARCH_SDK_RELATIVE_PATH),
      options[:love_root].join(TAPRESEARCH_SDK_RELATIVE_PATH),
      dry_run: options[:dry_run]
    )
  elsif !options[:skip_sdk_copy]
    puts "Skipping TapResearchSDK.xcframework copy because it was not found in this SDK package."
  end

  patch_xcode_projects(options[:love_root], dry_run: options[:dry_run]) unless options[:skip_xcode_project]

  if options[:android_root] && !options[:skip_android]
    patch_android_project(options[:sdk_root], options[:android_root], dry_run: options[:dry_run])
  elsif !options[:skip_android]
    puts "Skipping Android update because --android-root was not provided."
  end

  if options[:game_root] && !options[:skip_lua_copy]
    copy_path(
      options[:sdk_root].join("src/scripts/tapexample/tapresearch.lua"),
      options[:game_root].join("tapresearch.lua"),
      dry_run: options[:dry_run]
    )
  elsif !options[:skip_lua_copy]
    puts "Skipping tapresearch.lua copy because --game-root was not provided."
  end

  puts "Done."
end

install(parse_options(ARGV)) if $PROGRAM_NAME == __FILE__
