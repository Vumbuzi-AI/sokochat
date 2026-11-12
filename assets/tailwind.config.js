// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin");

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/sokochat_web.ex",
    "../lib/sokochat_web/**/*.*ex",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ["var(--font-sans)"],
        display: ["var(--font-display)"],
        mono: ["var(--font-mono)"],
      },
      maxWidth: { container: "1312px" },
      borderRadius: {
        "soko-6": "var(--radius-soko-6)",
        "soko-10": "var(--radius-soko-10)",
        "soko-14": "var(--radius-soko-14)",
        "soko-20": "var(--radius-soko-20)",
        "soko-28": "var(--radius-soko-28)",
      },
      letterSpacing: {
        "soko-display": "var(--tracking-soko-display)",
        "soko-heading": "var(--tracking-soko-heading)",
        "soko-ui": "var(--tracking-soko-ui)",
      },
      colors: {
        soko: {
          ink: "var(--color-soko-ink)",
          "ink-2": "var(--color-soko-ink-2)",
          "ink-3": "var(--color-soko-ink-3)",
          line: "var(--color-soko-line)",
          "line-2": "var(--color-soko-line-2)",
          white: "var(--color-soko-white)",
          base: "var(--color-soko-base)",
          stage: "var(--color-soko-stage)",
          forest: "var(--color-soko-forest)",
          "forest-hover": "var(--color-soko-forest-hover)",
          mint: "var(--color-soko-mint)",
          "mint-wash": "var(--color-soko-mint-wash)",
          danger: "var(--color-soko-danger)",
          "danger-hover": "var(--color-soko-danger-hover)",
          "danger-wash": "var(--color-soko-danger-wash)",
          amber: "var(--color-soko-amber)",
          "amber-wash": "var(--color-soko-amber-wash)",
          field: "var(--color-soko-field)",
          hover: "var(--color-soko-hover)",
          divider: "var(--color-soko-divider)",
        },
        primary: "#0f9c5c",
        "primary-light": "#ecfcf2",
        n50: "#fefefd",
        n100: "#fbfbfb",
        n200: "#f7f9fa",
        n300: "#e3e8ee",
        n400: "#9ea7b4",
        n500: "#707b8a",
        n600: "#535d6b",
        n700: "#3f4a59",
        n800: "#2a3341",
        n900: "#1d242f",
      },
    },
  },

  plugins: [
    require("@tailwindcss/forms"),
    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    //     <div class="phx-click-loading:animate-ping">
    //
    plugin(({ addVariant }) =>
      addVariant("phx-click-loading", [
        ".phx-click-loading&",
        ".phx-click-loading &",
      ]),
    ),
    plugin(({ addVariant }) =>
      addVariant("phx-submit-loading", [
        ".phx-submit-loading&",
        ".phx-submit-loading &",
      ]),
    ),
    plugin(({ addVariant }) =>
      addVariant("phx-change-loading", [
        ".phx-change-loading&",
        ".phx-change-loading &",
      ]),
    ),

  ],
};
