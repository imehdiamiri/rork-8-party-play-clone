import type { Config } from "tailwindcss";
const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        bg: "#0a0a0b",
        panel: "#111113",
        border: "#1f1f22",
        muted: "#8a8a93",
        accent: "#4f8cff",
      },
    },
  },
  plugins: [],
};
export default config;
