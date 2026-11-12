# gdb for reading the device's core files (aarch64) on this machine.
FROM debian:trixie
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y gdb-multiarch file && rm -rf /var/lib/apt/lists/*
