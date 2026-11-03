---
type: Component
title: Default-browser app
description: The AppleScript app that macOS calls as the default browser, and how bin/build makes it with no root.
tags: [macos, applescript, launchservices]
status: stable
generated: { by: claude-code/claude-opus-5-5, at: '2026-11-03T21:00:00Z' }
verified: [{ by: "human:mcampbellsb", at: '2026-11-03T21:00:00Z' }]
sources:
  - id: build
    resource: "repo my-choosy: bin/build"
    title: bin/build
  - id: research
    resource: "repo my-choosy: tmp/research-macos-default-browser.md (not committed)"
    title: Research - macOS default browser
---

# Overview

* macOS accepts only an `.app` bundle as the default browser. It sends the URL as an Apple Event (`GURL`), not in `ARGV`.[^research]
* The applet handler `on open location theURL` runs `<RUBY> Contents/Resources/my-choosy <url>` with `do shell script` and `quoted form of` on each part.[^build]
* `bin/build` steps: check `RUBY` (absolute, executable, no quote or backslash, has `YAML.safe_load_file`); `osacompile`; copy the script into `Contents/Resources`; `plutil` sets `CFBundleIdentifier` `local.my-choosy`, `CFBundleURLTypes` `http`/`https`, `LSUIElement`, `CFBundleDocumentTypes` (`public.html`, `public.xhtml`, role `Viewer`); `codesign --force --sign -`; with `--install`, copy to `~/Applications` and `lsregister -f`.

# Pitfalls

* A `plutil` edit breaks the ad-hoc signature from `osacompile`. Sign again after each edit.
* The applet gets no shell env, so the Ruby path is absolute and baked in. A Ruby upgrade needs a rebuild.
* With URL types alone, System Settings did not list the app. After adding `CFBundleDocumentTypes` and removing stale registrations, it did (2026-11-03). The two changes ran together.
* macOS registers each build copy (`build/`, scratch copies) with LaunchServices. Several copies with one bundle ID can confuse it. Remove extras with `lsregister -u <path>`.
* Setting the default browser also gives the app `public.html` and `public.xhtml` (`LSHandlerRoleAll` `local.my-choosy`).
* Unverified: what a double-click on a local `.html` file does. The applet has no `on open` handler for files.

[^build]: bin/build
[^research]: tmp/research-macos-default-browser.md
