import daisyui from "daisyui";

module.exports = {
  content: [
    "./app/views/**/*.html.{html,erb,haml,slim}",
    "./app/helpers/**/*.rb",
    "./app/assets/stylesheets/**/*.css",
    "./app/javascript/**/*.{js,jsx,ts,tsx,vue}",
  ],
  plugins: [daisyui],
};
