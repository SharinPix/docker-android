FROM cimg/android:2021.08.1

RUN npm install --unsafe-perm=true --allow-root -g cordova@10.0.0 @ionic/cli@6.1.0
