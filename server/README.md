# Running a dedicated server

The server is the same game with no graphics. It holds the ship and the crew list, and
players connect to it over UDP port 24565.

## On a small cloud machine

Any small Linux VPS works; the game uses very little CPU and about 20 KB/s per player.
For example a Hetzner CX22 (2 vCPU, 4 GB, a few euros a month) with Ubuntu 24.04.

1. Install Docker: `curl -fsSL https://get.docker.com | sh`
2. Get the server binary: download `sea-of-slop-server-linux-*.zip` from the GitHub release and
   unzip it into `build/server/` in a checkout of this repo (or run `tools/export.sh`).
3. Build and start it:

   ```
   docker build -f server/Dockerfile -t sea-of-slop-server .
   docker run -d --restart unless-stopped -p 24565:24565/udp --name pirate sea-of-slop-server
   ```

4. Open UDP 24565 in the provider's firewall.
5. Friends pick **Join** on the title screen and enter the machine's IP address.

`docker logs -f pirate` shows who joins and where the ship is every few seconds.

## Without Docker

```
./sea-of-slop-server.x86_64 --headless -- --server --port 24565
```

## Updating

Clients and server must run the same version (the server turns away anyone else). After a
new release, rebuild the image with the new binary and restart the container.
