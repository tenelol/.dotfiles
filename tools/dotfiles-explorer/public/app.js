const elements = {
  error: document.querySelector("#error-banner"),
  fileCount: document.querySelector("#file-count"),
  fileInspector: document.querySelector("#file-inspector"),
  fileTree: document.querySelector("#file-tree"),
  gitSummary: document.querySelector("#git-summary"),
  hosts: document.querySelector("#hosts"),
  inventory: document.querySelector("#inventory"),
  inventoryTabs: document.querySelector("#inventory-tabs"),
  moduleCount: document.querySelector("#module-count"),
  modules: document.querySelector("#modules"),
  rices: document.querySelector("#rices"),
  runtimeCard: document.querySelector("#runtime-card"),
  search: document.querySelector("#search-input"),
  syncLabel: document.querySelector("#sync-label"),
  topology: document.querySelector("#topology"),
};

const inventoryTabs = [
  { id: "homebrew", label: "Homebrew" },
  { id: "nix", label: "Nix" },
  { id: "custom", label: "Custom" },
  { id: "inputs", label: "Inputs" },
];
const pathDescriptions = [
  ["flake.nix", "すべての host、module、rice を束ねる flake の入口です。"],
  [
    "hosts/",
    "machine 固有の metadata、system、rice、hardware import を置きます。",
  ],
  ["modules/", "denix が自動発見する共有・host 固有の振る舞いです。"],
  ["rices/", "window manager と theme の組み合わせを切り替えます。"],
  ["home/", "system configuration に統合される Home Manager 設定です。"],
  ["lib/", "module から明示 import する helper と生成ロジックです。"],
  ["packages/", "この repository で組み立てる独自 Nix package です。"],
  ["config/", "Neovim、Ghostty、WM などへ配る実設定ファイルです。"],
  ["scripts/", "検証や運用で直接実行する補助コマンドです。"],
  ["tools/", "repository 自身を観測・操作する開発ツールです。"],
];

let state = null;
let fingerprint = "";
let activeInventoryTab = "homebrew";
let selectedPath = "flake.nix";
let query = "";

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function pathDescription(path) {
  const match = pathDescriptions.find(([prefix]) =>
    prefix.endsWith("/") ? path.startsWith(prefix) : path === prefix,
  );
  if (match) return match[1];
  if (path.endsWith(".nix")) {
    return "Nix の宣言ファイルです。保存すると explorer の集計へ自動で反映されます。";
  }
  return "repository で管理されている設定・補助ファイルです。";
}

function includesQuery(...values) {
  if (!query) return true;
  return values.some((value) =>
    String(value || "")
      .toLowerCase()
      .includes(query),
  );
}

function filteredTree(node) {
  if (!query) return node;
  const children = (node.children || []).map(filteredTree).filter(Boolean);
  if (includesQuery(node.name, node.path) || children.length) {
    return { ...node, children };
  }
  return null;
}

function treeMarkup(node, depth = 0) {
  if (node.type === "directory") {
    const children = (node.children || [])
      .map((child) => treeMarkup(child, depth + 1))
      .join("");
    return `
      <details class="tree-node" ${depth === 0 || query ? "open" : ""}>
        <summary>${escapeHtml(node.name)}</summary>
        <div class="tree-children">${children}</div>
      </details>
    `;
  }

  return `
    <button
      class="tree-file ${selectedPath === node.path ? "is-selected" : ""}"
      type="button"
      data-path="${escapeHtml(node.path)}"
    >
      <span>${escapeHtml(node.name)}</span>
      <span class="tree-ext">${escapeHtml(node.extension)}</span>
    </button>
  `;
}

function renderTree() {
  const nodes = state.tree.map(filteredTree).filter(Boolean);
  elements.fileTree.innerHTML = nodes.length
    ? nodes.map((node) => treeMarkup(node)).join("")
    : '<div class="empty">一致するファイルがありません。</div>';
  elements.fileCount.textContent = `${state.repository.filesVisible} files`;

  for (const button of elements.fileTree.querySelectorAll(".tree-file")) {
    button.addEventListener("click", () => {
      selectedPath = button.dataset.path;
      renderTree();
      renderInspector();
    });
  }
}

