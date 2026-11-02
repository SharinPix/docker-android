# Image size audit — `sharinpix/docker-android`

Data: Docker Hub layer sizes (compressed, amd64) for `sharinpix/docker-android:latest`
(pushed 2026-10-14) and its base `cimg/android:2025.03.1-node`.

| | Compressed size |
|---|---|
| `cimg/android:2025.03.1-node` (base) | **3.31 GB** |
| `sharinpix/docker-android:latest` | **7.19 GB** |
| Added by our Dockerfile | **3.88 GB** |

## Where our 3.88 GB comes from

| Layer (our Dockerfile) | Size | Notes |
|---|---:|---|
| `sudo chown -R node:node /home/circleci` | **2,678 MB** | Rewrites every file of the Android SDK + NDK into a new layer (overlayfs copies a file when its metadata changes). Pure duplication. |
| `sdkmanager "ndk;29.0.13599879"` | 793 MB | Needed only if a project builds native code. |
| rbenv + Ruby 3.4.9 + apt deps | 126 MB | apt lists not cleaned, rdoc/ri generated. |
| nvm + Node 22.19.0 | 88 MB | Includes nvm's tarball cache; base already ships a Node LTS in `/usr/local`. |
| `build-tools;35.0.0` | 62 MB | Base already has `35.0.1`, `36.0.0-rc5`, `34.0.0-rc3`. |
| cordova + ionic (global) | 45 MB | |
| apt: build-essential, git, vim, libpq-dev… | 33 MB | |
| cmake 3.6 + 3.10 | 28 MB | Very old; AGP/NDK 29 use cmake 3.22+. |
| python3-pip | 24 MB | apt lists not cleaned. |

## What the base image already costs (cannot be removed while we `FROM` it)

Android `extras` m2repositories + fastlane + firebase (676 MB), tools/platform-tools + 3 build-tools (651 MB),
JDK 8 + 17 + 21 + system ruby (530 MB), platforms 29→35 (403 MB), gcloud SDK (275 MB), docker CLI (158 MB), etc.

## Changes in this branch

1. **Remove the `chown -R /home/circleci` layer (−~2.7 GB, −37%)** — the base `circleci` user
   (uid/gid 3434) is renamed to `node` instead of creating a new uid 1000 user. Since ownership is stored
   by numeric uid, `node` owns the SDK without any file being rewritten, so Gradle/sdkmanager can still
   write into the SDK.
   **Behaviour change:** the `node` user is now **uid 3434** instead of 1000. This only matters if
   something bind-mounts host directories expecting uid 1000.
2. Merge the three `apt-get install` layers into one and clean apt lists in the same layer.
3. Clear nvm's download cache and npm caches.
4. Build Ruby with `--disable-install-doc` and install gems with `--no-document`.

Expected result: roughly **4.4 GB compressed** (from 7.19 GB). Must be confirmed by a CI build.

## Further options (not applied — need a product decision)

| Option | Est. saving | Trade-off |
|---|---:|---|
| Drop the NDK if no Cordova plugin compiles native code (or let AGP fetch it on demand) | ~790 MB | Builds that need it download it at runtime. |
| Drop `cmake;3.6` / `cmake;3.10` | ~28 MB | Check no plugin pins these. |
| Drop `build-tools;35.0.0` and use base `35.0.1` | ~62 MB | cordova-android 13/14 asks for 35.0.0 exactly; AGP would download it at build time. |
| Drop nvm and use base's Node (or install 22.19 into `/usr/local` with a tarball) | ~90 MB | Base Node version is whatever was LTS in 2025-03. |
| Rebuild from `cimg/base` / `ubuntu:22.04` with only: cmdline-tools, platform-tools, one platform, one build-tools, JDK 21, Gradle, Node, Ruby | **~2.5–3 GB** | More Dockerfile to maintain; removes JDK 8/17, gcloud, docker CLI, m2 extras, fastlane, firebase, platforms 29–34. Biggest possible win. |

## CI notes

- `docker save` → `persist_to_workspace` → `docker load` moves the full multi-GB tar between jobs; the
  size reduction speeds this up directly. Building and pushing in the same job would avoid it entirely.
- The executor image `circleci/buildpack-deps:stretch` is deprecated (Debian 9, EOL); `cimg/base:current` is the replacement.
