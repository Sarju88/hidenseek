FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libfontconfig1 libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 libgl1 libasound2 && rm -rf /var/lib/apt/lists/*
WORKDIR /game
COPY exports/linux/HideSeek.x86_64 /game/HideSeek.x86_64
RUN chmod +x /game/HideSeek.x86_64
EXPOSE 8080
USER 65534:65534
ENTRYPOINT ["/game/HideSeek.x86_64", "--headless", "--", "--port=8080"]