function renderInspector() {
  elements.fileInspector.innerHTML = `
    <p class="eyebrow">Selected path</p>
    <strong>${escapeHtml(selectedPath)}</strong>
    <p>${escapeHtml(pathDescription(selectedPath))}</p>
  `;
}

function renderRuntime() {
  const runtime = state.runtime;
  elements.runtimeCard.classList.remove("loading");
  elements.runtimeCard.innerHTML = `
    <p class="eyebrow">Active signal</p>
    <strong>${escapeHtml(runtime.target || runtime.host)}</strong>
    <span>${escapeHtml(runtime.os)} / ${escapeHtml(runtime.arch)}</span>
    <span>rice: ${escapeHtml(runtime.rice || "not detected")}</span>
  `;
}

function renderTopology() {
  const activeHost = state.runtime.host;
  const nodes = [
    { label: "flake inputs", count: state.inventory.flakeInputs.length },
    { label: "hosts", count: state.hosts.length, active: true },
    { label: "modules", count: state.modules.length },
    {
      label: "rices",
      count: state.rices.length,
      active: Boolean(state.runtime.rice),
    },
  ];

  elements.topology.innerHTML = `
    <div class="source-node">
      <div>
        <span class="eyebrow">Source</span>
        <div class="node-label">flake.nix</div>
      </div>
      <p>denix が host / module / rice を発見し、NixOS と nix-darwin の target を生成します。</p>
    </div>
    <div class="bus" aria-hidden="true"></div>
    <div class="topology-outputs">
      ${nodes
        .map(
          (node) => `
            <div class="output-node ${node.active ? "active" : ""}">
              <b>${node.count}</b>
              <span>${escapeHtml(node.label)}</span>
            </div>
          `,
        )
        .join("")}
    </div>
  `;

  const git = state.repository.git;
  const dirty = git.dirty ? `${git.changes.length} changed` : "clean";
  elements.gitSummary.textContent = `${git.branch} @ ${git.commit.hash} · ${dirty} · ${git.commit.subject}`;
  elements.topology.dataset.activeHost = activeHost;
}

function renderHosts() {
  elements.hosts.innerHTML = state.hosts
    .map((host) => {
      const active = host.name === state.runtime.host;
      const tags = [
        ...(host.rice ? [{ text: host.rice, className: "is-rice" }] : []),
        ...host.features.map((feature) => ({ text: feature, className: "" })),
        ...host.enabled.slice(0, 3).map((module) => ({
          text: module,
          className: "",
        })),
      ];
      return `
        <article class="host-card ${active ? "is-active" : ""}">
          <header>
            <h3>${escapeHtml(host.name)}</h3>
            <span class="machine-type">${escapeHtml(host.type)}</span>
          </header>
          <p class="host-system">${escapeHtml(host.system)}</p>
          <div class="tags">
            ${tags
              .map(
                (tag) =>
                  `<span class="tag ${tag.className}">${escapeHtml(tag.text)}</span>`,
              )
              .join("")}
          </div>
        </article>
      `;
    })
    .join("");

  elements.rices.innerHTML = state.rices
    .map((rice) => {
      const enabled = rice.toggles
        .filter((toggle) => toggle.enabled)
        .map((toggle) => toggle.name)
        .join(" · ");
      return `
        <div class="rice-item ${rice.name === state.runtime.rice ? "is-active" : ""}">
          <b>${escapeHtml(rice.name)}</b>
          <span>${escapeHtml(enabled || rice.wallpaper || "theme only")}</span>
        </div>
      `;
    })
    .join("");
}

function inventoryGroup(title, items) {
  const visible = items.filter((item) => includesQuery(item));
  return `
    <section class="inventory-group">
      <h3>${escapeHtml(title)} <span>${visible.length}</span></h3>
      <div class="inventory-list">
        ${
          visible.length
            ? visible
                .map(
                  (item) =>
                    `<span class="inventory-item">${escapeHtml(item)}</span>`,
                )
                .join("")
            : '<span class="empty">一致する項目なし</span>'
        }
      </div>
    </section>
  `;
}

