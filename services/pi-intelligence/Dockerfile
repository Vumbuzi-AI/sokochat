FROM node:26-bookworm-slim
ENV NODE_ENV=production PI_HOST=0.0.0.0 PI_PORT=4100 PI_DATA_DIR=/var/lib/sokochat-pi
WORKDIR /app
COPY package.json package-lock.json ./
RUN apt-get update && apt-get install -y --no-install-recommends util-linux && rm -rf /var/lib/apt/lists/*
RUN npm ci --omit=dev --ignore-scripts && mkdir -p /var/lib/sokochat-pi && chown node:node /var/lib/sokochat-pi
COPY --chown=node:node src ./src
USER node
EXPOSE 4100
VOLUME /var/lib/sokochat-pi
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s CMD node -e "fetch('http://127.0.0.1:4100/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "src/server.ts"]
