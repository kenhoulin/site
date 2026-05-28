// Publications filter UI — reads publications.json, drives chip filters + pub list
// Also syncs dimming state with network.js

(function () {
  let allPubs   = [];
  let activeKw  = new Set();
  let activeOut = new Set();
  let kwMode    = "and"; // "and" | "or"

  fetch("publications/publications.json")
    .then(r => r.json())
    .then(data => {
      allPubs = data;
      buildChips();
      renderList([]); // start empty — only show pubs once a chip is selected
    })
    .catch(() => {
      document.getElementById("pub-list").innerHTML =
        '<p style="color:#888;font-size:0.85rem">Publication data not yet generated. Run <code>quarto render</code> after populating publications.bib.</p>';
    });

  function buildChips() {
    // Count keyword frequencies across all publications
    const kwCount = new Map();
    allPubs.forEach(p => (p.keywords || []).forEach(k => {
      kwCount.set(k, (kwCount.get(k) || 0) + 1);
    }));

    // Sort by frequency desc, then alphabetically as tiebreaker
    const ordered = [...kwCount.entries()]
      .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
      .map(([k]) => k);

    renderChips("keyword-chips", ordered, activeKw, kw => {
      toggle(activeKw, kw);
      applyFilters();
    });
  }

  function renderChips(containerId, items, activeSet, onClick) {
    const el = document.getElementById(containerId);
    if (!el) return;
    el.innerHTML = "";
    items.forEach(item => {
      const chip = document.createElement("span");
      chip.className = "chip" + (activeSet.has(item) ? " active" : "");
      chip.textContent = item;
      chip.addEventListener("click", () => onClick(item));
      el.appendChild(chip);
    });
  }

  function toggle(set, value) {
    set.has(value) ? set.delete(value) : set.add(value);
  }

  document.querySelectorAll('input[name="kwmode"]').forEach(radio => {
    radio.addEventListener("change", e => { kwMode = e.target.value; applyFilters(); });
  });

  document.getElementById("clear-filters")?.addEventListener("click", () => {
    activeKw.clear();
    buildChips();
    applyFilters();
  });

  function applyFilters() {
    buildChips();

    const hasFilter = activeKw.size > 0;

    // Only build a publication list when at least one keyword is selected.
    let filtered = [];
    if (hasFilter) {
      filtered = allPubs.filter(p => {
        const pkw = new Set(p.keywords || []);
        return kwMode === "and"
          ? [...activeKw].every(k => pkw.has(k))
          : [...activeKw].some(k => pkw.has(k));
      });
    }

    renderList(filtered);
    updateNetworkDimming(new Set(filtered.map(p => p.id)));
  }

  function renderList(pubs) {
    const countEl = document.getElementById("pub-count");
    const listEl  = document.getElementById("pub-list");
    if (!listEl) return;

    // No filter selected → empty list with a prompt, no count
    if (activeKw.size === 0) {
      if (countEl) countEl.textContent = "";
      listEl.innerHTML = '<p class="pub-empty">Select one or more topics to see related publications.</p>';
      return;
    }

    if (countEl) countEl.textContent = `Showing ${pubs.length} of ${allPubs.length} publications`;

    // Sort by citation count desc (most-cited first); fall back to year desc for ties
    const sorted = pubs.slice().sort((a, b) =>
      (b.citations || 0) - (a.citations || 0) || (b.year - a.year)
    );

    listEl.innerHTML = sorted.map(pubHtml).join("");
  }

  // ASA-style author list: first author "Last, First"; subsequent "First Last".
  // 2 authors → "A and B"; 3+ → "A, B, and C" (Oxford comma).
  function formatAuthorsASA(raw) {
    if (!raw) return "";
    const parts = raw.split(";").map(s => s.trim()).filter(Boolean);
    const formatted = parts.map((name, i) => {
      const comma = name.indexOf(",");
      if (comma === -1) return name; // already "First Last" or single token
      const last  = name.slice(0, comma).trim();
      const first = name.slice(comma + 1).trim();
      return i === 0 ? `${last}, ${first}` : `${first} ${last}`;
    });
    if (formatted.length <= 1) return formatted.join("");
    if (formatted.length === 2) return `${formatted[0]} and ${formatted[1]}`;
    return formatted.slice(0, -1).join(", ") + ", and " + formatted.at(-1);
  }

  function pubHtml(p, opts = {}) {
    const doi = p.doi ? ` <a href="https://doi.org/${p.doi}" target="_blank" class="pub-link">[DOI]</a>` : "";
    const pdf = p.pdf ? ` <a href="${p.pdf}" target="_blank" class="pub-link">[PDF]</a>` : "";
    const openAttr = opts.openAbstract ? " open" : "";
    const abs = p.abstract
      ? `<details class="pub-abstract"${openAttr}><summary>Abstract</summary><p>${p.abstract.replace(/\n\n+/g, "</p><p>")}</p></details>`
      : "";
    return `
      <div class="pub-entry" data-id="${p.id}">
        <span class="pub-authors">${formatAuthorsASA(p.authors)}</span>. ${p.year}.
        <span class="pub-title">${p.title}</span>
        <span class="pub-venue"><em>${p.outlet || ""}</em></span>.
        ${doi}${pdf}
        ${abs}
      </div>`;
  }

  // Expose: render a single publication (by id) with its abstract expanded.
  // Called from network.js when a node is clicked.
  window.showPubById = function (id) {
    const p = allPubs.find(x => x.id === id);
    if (!p) return;
    const countEl = document.getElementById("pub-count");
    const listEl  = document.getElementById("pub-list");
    if (countEl) countEl.textContent = "Selected publication";
    if (listEl)  listEl.innerHTML = pubHtml(p, { openAbstract: true });
  };

  function updateNetworkDimming(matchIds) {
    if (!window._networkSvgNodes) return;
    const hasFilter = activeKw.size > 0 || activeOut.size > 0;

    window._networkSvgNodes
      .attr("opacity", d => (!hasFilter || matchIds.has(d.id)) ? 1 : 0.15);

    window._networkSvgLinks
      .attr("opacity", d => {
        if (!hasFilter) return 1;
        const sId = typeof d.source === "object" ? d.source.id : d.source;
        const tId = typeof d.target === "object" ? d.target.id : d.target;
        return (matchIds.has(sId) && matchIds.has(tId)) ? 1 : 0.1;
      });
  }
})();
