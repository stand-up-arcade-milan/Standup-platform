# Use the official Bun image for package installation and the Vite dev server.
FROM oven/bun:1.4.4
WORKDIR /app

# Copy the lock first so Docker can reuse the dependency layer between builds.
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

COPY . .
EXPOSE 5173
CMD ["bun", "run", "dev"]
