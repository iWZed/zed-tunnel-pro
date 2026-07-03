FROM alpine:latest

# Install dependencies (including ttyd via community repository)
RUN apk add --no-cache \
    curl \
    bash \
    jq \
    procps \
    psmisc \
    ca-certificates \
    unzip \
    wget \
    ttyd


# Download and install Xray core
RUN wget -qO /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip && \
    unzip -q /tmp/xray.zip -d /usr/local/bin/ && \
    chmod +x /usr/local/bin/xray && \
    rm -rf /tmp/xray.zip

# Download and install Cloudflared
RUN curl -L -s https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared

# Download and install neofetch bash script
RUN curl -fsSL https://raw.githubusercontent.com/dylanaraps/neofetch/master/neofetch -o /usr/local/bin/neofetch && \
    chmod +x /usr/local/bin/neofetch

WORKDIR /root

# Copy setup, welcome, and entrypoint scripts
COPY zed.sh welcome.sh ./
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x zed.sh welcome.sh /entrypoint.sh

# Configure neofetch and shell environment
RUN echo "neofetch" >> /root/.bashrc && \
    echo "cd /root" >> /root/.bashrc

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
