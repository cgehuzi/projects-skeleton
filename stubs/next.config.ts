import type { NextConfig } from "next";

// Накладывается поверх сгенерированного create-next-app при `make init-frontend`.
const nextConfig: NextConfig = {
  // Standalone-сборка нужна прод-образу node (docker/node/Dockerfile, стейдж production).
  output: "standalone",
  // Пакет @cgehuzi/core-frontend поставляется TS-исходниками — транспилируем его.
  // Безвредно, если пакет ещё не установлен (make core-install / core-link).
  transpilePackages: ["@cgehuzi/core-frontend"],
};

export default nextConfig;
