import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tsconfigPaths from "vite-tsconfig-paths";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  base: "/Fluxo-caixa/",
  plugins: [react(), tailwindcss(), tsconfigPaths()],
  build: {
    outDir: ".output/static",
    emptyOutDir: true,
  },
});
