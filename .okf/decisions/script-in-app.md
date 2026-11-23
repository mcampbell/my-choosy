---
type: Decision
title: Script copied into the app
description: bin/build copies my-choosy into the app bundle; config stays live.
tags: [build]
status: stable
generated: { by: "human:mcampbellsb", at: '2026-11-03T20:40:00Z' }
---

# Decision

`bin/build` copies `my-choosy` into `my-choosy.app/Contents/Resources/`. The repo can move after a build. A script edit needs a rebuild; a config edit does not, because the script reads the config on each run. See [default-browser app](/default-browser-app.md).
