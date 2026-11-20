# Android SDK

[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.com/donate/?hosted_button_id=Q9WMN3C2JXDKS)

## Overview

Android SDK image with minimal required set of tools for CI deployment and headless Android Emulator execution. **Does not contain system images or AVD data** inside the Docker image to minimize the footprint; system images and AVDs are cached on the host and initialized on demand.

Preinstalled tools/components:

Tool/Component | Version
------- | -------
Eclipse Temurin JDK | 21
Android SDK Build-Tools | 35.0.0, 34.0.0, 33.0.2, 33.0.1
Android SDK Platform | 36
Android Emulator | Latest (`emulator`)
Node.js | 24
GitLab CLI | 1.115.0

Additionally installed from the Ubuntu repositories (versions follow the base image, so they are not pinned): `git`, `curl`, `wget`, `unzip`, `jsonnet`, `jq`, `iputils-ping`, `dnsutils`, `cpu-checker`, `pciutils`, and runtime graphics/audio libraries for headless SwiftShader execution (`libgl1`, `libpulse0`, `libnss3`, `libx11-6`, `libxcb1`, `libxcomposite1`, `libxcursor1`, `libxdamage1`, `libxext6`, `libxfixes3`, `libxi6`, `libxrandr2`, `libxrender1`, `libxtst6`, `libfontconfig1`, `libfreetype6`, `libdbus-1-3`, `libxkbcommon0`, `libxkbcommon-x11-0`).

## Quick start

### Gitea Actions runner (`act_runner`)

Deploying Gitea `act_runner` in Docker with KVM hardware acceleration and persistent host-mounted caches for Gradle, Android AVDs, system images, and licenses.

#### Target environment & host prerequisites

- **Architecture:** Linux x86_64, 4 CPU cores, 8 GB RAM.
- **KVM acceleration:** Ensure `/dev/kvm` exists and is accessible. Verify with `kvm-ok` (from package `cpu-checker`).
- **Device permissions:** Ensure the Docker daemon has read/write permissions to `/dev/kvm`:

    ```shell
    sudo chmod 666 /dev/kvm
    ```

    Alternatively, add the user running Docker to the `kvm` group:

    ```shell
    sudo usermod -aG kvm $USER
    ```

#### Prepare persistent host cache directories

Create persistent host directories for caching Gradle dependencies, AVD configuration, downloaded Android system images, and accepted licenses:

```shell
mkdir -p /srv/gitea-runner-data/mnt/.gradle \
         /srv/gitea-runner-data/mnt/.android \
         /srv/gitea-runner-data/mnt/android-sdk/system-images \
         /srv/gitea-runner-data/mnt/android-sdk/licenses \
         /srv/gitea-runner-data/data
```

#### Configure `act_runner` (`config.yaml`)

Generate or create `/srv/gitea-runner-data/config.yaml`:

```shell
docker run --entrypoint="" --rm gitea/act_runner:latest act_runner generate-config > /srv/gitea-runner-data/config.yaml
```

Update `/srv/gitea-runner-data/config.yaml` with the following configuration:

```yaml
runner:
  capacity: 1 # Tuned for 4 CPU cores and 8 GB RAM to avoid emulator concurrency thrashing
  timeout: 3h

container:
  privileged: false
  options: "--device /dev/kvm"
  valid_volumes:
    - /srv/gitea-runner-data/mnt/**
  volumes:
    - /srv/gitea-runner-data/mnt/.gradle:/root/.gradle
    - /srv/gitea-runner-data/mnt/.android:/root/.android
    - /srv/gitea-runner-data/mnt/android-sdk/system-images:/opt/android/system-images
    - /srv/gitea-runner-data/mnt/android-sdk/licenses:/opt/android/licenses
```

#### Deploy `act_runner` with Docker Compose

Create `/srv/gitea-runner-data/docker-compose.yml`:

