FROM circleci/android:api-29-node

RUN sudo apt-get update && \
    cd /tmp && wget -O ruby-install-0.7.1.tar.gz https://github.com/postmodern/ruby-install/archive/v0.7.1.tar.gz && \
    tar -xzvf ruby-install-0.7.1.tar.gz && \
    cd ruby-install-0.7.1 && \
    sudo make install && \
    ruby-install --cleanup ruby 2.6.3 && \
    rm -r /tmp/ruby-install-* && \
    sudo rm -rf /var/lib/apt/lists/*

RUN echo 'PATH=/home/circleci/.rubies/ruby-2.6.3/bin' >> $BASH_ENV && \
    source /home/circleci/.bashrc

RUN sudo apt-get update && sudo apt-get install git
    
RUN sudo npm install --unsafe-perm=true --allow-root -g cordova@10.0.0 @ionic/cli@6.1.0

USER node
WORKDIR /home/circleci
