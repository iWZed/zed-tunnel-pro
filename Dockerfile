FROM debian:bookworm-slim

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install core dependencies & utilities
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget \
    curl \
    git \
    python3 \
    neofetch \
    procps \
    psmisc \
    jq \
    ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install ttyd for web-based terminal access
RUN wget -qO /bin/ttyd https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.x86_64 && \
    chmod +x /bin/ttyd

# Pre-install Xray core to speed up container boot time
RUN bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root

# Pre-install Cloudflared binary
RUN curl -L -s https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /root/cloudflared && \
    chmod +x /root/cloudflared

# Copy setup and entrypoint scripts
COPY zed.sh /root/zed.sh
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /root/zed.sh /entrypoint.sh

# Configure neofetch and shell environment
RUN echo "neofetch" >> /root/.bashrc && \
    echo "cd /root" >> /root/.bashrc

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
