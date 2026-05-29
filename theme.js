// theme.js — light/dark toggle injected into the Quarto navbar.
// Default: follow the OS (prefers-color-scheme). A click sets an explicit
// override saved in localStorage. The no-flash init in index.qmd's <head>
// applies a stored override before first paint; CSS @media handles the
// system default when no override is set.

(function () {
  const root = document.documentElement;
  const KEY = "theme";
  const mq = window.matchMedia("(prefers-color-scheme: dark)");

  function stored() {
    try { return localStorage.getItem(KEY); } catch (e) { return null; }
  }
  function effective() {
    const s = stored();
    if (s === "dark" || s === "light") return s;
    return mq.matches ? "dark" : "light";
  }

  const btn = document.createElement("button");
  btn.type = "button";
  btn.className = "theme-toggle";

  function render() {
    const eff = effective();
    btn.textContent = eff === "dark" ? "☾" : "☀"; // ☾ moon : ☀ sun
    const target = eff === "dark" ? "light" : "dark";
    btn.setAttribute("aria-label", "Switch to " + target + " theme");
    btn.setAttribute("title", "Switch to " + target + " theme");
  }

  function apply(theme) {
    root.setAttribute("data-theme", theme);
    try { localStorage.setItem(KEY, theme); } catch (e) {}
    render();
    window.dispatchEvent(new CustomEvent("themechange", { detail: { theme: theme } }));
  }

  btn.addEventListener("click", function () {
    apply(effective() === "dark" ? "light" : "dark");
  });

  // React to OS changes only while the visitor hasn't chosen an override.
  mq.addEventListener("change", function () {
    if (!stored()) {
      render();
      window.dispatchEvent(new CustomEvent("themechange", { detail: { theme: effective() } }));
    }
  });

  function place() {
    const navbar = document.querySelector(".navbar");
    if (!navbar) return false;
    const right = navbar.querySelector(".navbar-nav.ms-auto") ||
                  navbar.querySelector(".navbar-nav");
    if (right && right.tagName === "UL") {
      const li = document.createElement("li");
      li.className = "nav-item d-flex align-items-center";
      li.appendChild(btn);
      right.appendChild(li);
    } else {
      (navbar.querySelector(".navbar-container") || navbar).appendChild(btn);
    }
    render();
    return true;
  }

  if (!place()) {
    // Navbar may not be in the DOM yet; retry once after load.
    window.addEventListener("DOMContentLoaded", place);
  }
})();
