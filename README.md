# my-choosy

A small macOS "browser dispatcher". Set it as the default web browser. It
opens each `http` or `https` link in the Chrome profile that the link matches.

## How it works

1. You click a link in an app (Slack, Mail, a terminal).
2. macOS sends the URL to `my-choosy.app` as an Apple Event, not as a
   command-line argument. A bare script cannot be the default browser, so
   the app is a small AppleScript wrapper.
3. The app runs the Ruby script `my-choosy` with the full URL as the only
   argument.
4. The script reads `~/.config/my-choosy/config.yml`, picks a profile, and
   runs `open -na "Google Chrome" --args --profile-directory=<profile> <url>`.

The script reads the config on each link, so config edits apply at once.

## Config

Copy the example, then edit it:

```sh
mkdir -p ~/.config/my-choosy
cp config.example.yml ~/.config/my-choosy/config.yml
```

```yaml
- profile: Default
  match: []
- profile: Profile 1
  match:
    - github
    - atlassian.net
```

- `profile` is the Chrome profile folder name. See
  [Find profile folder names](#find-profile-folder-names).
- `match` is a list of URL fragments. A URL matches if it contains the
  fragment at any position: host, path, or query. The match ignores case.
- **The first profile in the list is the fallback.** A URL that matches no
  fragment opens in it.
- The first match wins. The script checks the profiles in list order.
- If the config is missing or invalid, the script logs the error and opens
  the link in Chrome with no profile flag. Chrome then uses its last-used
  profile.

## Find profile folder names

Chrome shows a display name (for example "Work"). The config needs the folder
name (for example `Profile 1`). To list both:

```sh
jq -r '.profile.info_cache | to_entries[] | "\(.key)\t\(.value.name)"' \
  "$HOME/Library/Application Support/Google/Chrome/Local State"
```

Example output (folder, then display name):

```text
Default Work
Profile 1 Home
```

## Build

No step needs root or sudo.

Requirements:

- macOS with Google Chrome in `/Applications`.
- A Ruby that has `YAML.safe_load_file` (`/usr/bin/ruby` 2.6 does not).

Build and install:

```sh
RUBY="$(mise which ruby)" bin/build --install
```

- `RUBY` must be an absolute path. The app gets no shell environment, so it
  calls this Ruby directly. If you leave `RUBY` unset, the script uses
  `command -v ruby`.
- `bin/build` without `--install` builds `build/my-choosy.app` only.
- `--install` copies the app to `~/Applications/my-choosy.app` and registers
  it with LaunchServices (`lsregister -f`).
- The build copies `my-choosy` into the app. Run `bin/build --install` again
  after you edit the script, or after a Ruby upgrade removes the old Ruby
  path. Config edits need no build.

Run the tests:

```sh
ruby test/my_choosy_test.rb
```

## Set as default browser

1. Open System Settings > Desktop & Dock.
2. Set "Default web browser" to `my-choosy`.
3. Confirm the dialog.
4. Test it:

   ```sh
   open https://github.com
   tail -1 ~/Library/Logs/my-choosy.log
   ```

   The log line shows the profile that the script picked.

## Troubleshoot

- **Log:** `~/Library/Logs/my-choosy.log`. The script writes one line for
  each link and each error.
- **The app is not in the System Settings list:** run `bin/build --install`
  again. It runs `lsregister -f`.
- **Check the signature:** `codesign --verify ~/Applications/my-choosy.app`.
  An edit to `Info.plist` breaks the signature. `bin/build` signs the app
  again.
- **Check the default handler:**

  ```sh
  defaults read ~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers | grep -B2 -A2 my-choosy
  ```

- **A link opens in the wrong profile:** check that `profile` is the folder
  name, not the display name. Check the fragment order: the first match wins.
- **Nothing opens:** look for `ERROR` in the log. A URL that does not start
  with `http://` or `https://` opens nothing.