function renderInventoryTabs() {
  elements.inventoryTabs.innerHTML = inventoryTabs
    .map(
      (tab) => `
        <button
          class="tab"
          type="button"
          role="tab"
          aria-selected="${tab.id === activeInventoryTab}"
          data-tab="${tab.id}"
        >${tab.label}</button>
      `,
    )
    .join("");

  for (const button of elements.inventoryTabs.querySelectorAll(".tab")) {
    button.addEventListener("click", () => {
      activeInventoryTab = button.dataset.tab;
      renderInventoryTabs();
      renderInventory();
    });
  }
}

function renderInventory() {
  const inventory = state.inventory;
  let groups = [];

  if (activeInventoryTab === "homebrew") {
    groups = [
      ["CLI brews", inventory.homebrew.brews],
      ["Base casks", inventory.homebrew.casks],
      ["Full desktop", inventory.homebrew.desktopCasks],
      ["Mac App Store", inventory.homebrew.masApps],
    ];
  } else if (activeInventoryTab === "nix") {
    groups = inventory.nixGroups.map((group) => [group.name, group.packages]);
  } else if (activeInventoryTab === "custom") {
    groups = [["packages/", inventory.customPackages]];
  } else {
    groups = [
      [
        "flake inputs",
        inventory.flakeInputs.map((input) => `${input.name} · ${input.source}`),
      ],
    ];
  }

  elements.inventory.innerHTML = `
    <div class="inventory-groups">
      ${groups.map(([title, items]) => inventoryGroup(title, items)).join("")}
    </div>
  `;
}

function renderModules() {
  const modules = state.modules.filter((module) =>
    includesQuery(module.name, module.path, ...module.scope),
  );
  elements.moduleCount.textContent = `${modules.length} / ${state.modules.length}`;
  elements.modules.innerHTML = modules.length
    ? modules
        .map(
          (module) => `
            <article class="module-card">
              <b title="${escapeHtml(module.path)}">${escapeHtml(module.name)}</b>
              <div>
                ${module.scope
                  .map(
                    (scope) =>
                      `<span class="scope">${escapeHtml(scope)}</span>`,
                  )
                  .join("")}
              </div>
            </article>
          `,
        )
        .join("")
    : '<div class="empty">一致する module がありません。</div>';
}

function renderAll() {
  renderTree();
  renderInspector();
  renderRuntime();
  renderTopology();
  renderHosts();
  renderInventoryTabs();
  renderInventory();
  renderModules();
}

function showUpdatedSignal() {
  const readout = elements.syncLabel.closest(".live-readout");
  readout.classList.remove("is-updating");
  requestAnimationFrame(() => readout.classList.add("is-updating"));
}

async function loadState() {
  try {
    const response = await fetch("/api/state", { cache: "no-store" });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const nextState = await response.json();
    const { generatedAt: _generatedAt, ...stableState } = nextState;
    const nextFingerprint = JSON.stringify(stableState);
    const firstRender = !fingerprint;
    const changed = fingerprint && fingerprint !== nextFingerprint;

    state = nextState;
    fingerprint = nextFingerprint;
    elements.error.hidden = true;
    elements.syncLabel.textContent = `LIVE · ${new Date(nextState.generatedAt).toLocaleTimeString("ja-JP")}`;

    if (changed) showUpdatedSignal();
    if (firstRender || changed) renderAll();
  } catch (error) {
    elements.error.hidden = false;
    elements.error.textContent = `構成を読み込めません。ローカルサーバーを確認してください: ${error.message}`;
    elements.syncLabel.textContent = "接続待ち";
  }
}

elements.search.addEventListener("input", (event) => {
  query = event.target.value.trim().toLowerCase();
  if (!state) return;
  renderTree();
  renderInventory();
  renderModules();
});

await loadState();
window.setInterval(loadState, 3000);
