FROM ubuntu:latest

RUN apt update && apt upgrade -y && apt install openjdk-11-jdk wget unzip git -y && apt clean

ENV ANDROID_HOME /opt/android
ENV PATH ${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools

RUN mkdir $ANDROID_HOME

RUN wget https://dl.google.com/android/repository/commandlinetools-linux-8512546_latest.zip -qO android-sdk.zip \
  && unzip android-sdk.zip -d $ANDROID_HOME \
  && mkdir $ANDROID_HOME/tmp/ \
  && mv $ANDROID_HOME/cmdline-tools/* $ANDROID_HOME/tmp \
  && mkdir $ANDROID_HOME/cmdline-tools/latest \
  && mv $ANDROID_HOME/tmp/* $ANDROID_HOME/cmdline-tools/latest \
  && rm -r $ANDROID_HOME/tmp/ \
  && rm android-sdk.zip

RUN echo "y" | sdkmanager "tools"
RUN echo "y" | sdkmanager "platform-tools"
RUN echo "y" | sdkmanager "build-tools;32.0.0"
RUN echo "y" | sdkmanager "extras;android;m2repository"
RUN echo "y" | sdkmanager "extras;google;m2repository"
RUN echo "y" | sdkmanager "platforms;android-31"
RUN echo "y" | sdkmanager --update
RUN rm -rf /var/lib/apt/lists/*

RUN ln -s $ANDROID_HOME /usr/lib/android-sdk
