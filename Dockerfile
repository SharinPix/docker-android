FROM ubuntu:24.04

USER root

# update image and install required packages
RUN apt update && apt install -y default-jdk

ENV JAVA_HOME=/usr/lib/jvm/default-java
ENV JDK_HOME=${JAVA_HOME}
ENV JRE_HOME=${JDK_HOME}

#  Install wget and unzip
RUN apt-get install -y wget unzip

# Install Gradle 7.6
RUN wget https://services.gradle.org/distributions/gradle-7.6-bin.zip -P /tmp && \
    unzip -d /opt/gradle /tmp/gradle-7.6-bin.zip && \
    ln -s /opt/gradle/gradle-7.6/bin/gradle /usr/bin/gradle && \
    rm /tmp/gradle-7.6-bin.zip

ENV ANDROID_HOME=/opt/android-sdk

# Install Android SDK Tools
RUN wget https://dl.google.com/android/repository/commandlinetools-linux-9123335_latest.zip -P /tmp && \
    mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    unzip -d ${ANDROID_HOME}/cmdline-tools /tmp/commandlinetools-linux-9123335_latest.zip && \
    mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID-WORK_DIR}/cmdline-tools/latest && \
    rm /tmp/commandlinetools-linux-9123335_latest.zip

# Set PATH to include the bin directory of the cmdline-tools
ENV PATH=${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin

# Accept licenses and install SDK components
RUN yes | ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --licenses && \
    ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager "platform-tools" "platforms;android-30" "build-tools;30.0.3" "extras;google;m2repository" "extras;android;m2repository"