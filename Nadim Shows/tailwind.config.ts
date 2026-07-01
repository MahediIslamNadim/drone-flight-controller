import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./lib/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        sand: "#F5EBDD",
        ember: "#B85C38",
        pine: "#12372A",
        ocean: "#1E4D5C",
        ink: "#18212F",
        mist: "#EEF3F2",
      },
      boxShadow: {
        glow: "0 20px 60px rgba(18, 55, 42, 0.18)",
      },
      backgroundImage: {
        halo:
          "radial-gradient(circle at top, rgba(184, 92, 56, 0.18), transparent 45%), radial-gradient(circle at bottom right, rgba(30, 77, 92, 0.18), transparent 40%)",
      },
      keyframes: {
        float: {
          "0%, 100%": { transform: "translateY(0px)" },
          "50%": { transform: "translateY(-8px)" },
        },
        rise: {
          "0%": { opacity: "0", transform: "translateY(16px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
      },
      animation: {
        float: "float 6s ease-in-out infinite",
        rise: "rise 0.6s ease-out both",
      },
    },
  },
  plugins: [],
};

export default config;

