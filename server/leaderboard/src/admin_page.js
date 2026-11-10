// The admin page, served at /admin. Everything it does goes through /v1/admin/*, which checks the
// admin key on every request; the page itself holds no secret. The key is kept in this browser
// tab only (sessionStorage), and forgotten when the tab closes.

export const ADMIN_PAGE = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>Leaderboard admin</title>
<style>
  :root { --bg: #17130f; --panel: #221c16; --line: #3a3026; --text: #efe4d2; --soft: #b3a48c; --ember: #e0913a; --bad: #e0614a; --ok: #8fbf6a; }
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--bg); color: var(--text); font: 15px/1.45 system-ui, -apple-system, "Segoe UI", sans-serif; }
  main { max-width: 1100px; margin: 0 auto; padding: 20px 16px 60px; }
  h1 { font-size: 22px; margin: 0 0 4px; }
  h2 { font-size: 17px; margin: 28px 0 8px; }
  p.soft, .soft { color: var(--soft); }
  .row { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; margin: 12px 0; }
  input { background: var(--panel); color: var(--text); border: 1px solid var(--line); border-radius: 6px; padding: 8px 10px; font: inherit; min-width: 0; }
  input:focus-visible, button:focus-visible { outline: 2px solid var(--ember); outline-offset: 2px; }
  button { background: var(--panel); color: var(--text); border: 1px solid var(--line); border-radius: 6px; padding: 6px 10px; font: inherit; cursor: pointer; }
  button:hover { border-color: var(--ember); }
  button.primary { background: var(--ember); color: #1a120a; border-color: var(--ember); font-weight: 600; }
  button.danger { color: var(--bad); }
  table { width: 100%; border-collapse: collapse; }
  th, td { text-align: left; padding: 7px 8px; border-bottom: 1px solid var(--line); vertical-align: middle; }
  th { color: var(--soft); font-weight: 500; font-size: 13px; }
  td.num, th.num { text-align: right; font-variant-numeric: tabular-nums; }
  tr.hidden td { opacity: 0.55; }
  .tag { font-size: 12px; color: var(--bad); border: 1px solid var(--bad); border-radius: 4px; padding: 0 5px; margin-left: 6px; }
  .actions { display: flex; gap: 4px; flex-wrap: wrap; }
  #status { min-height: 1.4em; }
  #status.err { color: var(--bad); }
  #status.ok { color: var(--ok); }
  .scroll { overflow-x: auto; }
</style>
</head>
<body>
<main>
  <h1>Leaderboard admin</h1>
  <p class="soft" id="where"></p>
  <div class="row" id="login">
    <label for="key">Admin key</label>
    <input id="key" type="password" autocomplete="off" size="40">
    <button class="primary" id="enter">Open</button>
  </div>
  <p id="status" role="status"></p>
  <section id="tools" hidden>
    <div class="row">
      <input id="q" placeholder="Find a player by name" size="30">
      <button id="search">Search</button>
      <button id="forget">Forget key</button>
    </div>
    <div class="scroll"><table>
      <thead><tr><th>Player</th><th class="num">All time</th><th class="num">Matches</th><th class="num">This week</th><th>Joined</th><th>Actions</th></tr></thead>
      <tbody id="players"></tbody>
    </table></div>
    <section id="matches-box" hidden>
      <h2 id="matches-title"></h2>
      <div class="scroll"><table>
        <thead><tr><th>When</th><th class="num">Points</th><th>Mode</th><th>Class</th><th class="num">Time</th><th class="num">Kills</th><th>Result</th><th></th></tr></thead>
        <tbody id="matches"></tbody>
      </table></div>
    </section>
    <h2>What was done</h2>
    <div class="scroll"><table>
      <thead><tr><th>When</th><th>Action</th><th>Details</th></tr></thead>
      <tbody id="log"></tbody>
    </table></div>
  </section>
</main>
<script>
(() => {
  const $ = (id) => document.getElementById(id);
  let key = "";
  try { key = sessionStorage.getItem("botti-admin") || ""; } catch (e) {}
  $("where").textContent = location.host;

  function say(text, kind) { const s = $("status"); s.textContent = text; s.className = kind || ""; }
  function when(ms) { return new Date(ms).toLocaleString(); }
  function cell(row, text, cls) { const td = document.createElement("td"); td.textContent = text; if (cls) td.className = cls; row.appendChild(td); return td; }
  function button(label, onClick, cls) { const b = document.createElement("button"); b.textContent = label; b.onclick = onClick; if (cls) b.className = cls; return b; }

  async function call(method, path, body) {
    const res = await fetch(path, { method, headers: { "authorization": "Admin " + key, "content-type": "application/json" }, body: body ? JSON.stringify(body) : undefined });
    let data = {};
    try { data = await res.json(); } catch (e) {}
    if (!res.ok) throw new Error(data.error === "not_admin" ? "That key is not right." : data.error === "slow_down" ? "Too many wrong keys from here. Wait an hour." : "The board said: " + (data.error || res.status));
    return data;
  }

  async function act(id, body, done) {
    try { await call("POST", "/v1/admin/players/" + id, body); say(done, "ok"); await refresh(); } catch (e) { say(e.message, "err"); }
  }

  async function showMatches(p) {
    try {
      const data = await call("GET", "/v1/admin/players/" + p.id + "/matches");
      $("matches-title").textContent = "Matches of " + p.name + " (newest first, up to 200)";
      const body = $("matches"); body.textContent = "";
      for (const m of data.matches) {
        const tr = document.createElement("tr");
        cell(tr, when(m.created_at)); cell(tr, m.points, "num"); cell(tr, m.mode + " · " + m.map);
        cell(tr, m.class + (m.spec ? " · " + m.spec : "")); cell(tr, Math.round(m.seconds / 60) + " min", "num");
        cell(tr, m.kills, "num"); cell(tr, m.outcome);
        const td = cell(tr, "");
        td.appendChild(button("Take back", () => { if (confirm("Take back this match of " + p.name + " (" + m.points + " points)?")) act(p.id, { action: "take_back", match_id: m.match_id }, "Match taken back."); }, "danger"));
        body.appendChild(tr);
      }
      if (!data.matches.length) { const tr = document.createElement("tr"); cell(tr, "No matches."); body.appendChild(tr); }
      $("matches-box").hidden = false;
      $("matches-box").scrollIntoView({ behavior: "smooth" });
    } catch (e) { say(e.message, "err"); }
  }

  async function refresh() {
    const data = await call("GET", "/v1/admin/players?q=" + encodeURIComponent($("q").value.trim()));
    const body = $("players"); body.textContent = "";
    for (const p of data.players) {
      const tr = document.createElement("tr");
      if (p.hidden) tr.className = "hidden";
      const name = cell(tr, p.name);
      if (p.hidden) { const t = document.createElement("span"); t.className = "tag"; t.textContent = "hidden"; name.appendChild(t); }
      cell(tr, p.all_points, "num"); cell(tr, p.all_matches, "num"); cell(tr, p.week_points, "num"); cell(tr, when(p.created_at));
      const box = document.createElement("div"); box.className = "actions";
      box.appendChild(button("Matches", () => showMatches(p)));
      box.appendChild(button("Rename", () => { const n = prompt("New name for " + p.name, p.name); if (n) act(p.id, { action: "rename", name: n }, "Renamed."); }));
      box.appendChild(button(p.hidden ? "Show" : "Hide", () => act(p.id, { action: p.hidden ? "unhide" : "hide" }, p.hidden ? "Shown on the boards again." : "Hidden from the boards and prizes.")));
      box.appendChild(button("Reset scores", () => { if (confirm("Delete every match of " + p.name + "? Their points start again from nothing.")) act(p.id, { action: "reset" }, "Scores reset."); }, "danger"));
      box.appendChild(button("Remove", () => { if (confirm("Remove " + p.name + " completely? Their phone will join again as a new player.")) act(p.id, { action: "remove" }, "Removed."); }, "danger"));
      const td = document.createElement("td"); td.appendChild(box); tr.appendChild(td);
      body.appendChild(tr);
    }
    if (!data.players.length) { const tr = document.createElement("tr"); cell(tr, "No players found."); body.appendChild(tr); }
    const log = await call("GET", "/v1/admin/log");
    const lb = $("log"); lb.textContent = "";
    for (const l of log.log) { const tr = document.createElement("tr"); cell(tr, when(l.at)); cell(tr, l.action); cell(tr, l.detail); lb.appendChild(tr); }
    if (!log.log.length) { const tr = document.createElement("tr"); cell(tr, "Nothing yet."); lb.appendChild(tr); }
  }

  async function open() {
    try {
      await refresh();
      try { sessionStorage.setItem("botti-admin", key); } catch (e) {}
      $("login").hidden = true; $("tools").hidden = false; say("");
    } catch (e) { say(e.message, "err"); }
  }

  $("enter").onclick = () => { key = $("key").value.trim(); open(); };
  $("key").onkeydown = (e) => { if (e.key === "Enter") $("enter").click(); };
  $("search").onclick = () => refresh().catch((e) => say(e.message, "err"));
  $("q").onkeydown = (e) => { if (e.key === "Enter") $("search").click(); };
  $("forget").onclick = () => { try { sessionStorage.removeItem("botti-admin"); } catch (e) {} key = ""; $("tools").hidden = true; $("login").hidden = false; $("key").value = ""; };
  if (key) open();
})();
</script>
</body>
</html>`;
