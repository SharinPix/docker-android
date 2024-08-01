FROM cimg/android:2024.07.1-node

RUN echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "cmake;3.6.4111459" && \
	echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "cmake;3.10.2.4988404"

# Setup LTS release
ENV NDK_LTS_VERSION "25.1.8937393"
ENV ANDROID_NDK_HOME "/home/circleci/android-sdk/ndk/${NDK_LTS_VERSION}"
RUN echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "ndk;${NDK_LTS_VERSION}"

# Setup build tools
ENV BUILD_TOOLS_VERSION "34.0.0"
RUN echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "build-tools;${BUILD_TOOLS_VERSION}"

ENV ANDROID_NDK_ROOT "${ANDROID_NDK_HOME}"
ENV PATH "${ANDROID_NDK_HOME}:${PATH}"

USER root

RUN groupadd --gid 1000 node \
  && useradd --uid 1000 --gid node --shell /bin/bash --create-home node \
  && echo 'node ALL=NOPASSWD: ALL' >> /etc/sudoers.d/50-circleci \
  && echo 'Defaults    env_keep += "DEBIAN_FRONTEND"' >> /etc/sudoers.d/env_keep

USER node
ENV HOME /home/node
ENV PATH /home/node/.local/bin:/home/node/bin:${PATH}

CMD ["/bin/sh"]

RUN sudo chown -R node:node /home/node
RUN sudo chown -R node:node /home/circleci

# Switching user can confuse Docker's idea of $HOME, so we set it explicitly
ENV HOME /home/node

RUN sudo npm install --unsafe-perm=true --allow-root -g cordova@12.0.0 @ionic/cli@6.20.3

RUN sudo apt-get update -qq && \
  DEBIAN_FRONTEND=noninteractive sudo apt-get install -y -qq --no-install-recommends \
    # for ruby-dev
    build-essential\
    git \
    vim \
    # for rbenv
    libssl-dev libreadline-dev zlib1g-dev \
    # for postgres
    libpq-dev \
  && sudo apt-get clean \
  && sudo rm -rf /var/cache/apt/archives/* \
  && sudo rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && sudo truncate -s 0 /var/log/*log

ENV PATH="/home/node/.rbenv/bin:/home/node/.rbenv/shims:$PATH"

ENV NVM_DIR="$HOME/.nvm"
ENV NODE_VERSION="20.15.0"

RUN curl https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash \
    && source $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

ENV NODE_PATH="$NVM_DIR/v$NODE_VERSION/lib/node_modules"
ENV PATH="$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH"

# Latest gcloud version can be found here: https://cloud.google.com/sdk/docs/release-notes
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - 

RUN sudo apt-get update && \
  sudo apt-get install git curl libssl-dev libreadline-dev bison zlib1g-dev autoconf build-essential libyaml-dev libreadline-dev libncurses5-dev libffi-dev libgdbm-dev && \
  bash -c "curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash" && \
  bash -c "rbenv install 3.1.4" && \
  echo 'eval "$(rbenv init -)"' >> /home/node/.bashrc && \
  bash -c "rbenv global 3.1.4" && \
  bash -c "/home/node/.rbenv/shims/gem install bundler"

RUN sudo apt-get update && sudo apt-get install python3-pip

ENV JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"

RUN java -version && gradle -v && ruby -v && node -v && pip -V

WORKDIR /home/node
