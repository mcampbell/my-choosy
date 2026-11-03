---
type: Reference
title: Getting started - my-choosy
description: What my-choosy is, how to build it, and how to test it.
tags: [getting-started]
status: stable
generated: { by: claude-code/claude-opus-5-5, at: '2026-11-03T20:40:00Z' }
sources:
  - id: readme
    resource: "repo my-choosy: README.md"
    title: README.md
---

# Overview

my-choosy is a macOS default-browser handler. It opens each `http` or `https` link in one Chrome profile. A YAML rule list picks the profile.[^readme]

* `my-choosy`: the Ruby script. See [dispatch](/dispatch.md).
* `bin/build`: wraps the script in an AppleScript app. See [default-browser app](/default-browser-app.md).
* `config.example.yml`: the config shape. The live config is `~/.config/my-choosy/config.yml`.
* `EGM.md`: the directory contract (interface, invariants, side effects).

# Commands

* Test: `ruby test/my_choosy_test.rb` (Minitest, stdlib only; it stubs `system`, so it never opens Chrome).
* Build: `RUBY=<absolute ruby> bin/build`. Install and register: `bin/build --install`.

[^readme]: README.md
