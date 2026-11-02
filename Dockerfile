FROM cimg/android:2025.03.1-node

RUN echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "cmake;3.6.4111459" && \
	echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "cmake;3.10.2.4988404"

# Setup LTS release
ENV NDK_LTS_VERSION "29.0.13599879"
ENV ANDROID_NDK_HOME "/home/circleci/android-sdk/ndk/${NDK_LTS_VERSION}"
RUN echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "ndk;${NDK_LTS_VERSION}"

# Setup build tools
ENV BUILD_TOOLS_VERSION "35.0.0"
RUN echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "build-tools;${BUILD_TOOLS_VERSION}"

ENV ANDROID_NDK_ROOT "${ANDROID_NDK_HOME}"
ENV PATH "${ANDROID_NDK_HOME}:${PATH}"

USER root

# `node` keeps uid/gid 1000 (host folders are bind-mounted with that uid).
# We deliberately do NOT `chown -R node:node /home/circleci`: changing ownership
# rewrites every file of the Android SDK/NDK into a new layer (~2.7 GB
# compressed). The SDK files are world-readable, and `node` is added to the
# `circleci` group so it can traverse /home/circleci even if it is mode 750.
# The SDK is therefore read-only for `node`: every SDK package the builds need
# must be installed above (or with `sudo sdkmanager ...` at build time).
RUN groupadd --gid 1000 node \
  && useradd --uid 1000 --gid node --groups circleci --shell /bin/bash --create-home node \
  && echo 'node ALL=NOPASSWD: ALL' >> /etc/sudoers.d/50-circleci \
  && echo 'Defaults    env_keep += "DEBIAN_FRONTEND"' >> /etc/sudoers.d/env_keep

# All apt packages in a single layer, with the apt lists removed in that same layer.
RUN apt-get update -qq && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
    # build toolchain (ruby-dev, native gems, rbenv)
    build-essential autoconf bison \
    git curl vim \
    # for rbenv / ruby-build
    libssl-dev libreadline-dev zlib1g-dev libyaml-dev libncurses5-dev libffi-dev libgdbm-dev \
    # for postgres
    libpq-dev \
    python3-pip \
  && apt-get clean \
  && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && truncate -s 0 /var/log/*log

USER node
ENV HOME /home/node
ENV PATH /home/node/.local/bin:/home/node/bin:${PATH}
WORKDIR /home/node

CMD ["/bin/sh"]

RUN sudo npm install --unsafe-perm=true --allow-root -g cordova@12.0.0 @ionic/cli@6.20.3 \
  && sudo npm cache clean --force \
  && sudo rm -rf /root/.npm /tmp/*

ENV PATH="/home/node/.rbenv/bin:/home/node/.rbenv/shims:$PATH"

ENV NVM_DIR="$HOME/.nvm"
ENV NODE_VERSION="22.19.0"

RUN curl https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash \
    && source $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default \
    && nvm cache clear \
    && npm cache clean --force \
    && rm -rf $NVM_DIR/.git $NVM_DIR/test $HOME/.npm

ENV NODE_PATH="$NVM_DIR/v$NODE_VERSION/lib/node_modules"
ENV PATH="$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH"

# Skip rdoc/ri generation for the compiled ruby and for gems (not needed in CI).
ENV RUBY_CONFIGURE_OPTS="--disable-install-doc"
RUN bash -c "curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash" && \
  bash -c "rbenv install 3.4.9" && \
  echo 'eval "$(rbenv init -)"' >> /home/node/.bashrc && \
  bash -c "rbenv global 3.4.9" && \
  echo 'gem: --no-document' >> /home/node/.gemrc && \
  bash -c "/home/node/.rbenv/shims/gem install bundler" && \
  rm -rf /home/node/.rbenv/cache /home/node/.rbenv/sources /tmp/ruby-build* /home/node/.gem/specs

ENV JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"

RUN java -version && gradle -v && ruby -v && node -v && pip -V