```yaml
version: '3.8'

services:
  act-runner:
    image: gitea/act_runner:latest
    container_name: gitea-act-runner
    restart: unless-stopped
    environment:
      - CONFIG_FILE=/config.yaml
      - GITEA_INSTANCE_URL=https://gitea.example.com
      - GITEA_RUNNER_REGISTRATION_TOKEN=your_registration_token_here
      - GITEA_RUNNER_NAME=android-sdk-runner
      - GITEA_RUNNER_LABELS=ubuntu-latest:docker://venk0/android-sdk:latest,android-sdk:docker://venk0/android-sdk:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /srv/gitea-runner-data/config.yaml:/config.yaml
      - /srv/gitea-runner-data/data:/data
```

Start the runner:

```shell
docker compose -f /srv/gitea-runner-data/docker-compose.yml up -d
```

#### Example Gitea Actions workflow

Create `.gitea/workflows/instrumented-tests.yaml` in your Android project. This workflow initializes an AVD idempotently, starts the headless emulator with KVM acceleration and SwiftShader software rendering, waits for boot completion, executes Compose UI tests, and ensures a clean shutdown:

```yaml
name: Android UI Tests

on:
  push:
    branches: [main, dev]
  pull_request:

jobs:
  instrumented-tests:
    runs-on: ubuntu-latest
    container:
      image: venk0/android-sdk:latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Download system image
        run: |
          echo "y" | sdkmanager --install "system-images;android-35;google_apis;x86_64"

      - name: Initialize AVD idempotently
        run: |
          AVD_NAME="test_avd"
          if ! avdmanager list avd -c | grep -Fxq "${AVD_NAME}"; then
            echo "Creating AVD ${AVD_NAME}..."
            echo "no" | avdmanager create avd \
              --name "${AVD_NAME}" \
              --package "system-images;android-35;google_apis;x86_64" \
              --device "pixel" \
              --force

            # Optimize memory and CPU allocation for a 4-core, 8 GB RAM runner
            CONFIG_PATH="/root/.android/avd/${AVD_NAME}.avd/config.ini"
            if [ -f "${CONFIG_PATH}" ]; then
              sed -i 's/hw.ramSize=.*/hw.ramSize=2048/' "${CONFIG_PATH}" || echo "hw.ramSize=2048" >> "${CONFIG_PATH}"
              sed -i 's/vm.heapSize=.*/vm.heapSize=576M/' "${CONFIG_PATH}" || echo "vm.heapSize=576M" >> "${CONFIG_PATH}"
              sed -i 's/hw.cpu.ncore=.*/hw.cpu.ncore=2/' "${CONFIG_PATH}" || echo "hw.cpu.ncore=2" >> "${CONFIG_PATH}"
            fi
          else
            echo "AVD ${AVD_NAME} already exists. Skipping creation."
          fi

      - name: Launch headless emulator
        run: |
          nohup emulator -avd test_avd \
            -no-window \
            -no-audio \
            -no-boot-anim \
            -no-snapshot-load \
            -gpu swiftshader_indirect \
            -camera-back none \
            -camera-front none \
            -timezone UTC > /tmp/emulator.log 2>&1 &

      - name: Wait for emulator boot
        run: |
          echo "Waiting for emulator to connect and finish booting..."
          BOOT_COMPLETED=""
          TIMEOUT=300
          ELAPSED=0

          until [ "${BOOT_COMPLETED}" = "1" ] || [ ${ELAPSED} -ge ${TIMEOUT} ]; do
            if ! pgrep -f "emulator" > /dev/null; then
              echo "Error: Emulator process terminated unexpectedly."
              echo "--- Emulator Logs ---"
              cat /tmp/emulator.log
              exit 1
            fi

            BOOT_COMPLETED=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
            if [ "${BOOT_COMPLETED}" = "1" ]; then
              break
            fi

            sleep 2
            ELAPSED=$((ELAPSED + 2))
          done

          if [ "${BOOT_COMPLETED}" != "1" ]; then
            echo "Error: Emulator failed to boot within ${TIMEOUT} seconds."
            echo "--- Emulator Logs ---"
            cat /tmp/emulator.log
            exit 1
          fi

          echo "Emulator booted successfully. Disabling animations for stable Compose UI tests..."
          adb shell settings put global window_animation_scale 0.0
          adb shell settings put global transition_animation_scale 0.0
          adb shell settings put global animator_duration_scale 0.0

      - name: Run Compose UI tests
        run: |
          ./gradlew connectedAndroidTest -Dorg.gradle.jvmargs="-Xmx2048m -XX:MaxMetaspaceSize=512m"

      - name: Stop emulator
        if: always()
        run: |
          echo "Shutting down Android emulator..."
          adb emu kill || true
```

