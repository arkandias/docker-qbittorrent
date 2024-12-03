# A Zero-Stats qBittorrent Container

A fork of [qbittorrent/docker-qbittorrent-nox][qbittorrent] that prevents sharing statistics with trackers through a
custom libtorrent patch. Supports both amd64 and arm64 architectures.

⚠️ **WARNING**: Using this client on private trackers may result in account bans as it interferes with ratio tracking.
Use at your own risk!

## Usage

Usage is exactly the same as the original [qbittorrent/docker-qbittorrent-nox][qbittorrent]. Refer to their
documentation for configuration.

## Security Notice

While this container prevents sharing statistics with trackers, your IP address remains visible to peers and trackers.
For full privacy, use with a VPN.

[qbittorrent]: https://github.com/qbittorrent/docker-qbittorrent-nox
