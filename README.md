# A Zero-Stats qBittorrent Container

A fork of [qbittorrent/docker-qbittorrent-nox][qbittorrent] with a custom patch of [arvidn/libtorrent][libtorrent] that
prevents sharing statistics with trackers. Supports both amd64 and arm64 architectures.

⚠️ **WARNING**: Using this client on private trackers may result in an account ban as it interferes with ratio tracking.
Use at your own risk!

## Usage

Usage is exactly the same as the original [qbittorrent/docker-qbittorrent-nox][qbittorrent]. Refer to their
documentation for configuration.

### Docker Compose (recommended)

```bash
services:
  qbittorrent:
    image: ghcr.io/arkandias/qbittorrent:latest
    container_name: qbittorrent
    environment:
      - QBT_LEGAL_NOTICE=confirm
      - QBT_WEBUI_PORT=8080
    ports:
      - "8080:8080"
      - "6881:6881"
      - "6881:6881/udp"
    volumes:
      - <path_to_config>:/config
      - <path_to_downloads>:/downloads
```

### Docker CLI

```bash
docker run \
  --name=qbittorrent \
  -e QBT_LEGAL_NOTICE=confirm \
  -e QBT_WEBUI_PORT=8080 \
  -p 8080:8080 \
  -p 6881:6881 \
  -p 6881:6881/udp \
  -v <path_to_config>:/config \
  -v <path_to_downloads>:/downloads \
  ghcr.io/arkandias/qbittorrent:latest
```

## Security Notice

While this client does not share any statistics with trackers, your IP address remains visible to peers and trackers.
For full privacy, use it with a VPN.

[qbittorrent]: https://github.com/qbittorrent/docker-qbittorrent-nox

[libtorrent]: https://github.com/arvidn/libtorrent
