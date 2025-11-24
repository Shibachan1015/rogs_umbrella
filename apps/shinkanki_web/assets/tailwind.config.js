const defaultTheme = require("tailwindcss/defaultTheme");

module.exports = {
  content: [
    "./css/**/*.css",
    "./js/**/*.js",
    "../lib/shinkanki_web_web.ex",
    "../lib/shinkanki_web_web/**/*.{ex,exs,heex}"
  ],
  theme: {
    extend: {
      colors: {
        washi: "#fcfaf2",
        "washi-dark": "#efece4",
        sumi: "#1c1c1c",
        "sumi-light": "#444444",
        shu: "#d3381c",
        matsu: "#4a593d",
        kin: "#c7b370",
        sakura: "#eec4ce",
        kohaku: "#bf783a",
        "trds-primary": "var(--color-primary)",
        "trds-secondary": "var(--color-secondary)",
        "trds-tertiary": "var(--color-tertiary)",
        "trds-surface": "var(--trds-surface-dark)",
        "trds-surface-glass": "var(--trds-surface-glass)",
        "trds-outline-strong": "var(--trds-outline-strong)",
        "trds-outline-soft": "var(--trds-outline-soft)",
        "trds-text-primary": "var(--color-landing-text-primary)",
        "trds-text-secondary": "var(--color-landing-text-secondary)",
      },
      fontFamily: {
        sans: ["var(--trds-font-sans)", ...defaultTheme.fontFamily.sans],
        serif: ["var(--trds-font-serif)", ...defaultTheme.fontFamily.serif],
        mono: ["var(--trds-font-mono)", ...defaultTheme.fontFamily.mono],
      },
      boxShadow: {
        "trds-1": "var(--elevation-1)",
        "trds-2": "var(--elevation-2)",
        "trds-3": "var(--elevation-3)",
        "trds-4": "var(--elevation-4)",
        "trds-8": "var(--elevation-8)",
        "trds-ink": "var(--trds-glow-ink)",
        "trds-gold": "var(--trds-glow-gold)",
      },
      borderRadius: {
        "trds-xs": "var(--shape-corner-extra-small)",
        "trds-sm": "var(--shape-corner-small)",
        "trds-md": "var(--shape-corner-medium)",
        "trds-lg": "var(--shape-corner-large)",
        "trds-xl": "var(--shape-corner-extra-large)",
      },
      backdropBlur: {
        trds: "18px",
      },
      dropShadow: {
        "trds-gold": "0 0 25px rgba(212, 175, 55, 0.4)",
        "trds-ink": "0 0 20px rgba(0, 0, 0, 0.5)",
      },
      transitionDuration: {
        trds: "var(--motion-duration-short4)",
      },
      transitionTimingFunction: {
        trds: "var(--motion-easing-standard)",
      },
      keyframes: {
        "trds-fade-up": {
          "0%": { opacity: "0", transform: "translateY(20px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
        "trds-glow-pulse": {
          "0%, 100%": { opacity: "0.25" },
          "50%": { opacity: "0.9" },
        },
      },
      animation: {
        "trds-fade-up": "trds-fade-up 0.6s var(--motion-easing-standard) both",
        "trds-glow": "trds-glow-pulse 2.4s ease-in-out infinite",
      },
    },
  },
  plugins: [],
};

