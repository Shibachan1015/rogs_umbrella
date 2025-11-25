const defaultTheme = require("tailwindcss/defaultTheme");

module.exports = {
  content: [
    "./css/**/*.css",
    "./js/**/*.js",
    "../lib/rogs_comm_web.ex",
    "../lib/rogs_comm_web/**/*.{ex,exs,heex}"
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
      },
    },
  },
  plugins: [],
};

