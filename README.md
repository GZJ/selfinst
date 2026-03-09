# Introduction

`selfinst` is a collection of scripts to build unattended ISO images, allowing for automated os installations. By using a unified set of parameters, you can quickly create an unattended installation ISO.

# Install

## Prerequisites

Before using selfinst, ensure you have the following dependencies installed:

```shell
# For Debian/Ubuntu systems
sudo apt update
sudo apt install -y genisoimage squashfs-tools xorriso wget curl

# For RHEL/CentOS/Fedora systems  
sudo yum install -y genisoimage squashfs-tools xorriso wget curl
# or for newer versions
sudo dnf install -y genisoimage squashfs-tools xorriso wget curl
```

## Installation

```shell
wget -q https://raw.githubusercontent.com/GZJ/selfinst/master/selfinst-debian.sh -O /tmp/selfinst-debian.sh && \
chmod +x /tmp/selfinst-debian.sh && \
sudo mv /tmp/selfinst-debian.sh /usr/local/bin/selfinst-debian.sh
```

# Quickstart

```shell
# Basic usage
selfinst-debian.sh

# Or specify the source ISO, preseed configuration, destination ISO, and additional data
selfinst-debian.sh \
    -s /path/to/debian.iso \
    -p /path/to/preseed.cfg \
    -d /path/to/custom-debian.iso \
    --data /path/to/extra/files
```

To create an unattended installation Debian ISO, you can either run selfinst-debian.sh without parameters to download the latest ISO and use an internal preseed file, or provide a source ISO, preseed configuration file, and destination ISO file for customization.


# Test

```shell
selfinst-debian-test.ps1
selfinst-debian-test.sh

#specify the ISO
selfinst-debian-test.ps1 -isoPath "path/to/your/custom-iso.iso"
selfinst-debian-test.sh "path/to/your/custom-iso.iso"
```

selfinst-debian-test uses QEMU to build a virtual machine for testing the unattended installation of an ISO that has been configured with a preseed.cfg file.
