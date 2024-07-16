# Introduction

`selfinst` is a collection of scripts to build unattended ISO images, allowing for automated os installations. By using a unified set of parameters, you can quickly create an unattended installation ISO.

# Quickstart

```shell
# Basic usage
selfinst-debian.sh

# Or specify the source ISO, preseed configuration, and destination ISO
selfinst-debian.sh [src.iso] [preseed.cfg] [dst.iso]
```

To create an unattended installation Debian ISO, you can either run selfinst-debian.sh without parameters to download the latest ISO and use an internal preseed file, or provide a source ISO, preseed configuration file, and destination ISO file for customization.
