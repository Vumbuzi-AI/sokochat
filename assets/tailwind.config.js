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
        sans: ["Poppins", "ui-sans-serif", "system-ui", "sans-serif"],
      },
      maxWidth: { container: "1312px" },
      colors: {
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
