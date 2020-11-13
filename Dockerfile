FROM circleci/android:api-28-node

RUN sudo apt-get update && \
    cd /tmp && wget -O ruby-install-0.6.1.tar.gz https://github.com/postmodern/ruby-install/archive/v0.6.1.tar.gz && \
    tar -xzvf ruby-install-0.6.1.tar.gz && \
    cd ruby-install-0.6.1 && \
    sudo make install && \
    ruby-install --cleanup ruby 2.6.3 && \
    rm -r /tmp/ruby-install-* && \
    sudo rm -rf /var/lib/apt/lists/*
