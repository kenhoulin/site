// Publications filter UI — reads publications.json, drives chip filters + pub list
// Also syncs dimming state with network.js

(function () {
  let allPubs   = [];
  let activeKw  = new Set();
  let activeOut = new Set();
  let kwMode    = "and"; // "and" | "or"

  fetch("publications.json")
    .then(r => r.json())
    .then(data => {
      allPubs = data;
      buildChips();
      renderList(allPubs);
    })
    .catch(() => {
      document.getElementById("pub-list").innerHTML =
        '<p style="color:#888;font-size:0.85rem">Publication data not yet generated. Run <code>quarto render</code> after populating publications.bib.</p>';
    });

  function buildChips() {
    const kwSet  = new Set();
    const outSet = new Set();
    allPubs.forEach(p => {
      (p.keywords || []).forEach(k => kwSet.add(k));
      if (p.outlet) outSet.add(p.outlet);
    });

    renderChips("keyword-chips", [...kwSet].sort(), activeKw, kw => {
      toggle(activeKw, kw);
      applyFilters();
    });

    renderChips("outlet-chips", [...outSet].sort(), activeOut, out => {
      toggle(activeOut, out);
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
    activeOut.clear();
    buildChips();
    applyFilters();
  });

  function applyFilters() {
    // Rebuild chip states
    buildChips();

    let filtered = allPubs;

    if (activeKw.size > 0) {
      filtered = filtered.filter(p => {
        const pkw = new Set(p.keywords || []);
        return kwMode === "and"
          ? [...activeKw].every(k => pkw.has(k))
          : [...activeKw].some(k => pkw.has(k));
      });
    }

    if (activeOut.size > 0) {
      filtered = filtered.filter(p => activeOut.has(p.outlet));
    }

    renderList(filtered);
    updateNetworkDimming(new Set(filtered.map(p => p.id)));
  }

  function renderList(pubs) {
    const countEl = document.getElementById("pub-count");
    const listEl  = document.getElementById("pub-list");
    if (!listEl) return;

    if (countEl) countEl.textContent = `Showing ${pubs.length} of ${allPubs.length} publications`;

    // Group by year descending
    const byYear = {};
    pubs.forEach(p => {
      byYear[p.year] = byYear[p.year] || [];
      byYear[p.year].push(p);
    });

    const years = Object.keys(byYear).sort((a, b) => b - a);
    listEl.innerHTML = years.map(yr => `
      <div class="pub-year-group">
        <h3>${yr}</h3>
        ${byYear[yr].map(pubHtml).join("")}
      </div>
    `).join("");
  }

  function pubHtml(p) {
    const doi = p.doi ? ` <a href="https://doi.org/${p.doi}" target="_blank">[DOI]</a>` : "";
    const pdf = p.pdf ? ` <a href="${p.pdf}" target="_blank">[PDF]</a>` : "";
    return `
      <div class="pub-entry" data-id="${p.id}">
        <span class="pub-authors">${p.authors}</span> (${p.year}).
        <span class="pub-title">${p.title}</span>.
        <span class="pub-venue">${p.outlet || ""}</span>.
        ${doi}${pdf}
      </div>`;
  }

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
