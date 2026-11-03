# my-choosy Blueprint

## System Overview

my-choosy is a macOS default-browser handler. It opens each `http` or `https` link in one Chrome profile. A YAML rule list picks the profile. macOS sends the URL to an AppleScript app as an Apple Event. The app runs the Ruby script `my-choosy` with the URL as the only argument.

Read `.okf/index.md` for the knowledge bundle (dispatch rules, the app, decisions). Read `README.md` for setup.

## Local Interface & Invariants

- `my-choosy` (Ruby, stdlib only)
  - CLI: `my-choosy <url>`. Exit 0 when Chrome opens. Exit 1 for a rejected URL or a failed `open`.
  - `load_config(path)`: returns the rule list. Raises `RuntimeError` (`config must be ...`) unless it is a non-empty list of `{profile: non-empty String, match: [non-empty String]}`.
  - `pick_profile(rules, url)`: the first entry with a fragment that the URL contains (case-insensitive). No hit: the first entry.
  - `web_url?(url)`: true only for a valid-UTF-8 String that starts with `http://` or `https://` and has no control character.
  - `launch_command(profile, url)`: argv for `system`. `nil` profile: no `--profile-directory` flag.
  - `main(argv, config_path:, log_path:)`: runs only when the file is the program (`__FILE__ == $0`), so tests can `load` it.
- `bin/build [--install]` (bash): builds `build/my-choosy.app`. The `Info.plist` declares URL types `http`/`https` and an HTML viewer document type. With URL types alone, System Settings did not list the app. `RUBY` must be an absolute, executable path with no `"` or `\`, and must have `YAML.safe_load_file`.
- `config.example.yml`: the config shape. The live config is `~/.config/my-choosy/config.yml`.

## Subdirectories & System Boundaries

- bin: `bin/build` only. No contract file.
- test: `test/my_choosy_test.rb` (Minitest). No contract file.
- `.okf/`: knowledge bundle (OKF v0.2). Read it as a source.
- `build/`: generated, git-ignored. Do not edit.
- `tmp/`: design and task work files, git-excluded.

## Global Invariants

- The first config entry is the fallback. The first match wins, in list order.
- Run each launch with `system(*argv)`, never a shell string. The URL is untrusted.
- Lose no link: a bad config opens Chrome with no profile flag. A log write failure does not stop the launch.
- The script reads the config on each run. There is no cache.
- No step needs root or sudo.
- Tests never launch Chrome. The test file replaces `system`.

## Global Side Effects

- `my-choosy` appends to `~/Library/Logs/my-choosy.log` and runs `open` for Google Chrome.
- `bin/build` writes `build/`. With `--install` it writes `~/Applications/my-choosy.app` and the user LaunchServices database (`lsregister -f`).
- macOS registers each built copy (for example `build/my-choosy.app`) with LaunchServices on its own. Extra copies with the bundle ID `local.my-choosy` can keep the app out of the System Settings browser list. Remove them with `lsregister -u <path>`.

## System Verification

- Run: `ruby test/my_choosy_test.rb`
- Run: `RUBY=<absolute ruby> bin/build`, then `codesign --verify build/my-choosy.app`