---

### GitLab docker runner

#### Register docker runner

1. Initiate registration

    ```shell
    docker run --rm -it -v /etc/gitlab-runner:/etc/gitlab-runner gitlab/gitlab-runner:latest register
    ```

    Update `/etc/gitlab-runner` directory or use volume if you prefer to store the configuration in another place.

1. Follow the registration steps.
1. On the `executor` configuration step set `docker`.
1. Set default docker image. This step sets default docker image that will be used for runner executor when no image is specified in project CI configuration.
    1. *Option A.* Set `docker image` to `docker:stable`. This way you will be able to run any docker container with this runner. Specify the image in the `.gitlab-ci.yml`:

        ```yaml
        image: venk0/android-sdk:latest
        ```

    1. *Option B*. Set `docker image` to `venk0/android-sdk:latest`. Using this option no changes in the `.gitlab-ci.yml` will be required.

#### Configure runner

Mount host directories with Gradle, AVD, system images, and SDK license caches. For emulator execution, pass `/dev/kvm` under `[runners.docker]`. Edit `/etc/gitlab-runner/config.toml`:

```toml
[[runners]]
  [runners.docker]
    devices = ["/dev/kvm"]
    volumes = [
      "/cache",
      "/srv/gitlab-runner-data/mnt/.gradle:/root/.gradle",
      "/srv/gitlab-runner-data/mnt/.android:/root/.android",
      "/srv/gitlab-runner-data/mnt/android-sdk/system-images:/opt/android/system-images",
      "/srv/gitlab-runner-data/mnt/android-sdk/licenses/:/opt/android/licenses"
    ]
```

Update `/srv/gitlab-runner-data/mnt` directory or use volume if you prefer to store the data cache mounts in another place.

#### Launch runner

Run docker container:

```shell
docker run -v /etc/gitlab-runner:/etc/gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --device /dev/kvm \
  --name gitlab-runner --restart unless-stopped -d \
  gitlab/gitlab-runner:latest
```

Or use with docker-compose:

```yaml
version: '3'
services:
  gitlab-runner:
    container_name: gitlab-runner
    image: gitlab/gitlab-runner:latest
    devices:
      - '/dev/kvm:/dev/kvm'
    volumes:
      - '/etc/gitlab-runner:/etc/gitlab-runner'
      - '/var/run/docker.sock:/var/run/docker.sock'
    restart: unless-stopped
```

## Docker image publishing workflow

This repository contains a GitHub Actions workflow that automates the publishing of a Docker image for the Android SDK on DockerHub. The workflow is triggered under specific conditions:

1. Push Event to the `dev` Branch:
   - Whenever code changes are pushed to the `dev` branch, the workflow will be triggered.
   - The Docker image will be built and published with the tag `edge`, indicating an edge version of the image.

2. Creation of a New Tag on Any Branch:
   - When a new tag is created on any branch, the workflow will be triggered.
   - The Docker image will be built and published with the following tags:
     - A tag named `latest`, indicating the latest stable version of the image.
     - A tag based on the name of the git tag that triggered the workflow.

It's important to note that the workflow excludes pull request events from triggering the build and push process, ensuring that Docker images are not published on pull requests. Additionally, the workflow is specific to the `Dockerfile`, meaning it only runs when changes are made to the Dockerfile in the repository.

### Preparing Secrets

Before using the workflow in your repository, ensure to properly configure the required secrets in the GitHub repository settings. The following secrets need to be set:

- `DOCKERHUB_USERNAME`: Your DockerHub username.
- `DOCKERHUB_TOKEN`: An access token with the necessary permissions to publish images to your DockerHub repository.

## License

The Dockerfiles and associated code and scripts are licensed under the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0.html).
