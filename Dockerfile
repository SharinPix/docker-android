FROM cimg/android:2021.10.2-node
USER node
RUN sudo npm install --unsafe-perm=true --allow-root -g cordova@10.0.0 @ionic/cli@6.1.0
