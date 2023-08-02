# Android SDK

[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.com/donate/?hosted_button_id=Q9WMN3C2JXDKS)

## Overview

Android SDK image with minimal required set of tools for CI deployment. **Does not contain emulator images** to minimize the footprint.

Preinstalled tools/components:

Tool/Component | Version
------- | -------
OpenJDK | 17
Android SDK Build-Tools | 33.0.2
Android SDK Platform | 31

## Quick start

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

Mount host directories with Gradle and SDK caches. Edit `/etc/gitlab-runner/config.toml`, set `volumes` as following:

```toml
volumes = ["/cache", "/srv/gitlab-runner-data/mnt/.gradle:/root/.gradle", "/srv/gitlab-runner-data/mnt/.android:/root/.android", "/srv/gitlab-runner-data/mnt/android-sdk/licenses/:/opt/android/licenses"]
```

Update `/srv/gitlab-runner-data/mnt` directory or use volume if you prefer to store the data cache mounts in another place.

#### Launch runner

Run docker container:

```shell
docker run -v /etc/gitlab-runner:/etc/gitlab-runner \ 
-v /var/run/docker.sock:/var/run/docker.sock \ 
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
