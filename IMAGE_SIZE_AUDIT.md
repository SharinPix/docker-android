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

## What `cimg/android` itself cost (removed by the multi-stage build)

Android `extras` m2repositories + fastlane + firebase (676 MB), tools/platform-tools + 3 build-tools (651 MB),
JDK 8 + 17 + 21 + system ruby (530 MB), platforms 29→35 (403 MB), gcloud SDK (275 MB), docker CLI (158 MB), etc.

## Changes in this branch: multi-stage build on a slim base

The image no longer starts `FROM cimg/android`. It is now built in two stages:

1. **`sdk` stage**: starts from `cimg/base:2026.10-22.04`, downloads the Android cmdline-tools, accepts the
   licenses, and installs only `platform-tools`, `platforms;android-35`, `build-tools;35.0.0`,
   `ndk;29.0.13599879` and cmake 3.6/3.10, plus Gradle 8.13. This stage is not shipped.
2. **Final stage**: starts from `cimg/base:2026.10-22.04` (Ubuntu 22.04, ~400 MB, same OS as
   `cimg/android`, and it keeps CircleCI's tooling: git, ssh, jq, docker CLI, sudo). It installs JDK 21
   (headless), the rbenv build deps and pip in one cleaned apt layer, then creates `node` with **uid/gid 1000**.
   It then copies the SDK with `COPY --from=sdk --chown=1000:1000`, so the SDK is **stored once and writable
   by `node`**: AGP can auto-install a missing platform or build-tools at build time. Node 22.19 (nvm),
   cordova/ionic, and Ruby 3.4.9 (rbenv) are installed as before, with caches and docs stripped.

Versions are build `ARG`s at the top of the Dockerfile (`ANDROID_PLATFORM`, `BUILD_TOOLS_VERSION`,
`NDK_VERSION`, `GRADLE_VERSION`, `CMDLINE_TOOLS_VERSION`, `BASE_IMAGE`).

**Estimated size: about 2.2 GB compressed** (from 7.19 GB), to be confirmed by the CI build:
base ~400 MB, NDK ~790 MB, cmdline-tools + platform + build-tools + platform-tools ~270 MB, Gradle ~140 MB,
JDK + apt ~120 MB, Node + cordova ~130 MB, Ruby ~90 MB.

### Behaviour changes to check

| Change | Impact |
|---|---|
| SDK path is now **`/opt/android-sdk`** (was `/home/circleci/android-sdk`) | `ANDROID_HOME`, `ANDROID_SDK_ROOT`, `ANDROID_NDK_HOME`, `ANDROID_NDK_ROOT` and `CMDLINE_TOOLS_ROOT` are all updated. Anything that hard-codes the old path (for example `local.properties` with `sdk.dir=`) must change. |
| Only **platform android-35** is preinstalled (was 29 to 35) | Other platforms are downloaded on demand by AGP, because the SDK is now writable. Add more with the `ANDROID_PLATFORM` arg if you want them preinstalled. |
| Only **build-tools 35.0.0** (was also 34.0.0-rc3, 35.0.1, 36.0.0-rc5) | Same: downloaded on demand. |
| Removed: **JDK 8 and 17, Maven, Ant, system Ruby, fastlane, firebase-tools, gcloud SDK, yarn, legacy SDK `tools`, emulator, m2 extras** | If a pipeline used one of these, add it back explicitly. fastlane can be installed with the rbenv Ruby (`gem install fastlane`). Yarn is available through `corepack enable`. |
| JDK 21 is **headless** | No GUI libraries; Gradle builds do not need them. |
| cordova/ionic are installed into the nvm Node 22.19 (was the base image's `/usr/local` Node) | They now run on the Node version you pinned. |
| `git config --system safe.directory '*'` | Avoids "dubious ownership" errors on mounted folders. |

## Further options

| Option | Est. saving | Trade-off |
|---|---:|---|
| Drop the NDK if no Cordova plugin compiles native code | ~790 MB | AGP downloads it on demand if a build needs it (the SDK is writable). |
| Drop `cmake;3.6` / `cmake;3.10` | ~28 MB | Check no plugin pins these. |
| Drop nvm and install Node 22.19 from the official tarball into `/usr/local` | small | Removes nvm; `source $NVM_DIR/nvm.sh` stops working. |

## CI notes

The CircleCI config was reworked in this branch:

- Build, smoke test and push now run in **one job**. Before, the `build` job ran `docker save` on the 7 GB
  image, uploaded it to the workspace, and the publish job downloaded it and ran `docker load`.
- The executor image is `cimg/base:current`. Before, it was `circleci/buildpack-deps:stretch`, which is deprecated and on Debian 9 (end of life).
- The executor pull and the build both log in to Docker Hub, so they are not hit by the anonymous pull rate limit.
- **Smoke test:** the job checks that the user is uid/gid 1000, that the SDK is writable, and that java, gradle, node, ruby, cordova, ionic and sdkmanager all run.
- **Tags:**
  - `main` pushes `latest` plus an immutable `sha-<commit>` tag.
  - Other branches push `circle-<build>`, `sha-<commit>`, and `pr-<n>` only when a PR exists. Before, a branch without a PR pushed a meaningless `pr-` tag.
