import { invoke } from "@tauri-apps/api/core";

const app = document.querySelector("#app");
const nav = document.querySelector("#bottom-nav");
const modalRoot = document.querySelector("#modal-root");
const toastElement = document.querySelector("#toast");
const isTauri = Boolean(window.__TAURI_INTERNALS__);

const state = {
  screen: "home",
  reportType: null,
  currentReport: null,
  currentMatch: null,
  lastCreated: null,
  records: [],
  matches: [],
  statistics: { lost: 0, found: 0, returned: 0, total: 0 },
  search: "",
  filter: "all",
  isDevelopment: false,
  connectionError: false,
  backTarget: "home",
};

const categories = [
  "Electronics", "Wallet", "Bag", "Clothing", "School Supplies", "Keys",
  "Accessories", "Documents", "Others",
];

const icon = (name) => `<svg aria-hidden="true"><use href="#icon-${name}"></use></svg>`;
const escapeHtml = (value = "") => String(value)
  .replaceAll("&", "&amp;")
  .replaceAll("<", "&lt;")
  .replaceAll(">", "&gt;")
  .replaceAll('"', "&quot;")
  .replaceAll("'", "&#039;");

function formatDate(value, long = false) {
  if (!value) return "—";
  const date = new Date(`${value}T00:00:00`);
  if (Number.isNaN(date.getTime())) return escapeHtml(value);
  return new Intl.DateTimeFormat("en-US", {
    month: long ? "long" : "short",
    day: "numeric",
    year: "numeric",
  }).format(date);
}

function today() {
  const now = new Date();
  const local = new Date(now.getTime() - now.getTimezoneOffset() * 60_000);
  return local.toISOString().slice(0, 10);
}

function showToast(message, error = false) {
  toastElement.textContent = message;
  toastElement.className = `toast show${error ? " error" : ""}`;
  clearTimeout(showToast.timer);
  showToast.timer = setTimeout(() => { toastElement.className = "toast"; }, 2800);
}

function friendlyError(error) {
  if (typeof error === "string") return error;
  return error?.message || "Something went wrong. Please try again.";
}

async function backend(command, args = {}) {
  if (!isTauri) {
    throw new Error("The Rust backend is available when FindIt runs through Tauri.");
  }
  return invoke(command, args);
}

function statusBadge(status) {
  return `<span class="badge ${status}">${escapeHtml(status.toUpperCase())}</span>`;
}

function reportCard(report) {
  return `
    <button type="button" class="report-card" data-action="view-report" data-id="${escapeHtml(report.id)}">
      <span class="report-card-head">
        <span><h3>${escapeHtml(report.itemName)}</h3><span class="report-id">${escapeHtml(report.id)}</span></span>
        ${statusBadge(report.status)}
      </span>
      <span class="report-meta">
        <span class="meta-item location">${icon("location")}<span>${escapeHtml(report.location)}</span></span>
        <span class="meta-item">${icon("calendar")} ${formatDate(report.date)}</span>
        <span class="report-color"><span class="color-dot"></span>${escapeHtml(report.color)}</span>
      </span>
    </button>`;
}

function header(title, subtitle = "", back = false) {
  if (!back) {
    return `<header class="page-header no-back"><div class="header-copy"><h1>${title}</h1>${subtitle ? `<p>${subtitle}</p>` : ""}</div></header>`;
  }
  return `<header class="page-header"><button type="button" class="icon-button" data-action="back" aria-label="Go back">${icon("back")}</button><h1>${title}</h1><span></span></header>`;
}

function emptyState(kind) {
  if (kind === "matches") {
    return `<section class="empty-state"><div class="empty-illustration">${icon("matches")}</div><h2>No Matches Yet</h2><p>We’ll show possible matches here when similar Lost and Found items are reported.</p><button type="button" class="primary-button" data-nav="report">Report an Item</button></section>`;
  }
  if (kind === "search") {
    return `<section class="empty-state"><div class="empty-illustration">${icon("search")}</div><h2>No Results Found</h2><p>Try a different item name, location, color, category, or filter.</p></section>`;
  }
  return `<section class="empty-state"><div class="empty-illustration">${icon("inbox")}</div><h2>No Reports Yet</h2><p>Lost or found something? Create your first report.</p><button type="button" class="primary-button" data-nav="report">Report an Item</button></section>`;
}

