FROM cimg/android:2021.10.2-node

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

RUN sudo npm install --unsafe-perm=true --allow-root -g cordova@10.0.0 @ionic/cli@6.18.1

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

RUN sudo apt-get update && \
  sudo apt-get install git curl libssl-dev libreadline-dev bison zlib1g-dev autoconf build-essential libyaml-dev libreadline-dev libncurses5-dev libffi-dev libgdbm-dev && \
  bash -c "curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash" && \
  bash -c "rbenv install 2.7.2" && \
  echo 'eval "$(rbenv init -)"' >> /home/node/.bashrc && \
  bash -c "rbenv global 2.7.2" && \
  bash -c "/home/node/.rbenv/shims/gem install bundler"

RUN sudo apt-get update && sudo apt-get install python3-pip

ENV JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"

RUN java -version && gradle -v && ruby -v && node -v && pip -V

WORKDIR /home/node
