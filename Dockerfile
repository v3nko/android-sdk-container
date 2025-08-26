FROM ubuntu:latest

RUN apt-get update && apt-get upgrade -y && apt-get install openjdk-17-jdk wget unzip -y

ENV ANDROID_HOME=/opt/android
ENV PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools

RUN mkdir $ANDROID_HOME

RUN wget https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip -qO android-sdk.zip \
  && unzip android-sdk.zip -d $ANDROID_HOME \
  && mkdir $ANDROID_HOME/tmp/ \
  && mv $ANDROID_HOME/cmdline-tools/* $ANDROID_HOME/tmp \
  && mkdir $ANDROID_HOME/cmdline-tools/latest \
  && mv $ANDROID_HOME/tmp/* $ANDROID_HOME/cmdline-tools/latest \
  && rm -r $ANDROID_HOME/tmp/ \
  && rm android-sdk.zip

RUN echo "y" | sdkmanager "tools"
RUN echo "y" | sdkmanager "platform-tools"
RUN echo "y" | sdkmanager "build-tools;35.0.0"
RUN echo "y" | sdkmanager "build-tools;34.0.0"
RUN echo "y" | sdkmanager "build-tools;33.0.2"
RUN echo "y" | sdkmanager "build-tools;33.0.1"
RUN echo "y" | sdkmanager "extras;android;m2repository"
RUN echo "y" | sdkmanager "extras;google;m2repository"
RUN echo "y" | sdkmanager "platforms;android-36"
RUN echo "y" | sdkmanager --update

RUN apt-get install git curl iputils-ping dnsutils jsonnet -y \
  && wget -q https://gitlab.com/gitlab-org/cli/-/releases/v1.67.0/downloads/glab_1.67.0_linux_amd64.tar.gz \
  && tar -xzf glab_1.67.0_linux_amd64.tar.gz \
  && mv bin/glab /usr/local/bin/ \
  && rm -rf glab_1.67.0_linux_amd64.tar.gz bin CHANGELOG.md LICENSE README.md
RUN apt-get autoremove -y && apt-get clean
RUN rm -rf /var/lib/apt/lists/*

RUN ln -s $ANDROID_HOME /usr/lib/android-sdk