function setScreen(html, activeNav) {
  app.classList.remove("page-enter");
  void app.offsetWidth;
  app.innerHTML = html;
  app.classList.add("page-enter");
  nav.querySelectorAll("button").forEach((button) => {
    button.classList.toggle("active", button.dataset.nav === activeNav);
  });
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function renderHome() {
  const recent = state.records.slice(0, 4);
  const stat = state.statistics;
  setScreen(`
    <section class="home-hero">
      <div class="brand-row"><div class="mini-brand"><span>${icon("logo")}</span>FindIt</div><div class="local-pill">Offline ready</div></div>
      <h1><span>Hello!</span>Find something you’ve lost.</h1>
    </section>
    <section class="stats-grid" aria-label="Report statistics">
      <article class="stat-card"><span class="stat-top"><i class="stat-dot lost"></i>Lost</span><strong>${String(stat.lost).padStart(2, "0")}</strong></article>
      <article class="stat-card"><span class="stat-top"><i class="stat-dot found"></i>Found</span><strong>${String(stat.found).padStart(2, "0")}</strong></article>
      <article class="stat-card"><span class="stat-top"><i class="stat-dot returned"></i>Returned</span><strong>${String(stat.returned).padStart(2, "0")}</strong></article>
    </section>
    ${state.connectionError ? `<div class="offline-notice"><strong>Browser preview:</strong> the interface is ready. Run <code>npm run tauri dev</code> to connect it to the Rust backend.</div>` : ""}
    <section class="section">
      <div class="section-heading"><h2>Quick report</h2></div>
      <div class="quick-actions">
        <button type="button" class="quick-card lost" data-action="choose-type" data-type="lost"><span class="quick-icon">${icon("lost")}</span><strong>REPORT LOST ITEM</strong>${icon("lost")}</button>
        <button type="button" class="quick-card found" data-action="choose-type" data-type="found"><span class="quick-icon">${icon("found")}</span><strong>REPORT FOUND ITEM</strong>${icon("found")}</button>
      </div>
    </section>
    <section class="section">
      <div class="section-heading"><h2>Recent Reports</h2>${recent.length ? `<button type="button" data-nav="records">View all</button>` : ""}</div>
      <div class="report-list">${recent.length ? recent.map(reportCard).join("") : emptyState("reports")}</div>
    </section>
    ${state.isDevelopment ? `<aside class="dev-card">${icon("refresh")}<span><strong>Demo helper</strong><br>Add matching sample reports.</span><button type="button" data-action="seed-data">ADD SAMPLE DATA</button></aside>` : ""}
  `, "home");
}

function renderReportChoice() {
  setScreen(`
    ${header("Report Item", "", false)}
    <div class="choice-intro"><h2>What happened?</h2><p>Choose one option to start a quick report.</p></div>
    <div class="type-choices">
      <button type="button" class="type-choice lost" data-action="choose-type" data-type="lost"><span class="type-choice-icon">${icon("lost")}</span><strong>I LOST AN ITEM</strong><small>Help the community identify it</small>${icon("lost")}</button>
      <button type="button" class="type-choice found" data-action="choose-type" data-type="found"><span class="type-choice-icon">${icon("found")}</span><strong>I FOUND AN ITEM</strong><small>Connect it with its owner</small>${icon("found")}</button>
    </div>`, "report");
}

function categoryOptions(selected = "") {
  return `<option value="">Select category</option>${categories.map((category) => `<option value="${escapeHtml(category)}"${selected === category ? " selected" : ""}>${escapeHtml(category)}</option>`).join("")}`;
}

function renderReportForm(report = null) {
  const editing = Boolean(report);
  const type = report?.reportType || state.reportType;
  const typeName = type === "lost" ? "Lost" : "Found";
  const dateLabel = type === "lost" ? "Date Lost" : "Date Found";
  setScreen(`
    ${header(editing ? "Edit Report" : `Report ${typeName} Item`, "", true)}
    <div class="form-type-banner ${type}">${icon(type)}<strong>${typeName} item report</strong>${editing ? "" : `<button type="button" data-action="change-type">Change</button>`}</div>
    <form id="report-form" class="form-grid" novalidate data-edit-id="${editing ? escapeHtml(report.id) : ""}">
      <div class="field"><label for="item-name">Item Name <span>*</span></label><div class="input-wrap">${icon("search")}<input id="item-name" name="itemName" maxlength="120" value="${escapeHtml(report?.itemName || "")}" placeholder="e.g. Wallet" required /></div></div>
      <div class="form-row">
        <div class="field"><label for="category">Category <span>*</span></label><div class="input-wrap">${icon("tag")}<select id="category" name="category" required>${categoryOptions(report?.category)}</select></div></div>
        <div class="field"><label for="color">Color <span>*</span></label><div class="input-wrap">${icon("palette")}<input id="color" name="color" maxlength="120" value="${escapeHtml(report?.color || "")}" placeholder="e.g. Black" required /></div></div>
      </div>
      <div class="field"><label for="location">Location <span>*</span></label><div class="input-wrap">${icon("location")}<input id="location" name="location" maxlength="120" value="${escapeHtml(report?.location || "")}" placeholder="e.g. Library" required /></div></div>
      <div class="field"><label for="date">${dateLabel} <span>*</span></label><div class="input-wrap">${icon("calendar")}<input id="date" type="date" name="date" value="${escapeHtml(report?.date || today())}" required /></div></div>
      <div class="field"><label for="description">Description</label><textarea id="description" name="description" maxlength="1000" placeholder="Add details that could help identify the item...">${escapeHtml(report?.description || "")}</textarea><small>Useful details improve matching.</small></div>
      <div class="field"><label for="contact">Contact Information <small>(optional)</small></label><div class="input-wrap">${icon("person")}<input id="contact" name="contactInformation" maxlength="200" value="${escapeHtml(report?.contactInformation || "")}" placeholder="Email, phone, or pickup desk" /></div></div>
      <button class="primary-button form-submit" type="submit">${editing ? "SAVE CHANGES" : "SUBMIT REPORT"}</button>
    </form>`, "report");
}

function renderSuccess() {
  const report = state.lastCreated;
  const label = report.reportType === "lost" ? "lost" : "found";
  setScreen(`
    <section class="success-state">
      <div class="success-icon">${icon("check")}</div>
      <h2>Report Submitted!</h2>
      <p>Your ${label} item has been added successfully.</p>
      <span class="success-id">${escapeHtml(report.id)}</span>
      <div class="button-stack"><button type="button" class="primary-button" data-action="view-report" data-id="${escapeHtml(report.id)}">VIEW REPORT</button><button type="button" class="secondary-button" data-nav="home">BACK TO HOME</button></div>
    </section>`, "report");
}

function matchCard(match) {
  const name = match.lostReport.itemName;
  return `<article class="match-card">
    <div class="match-kicker">${icon("matches")} POSSIBLE MATCH</div>
    <div class="match-main"><div><h3>${escapeHtml(name)}</h3><p>${escapeHtml(match.lostReport.color)} · ${escapeHtml(match.lostReport.category)}</p></div><div class="score-ring" style="--score:${match.score}"><strong>${match.score}<small>%</small></strong></div></div>
    <div class="match-route"><div class="route-side lost"><small>LOST</small><span>${escapeHtml(match.lostReport.location)}</span></div><div class="route-arrow">→</div><div class="route-side found"><small>FOUND</small><span>${escapeHtml(match.foundReport.location)}</span></div></div>
    <span class="match-quality">${escapeHtml(match.quality)}</span>
    <button type="button" class="secondary-button" data-action="view-match" data-lost-id="${escapeHtml(match.lostReport.id)}" data-found-id="${escapeHtml(match.foundReport.id)}">VIEW MATCH</button>
  </article>`;
}

function renderMatches() {
  setScreen(`
    ${header("Smart Matches", "Matches scored by the Rust engine")}
    <div class="match-list">${state.matches.length ? state.matches.map(matchCard).join("") : emptyState("matches")}</div>
  `, "matches");
}

function renderRecords() {
  const content = state.records.length ? state.records.map(reportCard).join("") : emptyState(state.search || state.filter !== "all" ? "search" : "reports");
  setScreen(`
    ${header("Records", "All offline reports")}
    <div class="search-box">${icon("search")}<input id="record-search" type="search" value="${escapeHtml(state.search)}" placeholder="Search items, location, color..." autocomplete="off" /></div>
    <div class="filter-row" aria-label="Filter records">
      ${["all", "lost", "found", "returned"].map((filter) => `<button type="button" class="filter-chip${state.filter === filter ? " active" : ""}" data-action="filter" data-filter="${filter}">${filter[0].toUpperCase()}${filter.slice(1)}</button>`).join("")}
    </div>
    <p class="record-count">${state.records.length} ${state.records.length === 1 ? "report" : "reports"}</p>
    <div class="report-list">${content}</div>`, "records");
  const search = document.querySelector("#record-search");
  search?.focus({ preventScroll: true });
  if (search) search.setSelectionRange(search.value.length, search.value.length);
}

function renderDetails(report) {
  const displayStatus = report.status;
  const dateLabel = report.reportType === "lost" ? "Date Lost" : "Date Found";
  const canMatch = displayStatus !== "returned";
  setScreen(`
    ${header("Report Details", "", true)}
    ${displayStatus === "returned" ? `<div class="returned-banner">${icon("check")} ITEM RETURNED</div>` : ""}
    <section class="detail-hero ${displayStatus}">${statusBadge(displayStatus)}<h2>${escapeHtml(report.itemName)}</h2><p>${escapeHtml(report.id)}</p></section>
    <section class="detail-card">
      <div class="detail-row"><span class="detail-row-icon">${icon("tag")}</span><div><small>Category</small><strong>${escapeHtml(report.category)}</strong></div></div>
      <div class="detail-row"><span class="detail-row-icon">${icon("palette")}</span><div><small>Color</small><strong>${escapeHtml(report.color)}</strong></div></div>
      <div class="detail-row"><span class="detail-row-icon">${icon("location")}</span><div><small>Location</small><strong>${escapeHtml(report.location)}</strong></div></div>
      <div class="detail-row"><span class="detail-row-icon">${icon("calendar")}</span><div><small>${dateLabel}</small><strong>${formatDate(report.date, true)}</strong></div></div>
      <div class="detail-row"><span class="detail-row-icon">${icon("records")}</span><div><small>Description</small><p>${escapeHtml(report.description || "No description provided.")}</p></div></div>
      ${report.contactInformation ? `<div class="detail-row"><span class="detail-row-icon">${icon("person")}</span><div><small>Contact Information</small><p>${escapeHtml(report.contactInformation)}</p></div></div>` : ""}
      <div class="detail-row"><span class="detail-row-icon">${icon("calendar")}</span><div><small>Created</small><strong>${new Intl.DateTimeFormat("en-US", { dateStyle: "long", timeStyle: "short" }).format(new Date(report.createdAt))}</strong></div></div>
    </section>
    ${canMatch ? `<div class="detail-actions"><button type="button" class="primary-button button-icon" data-action="find-for-report" data-id="${escapeHtml(report.id)}">${icon("matches")} FIND POSSIBLE MATCH</button></div>` : ""}
    <div class="detail-actions two"><button type="button" class="secondary-button button-icon" data-action="edit-report">${icon("edit")} EDIT REPORT</button><button type="button" class="danger-button button-icon" data-action="delete-report">${icon("trash")} DELETE</button></div>
  `, state.backTarget === "records" ? "records" : "home");
}

function comparisonCard(report, type) {
  return `<article class="comparison-card ${type}"><span class="comparison-card-label">${type.toUpperCase()} ITEM</span><h3>${escapeHtml(report.itemName)}</h3><div class="comparison-facts"><span>${escapeHtml(report.color)}</span><span>${escapeHtml(report.location)}</span><span>${formatDate(report.date)}</span><span>${escapeHtml(report.category)}</span></div></article>`;
}

function renderMatchDetails(match) {
  setScreen(`
    ${header("Possible Match", "", true)}
    ${comparisonCard(match.lostReport, "lost")}<div class="versus">VS</div>${comparisonCard(match.foundReport, "found")}
    <section class="big-score"><div class="score-ring" style="--score:${match.score}"><strong>${match.score}<small>%</small></strong></div><h3>${escapeHtml(match.quality)}</h3></section>
    <section class="reason-list">${match.reasons.map((reason) => `<div class="reason-row${reason.matched ? " matched" : ""}"><span class="reason-mark">${reason.matched ? icon("check") : icon("close")}</span><span>${escapeHtml(reason.label)}</span><span class="reason-points">+${reason.points}/${reason.maxPoints}</span></div>`).join("")}</section>
    <div class="detail-actions"><button type="button" class="primary-button button-icon" data-action="mark-returned">${icon("check")} MARK AS RETURNED</button></div>`, "matches");
}

function openModal({ title, message, confirm, action, danger = false }) {
  modalRoot.innerHTML = `<div class="modal-backdrop" data-action="close-modal"><section class="modal" role="dialog" aria-modal="true" aria-labelledby="modal-title" data-modal-panel><div class="modal-icon ${danger ? "" : "success"}">${icon(danger ? "trash" : "check")}</div><h2 id="modal-title">${escapeHtml(title)}</h2><p>${escapeHtml(message)}</p><div class="button-row"><button type="button" class="secondary-button" data-action="close-modal">Cancel</button><button type="button" class="${danger ? "danger" : "primary"}-button" data-action="${action}">${escapeHtml(confirm)}</button></div></section></div>`;
}

function closeModal() { modalRoot.innerHTML = ""; }

async function loadHome() {
  state.screen = "home";
  try {
    [state.statistics, state.records] = await Promise.all([
      backend("get_statistics"),
      backend("get_reports", { query: null }),
    ]);
    state.connectionError = false;
  } catch (error) {
    state.connectionError = !isTauri;
    if (isTauri) showToast(friendlyError(error), true);
  }
  renderHome();
}

async function loadMatches(reportId = null) {
  state.screen = "matches";
  try {
    state.matches = await backend("find_matches", { reportId });
  } catch (error) {
    state.matches = [];
    if (isTauri) showToast(friendlyError(error), true);
  }
  renderMatches();
}

async function loadRecords() {
  state.screen = "records";
  try {
    const query = { search: state.search || null, status: state.filter === "all" ? null : state.filter };
    state.records = await backend("get_reports", { query });
  } catch (error) {
    state.records = [];
    if (isTauri) showToast(friendlyError(error), true);
  }
  renderRecords();
}

async function openReport(id) {
  try {
    state.currentReport = await backend("get_report", { id });
    state.screen = "details";
    renderDetails(state.currentReport);
  } catch (error) {
    showToast(friendlyError(error), true);
  }
}

async function navigate(screen) {
  closeModal();
  if (screen === "home") return loadHome();
  if (screen === "report") {
    state.screen = "report";
    state.reportType = null;
    state.lastCreated = null;
    return renderReportChoice();
  }
  if (screen === "matches") return loadMatches();
  if (screen === "records") {
    state.search = "";
    state.filter = "all";
    return loadRecords();
  }
}

async function submitReport(form) {
  if (!form.reportValidity()) {
    form.reportValidity();
    return;
  }
  const button = form.querySelector("[type=submit]");
  button.disabled = true;
  button.textContent = form.dataset.editId ? "SAVING..." : "SUBMITTING...";
  const data = Object.fromEntries(new FormData(form));
  data.contactInformation = data.contactInformation.trim() || null;
  try {
    if (form.dataset.editId) {
      state.currentReport = await backend("update_report", { id: form.dataset.editId, input: data });
      showToast("Report updated successfully.");
      state.screen = "details";
      renderDetails(state.currentReport);
    } else {
      data.reportType = state.reportType;
      state.lastCreated = await backend("add_report", { input: data });
      state.screen = "success";
      renderSuccess();
    }
  } catch (error) {
    showToast(friendlyError(error), true);
    button.disabled = false;
    button.textContent = form.dataset.editId ? "SAVE CHANGES" : "SUBMIT REPORT";
  }
}

app.addEventListener("submit", (event) => {
  if (event.target.id === "report-form") {
    event.preventDefault();
    submitReport(event.target);
  }
});

let searchTimer;
app.addEventListener("input", (event) => {
  if (event.target.id !== "record-search") return;
  state.search = event.target.value;
  clearTimeout(searchTimer);
  searchTimer = setTimeout(loadRecords, 220);
});

document.addEventListener("click", async (event) => {
  const navTarget = event.target.closest("[data-nav]");
  if (navTarget) {
    await navigate(navTarget.dataset.nav);
    return;
  }
  const target = event.target.closest("[data-action]");
  if (!target) return;
  const action = target.dataset.action;

  if (action === "choose-type") {
    state.reportType = target.dataset.type;
    state.screen = "reportForm";
    renderReportForm();
  } else if (action === "change-type") {
    state.reportType = null;
    state.screen = "report";
    renderReportChoice();
  } else if (action === "view-report") {
    state.backTarget = state.screen === "records" ? "records" : "home";
    await openReport(target.dataset.id);
  } else if (action === "filter") {
    state.filter = target.dataset.filter;
    await loadRecords();
  } else if (action === "view-match") {
    state.currentMatch = state.matches.find((match) => match.lostReport.id === target.dataset.lostId && match.foundReport.id === target.dataset.foundId);
    if (state.currentMatch) { state.screen = "matchDetails"; renderMatchDetails(state.currentMatch); }
  } else if (action === "back") {
    if (state.screen === "reportForm") renderReportChoice();
    else if (state.screen === "edit") { state.screen = "details"; renderDetails(state.currentReport); }
    else if (state.screen === "details") await navigate(state.backTarget);
    else if (state.screen === "matchDetails") renderMatches();
    else await navigate("home");
  } else if (action === "edit-report") {
    state.screen = "edit";
    renderReportForm(state.currentReport);
  } else if (action === "delete-report") {
    openModal({ title: "Delete Report?", message: "Are you sure you want to permanently delete this report?", confirm: "Delete", action: "confirm-delete", danger: true });
  } else if (action === "confirm-delete") {
    try {
      await backend("delete_report", { id: state.currentReport.id });
      closeModal();
      showToast("Report deleted.");
      await navigate("records");
    } catch (error) { showToast(friendlyError(error), true); }
  } else if (action === "find-for-report") {
    await loadMatches(target.dataset.id);
    if (!state.matches.length) showToast("No match above 60% yet.");
  } else if (action === "mark-returned") {
    openModal({ title: "Item Returned?", message: "Has this item been successfully returned to its owner?", confirm: "Yes, Mark Returned", action: "confirm-returned" });
  } else if (action === "confirm-returned") {
    try {
      await backend("mark_as_returned", { lostId: state.currentMatch.lostReport.id, foundId: state.currentMatch.foundReport.id });
      closeModal();
      showToast("Items marked as returned!");
      await loadHome();
    } catch (error) { showToast(friendlyError(error), true); }
  } else if (action === "close-modal") {
    if (!target.hasAttribute("data-modal-panel")) closeModal();
  } else if (action === "seed-data") {
    try {
      await backend("seed_sample_data");
      showToast("Demo data is ready.");
      await loadHome();
    } catch (error) { showToast(friendlyError(error), true); }
  }
});

async function initialize() {
  try { state.isDevelopment = await backend("is_development"); } catch { state.isDevelopment = false; }
  await loadHome();
  const elapsedMinimum = new Promise((resolve) => setTimeout(resolve, 1050));
  await elapsedMinimum;
  document.querySelector("#splash").classList.add("hidden");
}

initialize();
