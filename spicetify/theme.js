/* Stillwater Spicetify adapter. Loads Dribbblish:
 * https://github.com/spicetify/spicetify-themes (MIT)
 */
(() => {
  const script = document.createElement("SCRIPT");
  script.setAttribute("type", "text/javascript");
  script.setAttribute(
    "src",
    "https://cdn.jsdelivr.net/gh/spicetify/spicetify-themes@master/Dribbblish/theme.js"
  );
  document.head.appendChild(script);
})();
