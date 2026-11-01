# Building and installing

Everything is compiled by GitHub Actions. Your PC only edits and uploads files.

## 1. Upload the project

The repository must contain `icon.png` in the root. It has to be a square PNG, at least
512x512 (1024x1024 recommended).

Ways to upload from a weak PC:

- **GitHub Desktop** (small program, no build tools): clone the repository, copy your
  files in, commit, push.
- **Web upload**: *Add file → Upload files*. The browser accepts about 100 files per
  upload and 25 MB per file, so upload folders in several rounds.

GitHub rejects files over 100 MB on push, so keep each asset file small.

## 2. Run the build

1. Open your repository on github.com and click the **Actions** tab.
2. Choose **Build Android APK** in the left list.
3. Click **Run workflow**, keep the defaults, and click the green **Run workflow** button.
4. Wait for the run to finish. The first run is slower because it downloads Godot and the
   Android tools. Later runs reuse caches.

Options:

| Option | Default | Meaning |
|---|---|---|
| universal | on | Also build the single APK that contains both 64-bit and 32-bit code |
| debug_build | off | Use the debug engine (slower game, only needed for diagnostics) |

The workflow never runs automatically on push. Start it only when a phase is ready.

## 3. Download the APK

1. Click the finished run (green tick).
2. Scroll down to **Artifacts**.
3. Click the artifact name to download a ZIP, then unzip it. The APK is inside.

| Artifact | Use it when |
|---|---|
| `quietfront-arm64-v8a` | Almost every phone from about 2017 onwards. Smallest download. |
| `quietfront-armeabi-v7a` | Older phones with a 32-bit processor |
| `quietfront-universal` | You are not sure; works on both, larger |

The run summary lists the exact size of every APK.

## 4. Install on a phone

1. Copy the APK to the phone (USB, cloud drive, messaging app).
2. Open it with a file manager. When Android asks, allow **Install unknown apps** for that
   file manager or browser.
3. Install and open **Quiet Front**.

### If the install fails

Test builds are signed with a throwaway test key. The key is kept in the GitHub cache so
new builds can be installed over old ones. If GitHub clears the cache (it does after about
a week without builds), the next build uses a new key and Android refuses to update.

**Fix:** uninstall the old Quiet Front, then install the new APK. The run summary says
whether the test key was reused or newly created.

## 5. What the workflow does

1. Checks out the repository and fixes Windows line endings in `tools/`.
2. Installs Java 17 and Python.
3. Validates the project (`tools/validate_project.py`). Missing files, a bad `icon.png`,
   broken JSON or unlicensed assets stop the build with a clear message.
4. Creates or restores the test signing key.
5. Installs the Android SDK and Godot with the Android export templates (cached).
6. Generates the launcher icons from `icon.png` and placeholder images.
7. Imports the assets, checks every script for errors and runs the logic tests.
8. Exports the APKs and uploads them as artifacts (kept 14 days).

## 6. Limits to know about

- GitHub's free plan has monthly limits for private-repository Actions minutes and for
  artifact storage. If you run out, download what you need, delete old runs, or check your
  plan. The limits change, so check GitHub's current numbers.
- Artifacts expire after 14 days. Download what you want to keep.

## 7. Troubleshooting

| Failing step | What it usually means |
|---|---|
| Validate project files | Read the listed messages: a file is missing or empty, `icon.png` is missing or not square, or an asset pack is not in `docs/ASSETS.md` |
| Install Android SDK | Download problem; run the workflow again. If it repeats, send me the log |
| Install Godot | Same; the log shows which download failed or whether a checksum did not match |
| Check scripts and run logic tests | A script has a syntax error. The log names the file; send me the message |
| Export APKs | Usually a missing Android SDK component or a project setting problem. Send me the log |

When you report a problem, copy the red error lines from the failed step.