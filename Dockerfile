FROM ubuntu:24.04

RUN sudo apt-get update && sudo apt-get install -y \
		ant \
		openjdk-8-jdk \
		openjdk-11-jdk \
		ruby-full \
	&& \
	sudo rm -rf /var/lib/apt/lists/* && \
	ruby -v && \
	sudo gem install bundler && \
	bundle version

ENV M2_HOME /usr/local/apache-maven
ENV MAVEN_OPTS -Xmx2048m
ENV PATH $M2_HOME/bin:$PATH
# Set JAVA_HOME (and related) environment variable. This will be set to our
# default Java version of 11 but the user would need to reset it when changing
# JAVA versions.
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV JDK_HOME=${JAVA_HOME}
ENV JRE_HOME=${JDK_HOME}
ENV MAVEN_VERSION "3.8.6"
RUN curl -sSL -o /tmp/maven.tar.gz http://apache.osuosl.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz && \
	sudo tar -xz -C /usr/local -f /tmp/maven.tar.gz && \
	sudo ln -sf /usr/local/apache-maven-${MAVEN_VERSION} /usr/local/apache-maven && \
	rm -rf /tmp/maven.tar.gz && \
	mkdir -p /home/circleci/.m2

ENV GRADLE_VERSION "7.6"
ENV PATH $PATH:/usr/local/gradle-${GRADLE_VERSION}/bin
RUN URL=https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip && \
	curl -sSL -o /tmp/gradle.zip $URL && \
	sudo unzip -d /usr/local /tmp/gradle.zip && \
	rm -rf /tmp/gradle.zip

# Install Android SDK Tools
ENV ANDROID_HOME "/home/circleci/android-sdk"
ENV ANDROID_SDK_ROOT $ANDROID_HOME
ENV CMDLINE_TOOLS_ROOT "${ANDROID_HOME}/cmdline-tools/latest/bin"
ENV ADB_INSTALL_TIMEOUT 120
ENV PATH "${ANDROID_HOME}/emulator:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/platform-tools/bin:${PATH}"
# You can find the latest command line tools here: https://developer.android.com/studio#command-line-tools-only
RUN SDK_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-9123335_latest.zip" && \
	mkdir -p ${ANDROID_HOME}/cmdline-tools && \
	mkdir ${ANDROID_HOME}/platforms && \
	mkdir ${ANDROID_HOME}/ndk && \
	wget -O /tmp/cmdline-tools.zip -t 5 "${SDK_TOOLS_URL}" && \
	unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_HOME}/cmdline-tools && \
	rm /tmp/cmdline-tools.zip && \
	mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest

RUN echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "tools" && \
	echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "platform-tools" && \
	echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "build-tools;33.0.1"

RUN echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "platforms;android-33" && \
	echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "platforms;android-32" && \
	echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "platforms;android-31" && \
	echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "platforms;android-30" && \
	echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "platforms;android-29" && \
	echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "platforms;android-28" && \
	echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "platforms;android-27"

# Install some useful packages
RUN echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "extras;android;m2repository" && \
	echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "extras;google;m2repository" && \
	echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "extras;google;google_play_services" && \
	sudo gem install fastlane --version 2.208.0 --no-document

# Install Google Cloud CLI
# Latest gcloud version can be found here: https://cloud.google.com/sdk/docs/release-notes
ENV GCLOUD_VERSION "412.0.0-0"
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - && \
	sudo add-apt-repository "deb https://packages.cloud.google.com/apt cloud-sdk main" && \
	sudo apt-get update && sudo apt-get install -y google-cloud-sdk=${GCLOUD_VERSION} && \
	sudo gcloud config set --installation component_manager/disable_update_check true && \
	sudo gcloud config set disable_usage_reporting false

RUN echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "cmake;3.6.4111459" && \
	echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "cmake;3.10.2.4988404"

# Setup LTS release
ENV NDK_LTS_VERSION "21.4.7075529"
ENV ANDROID_NDK_HOME "/home/circleci/android-sdk/ndk/${NDK_LTS_VERSION}"
RUN echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "ndk;${NDK_LTS_VERSION}"

# Setup build tools
ENV BUILD_TOOLS_VERSION "30.0.3"
RUN echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "build-tools;${BUILD_TOOLS_VERSION}"

ENV ANDROID_NDK_ROOT "${ANDROID_NDK_HOME}"
ENV PATH "${ANDROID_NDK_HOME}:${PATH}"

USER root

RUN groupadd --gid 1000 node \
  && useradd --uid 1000 --gid node --shell /bin/bash --create-home node \
  && echo 'node ALL=NOPASSWD: ALL' >> /etc/sudoers.d/50-circleci \
  && echo 'Defaults    env_keep += "DEBIAN_FRONTEND"' >> /etc/sudoers.d/env_keep

USER node
ENV PATH /home/node/.local/bin:/home/node/bin:${PATH}

CMD ["/bin/sh"]

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
ENV NODE_VERSION="16.17.0"

RUN curl https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash \
    && source $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

ENV NODE_PATH="$NVM_DIR/v$NODE_VERSION/lib/node_modules"
ENV PATH="$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH"

RUN sudo apt-get update && \
  sudo apt-get install git curl libssl-dev libreadline-dev bison zlib1g-dev autoconf build-essential libyaml-dev libreadline-dev libncurses5-dev libffi-dev libgdbm-dev && \
  bash -c "curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash" && \
  bash -c "rbenv install 3.1.4" && \
  echo 'eval "$(rbenv init -)"' >> /home/node/.bashrc && \
  bash -c "rbenv global 3.1.4" && \
  bash -c "/home/node/.rbenv/shims/gem install bundler"

RUN sudo apt-get update && sudo apt-get install python3-pip

ENV JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"

RUN java -version && gradle -v && ruby -v && node -v && pip -V

WORKDIR /home/node
