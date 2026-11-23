---
type: Decision
title: Bad config still opens the link
description: A missing or invalid config logs the error and opens Chrome with no profile flag.
tags: [errors]
status: stable
generated: { by: "human:mcampbellsb", at: '2026-11-03T20:40:00Z' }
---

# Decision

Lose no link. With a bad config the fallback profile is unknown, so the script runs `open -a "Google Chrome" <url>` and Chrome uses its last-used profile. See [dispatch](/dispatch.md).
