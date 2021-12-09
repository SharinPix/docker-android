FROM cimg/android:2021.10.2-node

RUN sudo groupadd --gid 1000 node \
  && sudo useradd --uid 1000 --gid node --shell /bin/bash --create-home node \
  && sudo echo 'node ALL=NOPASSWD: ALL' >> /etc/sudoers.d/50-circleci \
  && sudo echo 'Defaults    env_keep += "DEBIAN_FRONTEND"' >> /etc/sudoers.d/env_keep

USER node
ENV PATH /home/node/.local/bin:/home/node/bin:${PATH}

CMD ["/bin/sh"]

# Switching user can confuse Docker's idea of $HOME, so we set it explicitly
ENV HOME /home/node

RUN sudo npm install --unsafe-perm=true --allow-root -g cordova@10.0.0 @ionic/cli@6.1.0

WORKDIR /home/node
