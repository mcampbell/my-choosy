---
type: Component
title: Dispatch
description: How my-choosy picks a Chrome profile for a URL and opens it.
tags: [ruby, dispatch, config]
status: stable
generated: { by: claude-code/claude-opus-5-5, at: '2026-11-03T20:40:00Z' }
sources:
  - id: script
    resource: "repo my-choosy: my-choosy"
    title: my-choosy
---

# Behavior

1. `web_url?`: accept only a valid-UTF-8 string that starts with `http://` or `https://` (any case) and has no control character. Else log `ERROR not a web URL:` and exit 1. Nothing opens.[^script]
2. `load_config`: `YAML.safe_load_file` on each run (no cache). It must be a non-empty list of `{profile: String, match: [String]}`, with no empty profile or fragment.
3. `pick_profile`: check entries in list order, fragments in list order. A fragment matches if the full URL contains it, ignoring case. First hit wins. No hit: the first entry (the fallback).
4. `launch_command`: `open -na "Google Chrome" --args --profile-directory=<profile> <url>`, run with `system(*cmd)` (no shell).
5. A bad config logs the error and opens `open -a "Google Chrome" <url>` with no profile flag.
6. A failed `open` logs `ERROR open failed:` and exits 1.

# Log

`~/Library/Logs/my-choosy.log`: one line per dispatch (`<iso8601> <profile> <url>`) and per error. A log write failure goes to stderr and does not stop the launch.

See [decisions](/decisions/index.md).

[^script]: my-choosy
