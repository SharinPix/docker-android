# Multi-stage build:
#   - stage `sdk` downloads the Android SDK, NDK and Gradle,
#   - the final stage starts from the slim CircleCI base image (Ubuntu 22.04, ~400 MB compressed,
#     same OS as cimg/android) and copies only what we need.
# The SDK is copied with `--chown=1000:1000`, so it is stored once and is writable by `node`
# (uid 1000, matches bind-mounted host folders): AGP can auto-install missing SDK packages.

ARG BASE_IMAGE=cimg/base:2026.10-22.04
ARG CMDLINE_TOOLS_VERSION=11076708
ARG GRADLE_VERSION=8.13
ARG ANDROID_PLATFORM=android-35
ARG BUILD_TOOLS_VERSION=35.0.0
ARG NDK_VERSION=29.0.13599879

########################################################################################
FROM ${BASE_IMAGE} AS sdk

ARG CMDLINE_TOOLS_VERSION
ARG GRADLE_VERSION
ARG ANDROID_PLATFORM
ARG BUILD_TOOLS_VERSION
ARG NDK_VERSION

USER root
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=/opt/android-sdk

RUN apt-get update \
  && apt-get install -y --no-install-recommends openjdk-21-jdk-headless \
  && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/cmdline-tools.zip \
      "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip" \
  && mkdir -p /tmp/cmdline-tools "${ANDROID_HOME}/cmdline-tools" \
  && unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools \
  && mv /tmp/cmdline-tools/cmdline-tools "${ANDROID_HOME}/cmdline-tools/latest" \
  && rm -rf /tmp/*

# `yes` is wrapped because the base image's SHELL uses `-o pipefail` and `yes` exits on SIGPIPE.
RUN SDKMANAGER="${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" \
  && (yes || true) | "${SDKMANAGER}" --licenses > /dev/null \
  && "${SDKMANAGER}" --install \
      "platform-tools" \
      "platforms;${ANDROID_PLATFORM}" \
      "build-tools;${BUILD_TOOLS_VERSION}" \
      "ndk;${NDK_VERSION}" \
      "cmake;3.6.4111459" \
      "cmake;3.10.2.4988404" \
  && rm -rf "${ANDROID_HOME}/.temp" "${ANDROID_HOME}/.downloadIntermediates"

RUN curl -fsSL -o /tmp/gradle.zip "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" \
  && unzip -q /tmp/gradle.zip -d /opt \
  && mv "/opt/gradle-${GRADLE_VERSION}" /opt/gradle \
  && rm -f /tmp/gradle.zip

########################################################################################
FROM ${BASE_IMAGE}

ARG BUILD_TOOLS_VERSION
ARG NDK_VERSION

USER root

# System packages. The base image already ships build-essential, git, curl, vim, unzip, zip,
# libpq-dev, libssl-dev, jq, sudo; they are listed anyway so the requirement is explicit.
RUN apt-get update -qq \
  && apt-get install -y -qq --no-install-recommends \
    openjdk-21-jdk-headless \
    build-essential autoconf bison git curl vim \
    # for rbenv / ruby-build
    libssl-dev libreadline-dev zlib1g-dev libyaml-dev libncurses5-dev libffi-dev libgdbm-dev \
    # for postgres
    libpq-dev \
    python3-pip \
  && apt-get clean \
  && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && truncate -s 0 /var/log/*log

RUN groupadd --gid 1000 node \
  && useradd --uid 1000 --gid node --shell /bin/bash --create-home node \
  && echo 'node ALL=NOPASSWD: ALL' > /etc/sudoers.d/node \
  && echo 'Defaults    env_keep += "DEBIAN_FRONTEND"' > /etc/sudoers.d/env_keep \
  && chmod 0440 /etc/sudoers.d/node /etc/sudoers.d/env_keep \
  && git config --system --add safe.directory '*'

COPY --from=sdk --chown=1000:1000 /opt/android-sdk /opt/android-sdk
COPY --from=sdk /opt/gradle /opt/gradle

ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
ENV GRADLE_HOME=/opt/gradle
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV CMDLINE_TOOLS_ROOT=/opt/android-sdk/cmdline-tools/latest/bin
ENV ADB_INSTALL_TIMEOUT=120
ENV BUILD_TOOLS_VERSION=${BUILD_TOOLS_VERSION}
ENV NDK_LTS_VERSION=${NDK_VERSION}
ENV ANDROID_NDK_HOME=/opt/android-sdk/ndk/${NDK_VERSION}
ENV ANDROID_NDK_ROOT=/opt/android-sdk/ndk/${NDK_VERSION}
ENV PATH=${ANDROID_NDK_HOME}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${GRADLE_HOME}/bin:${PATH}

USER node
ENV HOME=/home/node
ENV PATH=/home/node/.local/bin:/home/node/bin:${PATH}
WORKDIR /home/node

# Node.js via nvm
ENV NVM_DIR=/home/node/.nvm
ENV NODE_VERSION=22.19.0
RUN curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash \
  && source "$NVM_DIR/nvm.sh" \
  && nvm install "$NODE_VERSION" \
  && nvm alias default "$NODE_VERSION" \
  && nvm use default \
  && npm install -g cordova@12.0.0 @ionic/cli@6.20.3 \
  && nvm cache clear \
  && npm cache clean --force \
  && rm -rf "$NVM_DIR/.git" "$NVM_DIR/test" "$HOME/.npm" /tmp/*

ENV NODE_PATH=$NVM_DIR/versions/node/v$NODE_VERSION/lib/node_modules
ENV PATH=$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

# Ruby via rbenv (no rdoc/ri for ruby nor gems)
ENV PATH=/home/node/.rbenv/bin:/home/node/.rbenv/shims:$PATH
ENV RUBY_CONFIGURE_OPTS=--disable-install-doc
RUN curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash \
  && rbenv install 3.4.9 \
  && rbenv global 3.4.9 \
  && echo 'eval "$(rbenv init -)"' >> /home/node/.bashrc \
  && echo 'gem: --no-document' >> /home/node/.gemrc \
  && gem install bundler \
  && rm -rf /home/node/.rbenv/cache /home/node/.rbenv/sources /tmp/ruby-build* /home/node/.gem/specs

RUN java -version && gradle -v && ruby -v && node -v && pip -V \
  && sdkmanager --version && adb version

CMD ["/bin/sh"]
