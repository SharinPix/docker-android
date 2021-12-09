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

RUN sudo npm install --unsafe-perm=true --allow-root -g cordova@10.0.0 @ionic/cli@6.1.0

RUN sudo apt install git curl libssl-dev libreadline-dev zlib1g-dev autoconf bison build-essential libyaml-dev libreadline-dev libncurses5-dev libffi-dev libgdbm-dev && \
  bash -c "curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash" && \
  bash -c "rbenv install 2.7.2" && \
  echo 'eval "$(rbenv init -)"' >> /home/user/.bashrc && \
  bash -c "rbenv global 2.7.2" && \
  bash -c "/home/node/.rbenv/shims/gem install bundler"

WORKDIR /home/node
