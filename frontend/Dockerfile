# Build the static React app for the production image.
FROM oven/bun:1.4.4 AS frontend-build
WORKDIR /app
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile
COPY . .
RUN bun run build

# Serve the compiled app and forward same-origin API requests to the backend.
FROM nginx:alpine AS production
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=frontend-build /app/dist /usr/share/nginx/html
EXPOSE 80

# Keep development last so the existing Compose target remains the Vite server.
FROM oven/bun:1.4.4 AS development
WORKDIR /app
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile
COPY . .
EXPOSE 5173
CMD ["bun", "run", "dev"]
