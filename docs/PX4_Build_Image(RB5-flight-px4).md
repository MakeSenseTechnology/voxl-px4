# RB5-Flight build container on MacOS

This doc describes how to build the complete RB5 flight container used to compile PX4 for Qualcomm RB5.
The container is mostly complete but is missing the Hexagon SDK as redistribution of the SDK is prohibited.

## Install Hexagon SDK 4.1.0.4 on a Ubuntu container

Target environment: Ubuntu 20.04, x86-64 (`linux/amd64`), for the VOXL-PX4 build. Explicitly select this architecture on Apple Silicon Macs.

1. **Download Qualcomm Package Manager (QPM)**

    Sign in to the [QPM3 download page](https://qpm.qualcomm.com/#/main/tools/details/QPM3) and download the Linux x86-64 `.deb` installer.

2. **Start Docker Desktop and create the container**

    Run in macOS terminal:
    ```sh
    mkdir -p "$HOME/hexagon-download"

    docker pull --platform linux/amd64 ubuntu:20.04

    docker volume create hexagon-sdk-data

    docker run -it \
      --name hexagon-qpm \
      --platform linux/amd64 \
      --mount type=volume,source=hexagon-sdk-data,target=/opt/Qualcomm \
      --mount "type=bind,source=$HOME/Downloads,target=/downloads,readonly" \
      --mount "type=bind,source=$HOME/hexagon-download,target=/export" \
      ubuntu:20.04 bash
    ```

    **Notes:**
    - The container mounts `$HOME/Downloads` as readonly for access to the QPM `.deb` file
    - The container mounts `$HOME/hexagon-download` with write access to export a `.tgz` sdk archive for the RB5-flight Docker image build.

3. **Install dependencies inside the container**

    ```sh
    apt-get update

    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      ca-certificates curl unzip zip tar file \
      python3 python-is-python3 build-essential xz-utils

    dpkg --print-architecture
    python --version
    ```
    Expected architecture: `amd64`.

    `python-is-python3` supplies the `python` command required by the installer. Without it, the installation will fail.

4. **Install QPM**

    ```sh
    apt-get install -y /downloads/qpm-linux.deb

    command -v qpm-cli
    qpm-cli --help
    ```

5. **Authenticate and activate the SDK license**

    Replace the email placeholder with the Qualcomm account that accepted the license:
    ```sh
    qpm-cli --login <YOUR_QUALCOMM_EMAIL>
    ```
    Enter the password interactively, then run:
    ```sh
    qpm-cli --license-activate hexagonsdk4.x
    ```
    Follow the installation prompts and confirm the install was successful.

7. **Inspect the installation**

    ```sh
    ls -la /opt/Qualcomm/Hexagon_SDK/4.1.0.4

    find /opt/Qualcomm/Hexagon_SDK/4.1.0.4 \
      -type f -name ''*hexagon-clang*' -print
    ```
    Confirm that installation completed successfully and the SDK/compiler files exist. File presence alone does not verify that the post-install step succeeded.

8. **Export the SDK archive to macOS**

    After successful installation:
    ```sh
    tar -czf /export/sdk.tgz \
      -C /opt/Qualcomm/Hexagon_SDK \
      4.1.0.4

    tar -tzf /export/sdk.tgz | head -20
    ```
    The archive appears on macOS at `~/hexagon-download/sdk.tgz`, with `4.1.0.4/` as its top-level directory.
    Use it as input to the ModalAI PX4 Docker build.

9. **Exit and resume later**

    Exit the container:
    ```sh
    exit
    ```
    Resume it from macOS can be achieved when needed with:
    ```sh
    docker start -ai hexagon-qpm
    ```

## Build VOXL rb5-flight-px4-build-docker container

1. Clone `https://gitlab.com/voxl-public/rb5-flight/rb5-flight-px4-build-docker.git`
2. `cd rb5-flight-px4-build-docker`
3. Copy the hexagon sdk `cp ~/hexagon-download/sdk.tgz .`
4. Run the setup `./setup.sh`
5. Run the build script `DOCKER_DEFAULT_PLATFORM=linux/amd64 ./build.sh`
6. Confirm image is installed `docker images | grep rb5-flight-px4-build-docker`

## Building Our Internal `voxl-px4` fork

1. Clone `git@github.com:MakeSenseTechnology/voxl-px4.git`
2. `cd voxl-px4`
3. Run the RB5-flight container
    ```sh
    docker run --rm -it \
      --platform linux/amd64 \
      --mount "type=bind,source=$PWD,target=/usr/local/workspace" \
      --workdir /usr/local/workspace \
      rb5-flight-px4-build-docker:latest \
      bash
    ```
4. Run the build in the container with `./build.sh`
5. Produce the deb with `./make_package.sh` in the container

**NOTEs:**
Our px4-sensor-bridge plugin requires you to run:
```sh
python3 tools/apply_px4_overlay.py /path/to/voxl-px4/px4-firmware
```
from this repository on the current `voxl-px4` clone prior to building the `voxl-px4`
project. This script injects the px4-sensor-bridge plugin into `voxl-px4`.

## Installing the `voxl-px4` fork build

1. On macOS push the `.deb` to the voxl `adb push voxl-px4_1.18.0-1.0.7_arm64.deb /home/root/`
2. Install the `.deb` by
    ```sh
    adb shell
    # Back up existing PX4 parameters and configuration (Optionial)
    tar -czf /home/root/px4-config-before-upgrade.tgz \
      /data/px4/param /etc/modalai/voxl-px4.conf

    # Install voxl-px4 fork package
    cd /home/root
    dpkg -i voxl-px4_1.18.0-1.0.7_arm64.deb
    sync
    reboot
    ```

    **NOTEs:** 
    - You don't need to backup PX4 parameters and configuration for each install. It's optional.
    - development purposes can avoid this cumbersome install process using the supplied `install-voxl.sh` when editing `voxl-px4`.

3. Inspect installed package on VOXL:
    ```sh
    adb shell
    dpkg-query -W voxl-px4
    systemctl status voxl-px4 --no-pager
    px4-ver all
    px4-qshell gps status
    px4-listener sensor_gps -n 5
    ```

    The package version should be `1.18.0-1.0.7`. If PX4 fails to start, inspect:
    ```sh
    journalctl -u voxl-px4 -b -n 100 --no-pager
    ```