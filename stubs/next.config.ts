import type { NextConfig } from "next";

// Накладывается поверх сгенерированного create-next-app при `make init-frontend`.
const nextConfig: NextConfig = {
  // Standalone-сборка нужна прод-образу node (docker/node/Dockerfile, стейдж production).
  output: "standalone",
};

export default nextConfig;
