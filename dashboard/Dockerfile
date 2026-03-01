# dashboard/Dockerfile
FROM node:20-alpine
WORKDIR /app

# Install dependencies first (better layer caching)
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Copy application source
COPY server.js ./
COPY public ./public

EXPOSE 3000
USER node
CMD ["node", "server.js"]
