---
type: Decision
title: First entry is the fallback
description: The first profile in the config list opens URLs that match no fragment.
tags: [config]
status: stable
generated: { by: "human:mcampbellsb", at: '2026-11-03T20:40:00Z' }
---

# Decision

The first config entry is the fallback. There is no separate `default` key. First match wins in list order. Fragments use a case-insensitive "contains" test on the full URL. See [dispatch](/dispatch.md).
