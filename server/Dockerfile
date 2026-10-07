# Dedicated server image. Build the server binary first (tools/export.sh, or download it from a
# GitHub release into build/server/), then from the repo root:
#   docker build -f server/Dockerfile -t pirate-game-server .
#   docker run -d --restart unless-stopped -p 24565:24565/udp --name pirate pirate-game-server
FROM debian:bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates libfontconfig1 \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --create-home --shell /usr/sbin/nologin pirate

COPY build/server/pirate-game-server.x86_64 /opt/pirate/pirate-game-server
RUN chmod +x /opt/pirate/pirate-game-server

USER pirate
EXPOSE 24565/udp
ENTRYPOINT ["/opt/pirate/pirate-game-server", "--headless", "--", "--server"]
CMD ["--port", "24565"]
