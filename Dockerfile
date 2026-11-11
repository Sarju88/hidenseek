FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libfontconfig1 libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 libgl1 libasound2 && rm -rf /var/lib/apt/lists/*
WORKDIR /game
COPY exports/linux/Foundry.x86_64 /game/Foundry.x86_64
RUN chmod +x /game/Foundry.x86_64
EXPOSE 8081
USER 65534:65534
ENTRYPOINT ["/game/Foundry.x86_64", "--headless", "--", "--websocket"]
