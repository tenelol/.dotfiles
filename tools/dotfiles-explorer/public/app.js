const TYPE_META = {
  root: { label: "Root", color: "#edf8ff", radius: 17 },
  cluster: { label: "Group", color: "#5277c3", radius: 9 },
  file: { label: "Structure", color: "#8fc9ed", radius: 6 },
  host: { label: "Hosts", color: "#7ebae4", radius: 9 },
  rice: { label: "Rices", color: "#a8c7f0", radius: 8 },
  module: { label: "Modules", color: "#62b9d1", radius: 5 },
  package: { label: "Packages", color: "#d1e8f7", radius: 4 },
  input: { label: "Inputs", color: "#9ab9e5", radius: 6 },
};

const CATEGORY_META = [
  {
    id: "structure",
    label: "Structure",
    color: TYPE_META.file.color,
    default: true,
  },
  { id: "host", label: "Hosts", color: TYPE_META.host.color, default: true },
  { id: "rice", label: "Rices", color: TYPE_META.rice.color, default: true },
  {
    id: "module",
    label: "Modules",
    color: TYPE_META.module.color,
    default: true,
  },
  {
    id: "input",
    label: "Flake inputs",
    color: TYPE_META.input.color,
    default: true,
  },
  {
    id: "package",
    label: "Packages",
    color: TYPE_META.package.color,
    default: false,
  },
];

const TYPE_LABELS = {
  root: "flake root",
  cluster: "collection",
  file: "repository path",
  host: "host",
  rice: "rice",
  module: "module",
  package: "package",
  input: "flake input",
};

const SNOWFLAKE_ARMS = [
  "structure",
  "rice",
  "package",
  "module",
  "input",
  "host",
];

const elements = {
  accessibleNodes: document.querySelector("#accessible-nodes"),
  canvas: document.querySelector("#graph-canvas"),
  error: document.querySelector("#error-banner"),
  filterList: document.querySelector("#filter-list"),
  fitGraph: document.querySelector("#fit-graph"),
  gitChip: document.querySelector("#git-chip"),
  graphShell: document.querySelector("#graph-shell"),
  graphStats: document.querySelector("#graph-stats"),
  inspector: document.querySelector("#inspector"),
  search: document.querySelector("#search-input"),
  syncStatus: document.querySelector("#sync-status"),
  targetChip: document.querySelector("#target-chip"),
  toggleLabels: document.querySelector("#toggle-labels"),
  toggleMotion: document.querySelector("#toggle-motion"),
  visibleCount: document.querySelector("#visible-count"),
  zoomIn: document.querySelector("#zoom-in"),
  zoomLabel: document.querySelector("#zoom-label"),
  zoomOut: document.querySelector("#zoom-out"),
};

const canvasContext = elements.canvas.getContext("2d");
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
const enabledCategories = new Set(
  CATEGORY_META.filter((category) => category.default).map(
    (category) => category.id,
  ),
);

let sourceState = null;
let stateFingerprint = "";
let allNodes = [];
let allEdges = [];
let visibleNodes = [];
let visibleEdges = [];
let nodeById = new Map();
let selectedId = null;
let hoveredId = null;
let focusNeighbors = false;
let searchQuery = "";
let searchMatches = new Set();
let showLabels = true;
let motionEnabled = !reducedMotion.matches;
let layoutEnergy = 1;
let viewWidth = 0;
let viewHeight = 0;
let pixelRatio = 1;
let zoom = 1;
let panX = 0;
let panY = 0;
let pointerState = null;
let lastPointer = { x: 0, y: 0 };
let snowParticles = [];

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function stableHash(value) {
  let hash = 2166136261;
  for (const character of String(value)) {
    hash ^= character.charCodeAt(0);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function seededPosition(id, category, index = 0, total = 1) {
  if (category === "core") return { x: 0, y: 0 };
  const hash = stableHash(id);
  const angle =
    ((hash % 6283) / 1000 + (index / Math.max(total, 1)) * Math.PI * 2) %
    (Math.PI * 2);
  const radius = 36 + (hash % 74);
  return {
    x: Math.cos(angle) * radius,
    y: Math.sin(angle) * radius,
  };
}

function makeNode({
  id,
  label,
  type,
  category = type,
  path = null,
  active = false,
  details = {},
  anchored = false,
  index = 0,
  total = 1,
}) {
  const previous = nodeById.get(id);
  const initial = previous || seededPosition(id, category, index, total);
  return {
    id,
    label,
    type,
    category,
    path,
    active,
    details,
    anchored,
    x: initial.x,
    y: initial.y,
    targetX: previous?.targetX || initial.x,
    targetY: previous?.targetY || initial.y,
    vx: previous?.vx || 0,
    vy: previous?.vy || 0,
  };
}

function addEdge(edges, source, target, kind = "contains", active = false) {
  edges.push({
    id: `${source}→${target}:${kind}`,
    source,
    target,
    kind,
    active,
  });
}

function countTreeChildren(node) {
  return (node.children || []).reduce(
    (total, child) => total + 1 + countTreeChildren(child),
    0,
  );
}

function snowflakeSlots(count) {
  const slots = [];
  let layer = 0;

  while (slots.length < count) {
    const radius = 128 + layer * 31;
    for (let arm = 0; arm < 6 && slots.length < count; arm += 1) {
      const angle = -Math.PI / 2 + (arm / 6) * Math.PI * 2;
      const baseX = Math.cos(angle) * radius;
      const baseY = Math.sin(angle) * radius;
      slots.push({ x: baseX, y: baseY });

      if (layer > 0) {
        const branchLength = 17 + Math.min(layer * 4.5, 48);
        for (const direction of [-1, 1]) {
          if (slots.length >= count) break;
          const branchAngle = angle + direction * (Math.PI / 3);
          slots.push({
            x: baseX + Math.cos(branchAngle) * branchLength,
            y: baseY + Math.sin(branchAngle) * branchLength,
          });
        }
      }
    }
    layer += 1;
  }

  return slots;
}

function assignSnowflakeTargets() {
  const root = nodeById.get("flake");
  if (root) {
    root.targetX = 0;
    root.targetY = 0;
  }

  const mainGroups = visibleNodes.filter(
    (node) => node.type === "cluster" && node.anchored,
  );
  for (const group of mainGroups) {
    const arm = Math.max(0, SNOWFLAKE_ARMS.indexOf(group.category));
    const angle = -Math.PI / 2 + (arm / 6) * Math.PI * 2;
    group.targetX = Math.cos(angle) * 90;
    group.targetY = Math.sin(angle) * 90;
  }

  const shapeNodes = visibleNodes
    .filter((node) => node.type !== "root" && !node.anchored)
    .sort((left, right) => stableHash(left.id) - stableHash(right.id));
  const slots = snowflakeSlots(shapeNodes.length);
  shapeNodes.forEach((node, index) => {
    node.targetX = slots[index].x;
    node.targetY = slots[index].y;
  });

  if (!motionEnabled || reducedMotion.matches) {
    for (const node of visibleNodes) {
      node.x = node.targetX;
      node.y = node.targetY;
      node.vx = 0;
      node.vy = 0;
    }
  }
}

function flattenPackages(inventory) {
  const packages = [];
  const seen = new Set();
  const add = (manager, group, names) => {
    for (const name of names) {
      const key = `${manager}:${name}`;
      if (seen.has(key)) continue;
      seen.add(key);
      packages.push({ name, manager, group });
    }
  };

  add("Homebrew", "CLI brews", inventory.homebrew.brews);
  add("Homebrew", "Base casks", inventory.homebrew.casks);
  add("Homebrew", "Full desktop", inventory.homebrew.desktopCasks);
  add("MAS", "Mac App Store", inventory.homebrew.masApps);
  for (const group of inventory.nixGroups) {
    add("Nix", group.name, group.packages);
  }
  add("Local", "packages/", inventory.customPackages);
  return packages;
}

function buildGraph(state) {
  const previousNodes = nodeById;
  nodeById = previousNodes;
  const nodes = [];
  const edges = [];

  nodes.push(
    makeNode({
      id: "flake",
      label: "flake.nix",
      type: "root",
      category: "core",
      path: "flake.nix",
      anchored: true,
      details: {
        role: "denix control plane",
        description: state.repository.description,
        files: `${state.repository.filesVisible} visible`,
        nix: `${state.repository.nixFiles} Nix files`,
      },
    }),
  );

  const groups = [
    ["group:structure", "repository", "structure", state.tree.length],
    ["group:hosts", "hosts/", "host", state.hosts.length],
    ["group:rices", "rices/", "rice", state.rices.length],
    ["group:modules", "modules/", "module", state.modules.length],
    [
      "group:inputs",
      "flake inputs",
      "input",
      state.inventory.flakeInputs.length,
    ],
    [
      "group:packages",
      "packages",
      "package",
      flattenPackages(state.inventory).length,
    ],
  ];

  for (const [id, label, category, count] of groups) {
    nodes.push(
      makeNode({
        id,
        label,
        type: "cluster",
        category,
        path: label.endsWith("/") ? label : null,
        anchored: true,
        details: {
          count,
          category:
            CATEGORY_META.find((item) => item.id === category)?.label ||
            category,
        },
      }),
    );
    addEdge(
      edges,
      "flake",
      id,
      "group",
      category === "host" || category === "rice",
    );
  }

  state.tree.forEach((entry, index) => {
    const id = `file:${entry.path}`;
    nodes.push(
      makeNode({
        id,
        label: entry.name,
        type: "file",
        category: "structure",
        path: entry.path,
        index,
        total: state.tree.length,
        details: {
          kind: entry.type,
          descendants:
            entry.type === "directory" ? countTreeChildren(entry) : 0,
        },
      }),
    );
    addEdge(edges, "group:structure", id);
  });

  state.hosts.forEach((host, index) => {
    const id = `host:${host.name}`;
    nodes.push(
      makeNode({
        id,
        label: host.name,
        type: "host",
        path: `hosts/${host.name}/default.nix`,
        active: host.name === state.runtime.host,
        index,
        total: state.hosts.length,
        details: {
          system: host.system,
          type: host.type,
          rice: host.rice || "none",
          features: host.features.join(", ") || "base",
          enabled: host.enabled.join(", ") || "defaults",
        },
      }),
    );
    const active = host.name === state.runtime.host;
    addEdge(edges, "group:hosts", id, "contains", active);
    if (host.rice) {
      addEdge(
        edges,
        id,
        `rice:${host.rice}`,
        "uses",
        active && host.rice === state.runtime.rice,
      );
    }
  });

  state.rices.forEach((rice, index) => {
    const enabled = rice.toggles
      .filter((toggle) => toggle.enabled)
      .map((toggle) => toggle.name);
    nodes.push(
      makeNode({
        id: `rice:${rice.name}`,
        label: rice.name,
        type: "rice",
        path: `rices/${rice.name}.nix`,
        active: rice.name === state.runtime.rice,
        index,
        total: state.rices.length,
        details: {
          enabled: enabled.join(", ") || "theme only",
          wallpaper: rice.wallpaper || "inherited",
        },
      }),
    );
    addEdge(
      edges,
      "group:rices",
      `rice:${rice.name}`,
      "contains",
      rice.name === state.runtime.rice,
    );
  });

  state.modules.forEach((module, index) => {
    const id = `module:${module.path}`;
    nodes.push(
      makeNode({
        id,
        label: module.name,
        type: "module",
        path: module.path,
        index,
        total: state.modules.length,
        details: {
          scope: module.scope.join(", "),
          configurable: module.configurable ? "yes" : "no",
        },
      }),
    );
    addEdge(edges, "group:modules", id);
  });

  state.inventory.flakeInputs.forEach((input, index) => {
    const id = `input:${input.name}`;
    nodes.push(
      makeNode({
        id,
        label: input.name,
        type: "input",
        path: "flake.nix",
        index,
        total: state.inventory.flakeInputs.length,
        details: { source: input.source },
      }),
    );
    addEdge(edges, "group:inputs", id);
  });

  const packages = flattenPackages(state.inventory);
  const packageGroups = new Map();
  for (const item of packages) {
    const groupId = `package-group:${item.manager}:${item.group}`;
    if (!packageGroups.has(groupId)) {
      packageGroups.set(groupId, {
        manager: item.manager,
        group: item.group,
      });
    }
  }

  [...packageGroups.entries()].forEach(([id, item], index) => {
    nodes.push(
      makeNode({
        id,
        label: item.group,
        type: "cluster",
        category: "package",
        index,
        total: packageGroups.size,
        details: { manager: item.manager },
      }),
    );
    addEdge(edges, "group:packages", id, "package group");
  });

  packages.forEach((item, index) => {
    const groupId = `package-group:${item.manager}:${item.group}`;
    const id = `package:${item.manager}:${item.name}`;
    nodes.push(
      makeNode({
        id,
        label: item.name,
        type: "package",
        category: "package",
        path: item.manager === "Local" ? `packages/${item.name}.nix` : null,
        index,
        total: packages.length,
        details: {
          manager: item.manager,
          group: item.group,
        },
      }),
    );
    addEdge(edges, groupId, id);
  });

  allNodes = nodes;
  allEdges = edges;
  nodeById = new Map(nodes.map((node) => [node.id, node]));
  updateVisibleGraph();
}

function categoryVisible(node) {
  if (node.type === "root") return true;
  return enabledCategories.has(node.category);
}

function updateVisibleGraph() {
  visibleNodes = allNodes.filter(categoryVisible);
  const visibleIds = new Set(visibleNodes.map((node) => node.id));
  visibleEdges = allEdges.filter(
    (edge) => visibleIds.has(edge.source) && visibleIds.has(edge.target),
  );

  if (selectedId && !visibleIds.has(selectedId)) {
    selectedId = null;
    focusNeighbors = false;
  }

  assignSnowflakeTargets();
  layoutEnergy = 1;
  renderFilters();
  updateSearchMatches();
  updateInspector();
  updateStats();
}

function renderFilters() {
  const counts = new Map(
    CATEGORY_META.map((category) => [
      category.id,
      allNodes.filter(
        (node) => node.category === category.id && node.type !== "cluster",
      ).length,
    ]),
  );

  elements.filterList.innerHTML = CATEGORY_META.map(
    (category) => `
      <button
        class="filter-button"
        type="button"
        data-category="${category.id}"
        aria-pressed="${enabledCategories.has(category.id)}"
        style="--filter-color: ${category.color}"
      >
        <i></i>
        <span>${category.label}</span>
        <small>${counts.get(category.id) || 0}</small>
      </button>
    `,
  ).join("");

  for (const button of elements.filterList.querySelectorAll(".filter-button")) {
    button.addEventListener("click", () => {
      const category = button.dataset.category;
      if (enabledCategories.has(category)) enabledCategories.delete(category);
      else enabledCategories.add(category);
      updateVisibleGraph();
    });
  }
}

function updateSearchMatches() {
  searchMatches = new Set();
  if (searchQuery) {
    for (const node of visibleNodes) {
      const haystack = [
        node.label,
        node.path,
        node.type,
        ...Object.values(node.details),
      ]
        .join(" ")
        .toLowerCase();
      if (haystack.includes(searchQuery)) searchMatches.add(node.id);
    }
  }

  elements.accessibleNodes.textContent = searchQuery
    ? `${searchMatches.size}件: ${[...searchMatches]
        .slice(0, 20)
        .map((id) => nodeById.get(id)?.label)
        .join(", ")}`
    : `${visibleNodes.length}件のノードを表示中`;
}

function connectedIds(nodeId) {
  const connected = new Set();
  for (const edge of visibleEdges) {
    if (edge.source === nodeId) connected.add(edge.target);
    if (edge.target === nodeId) connected.add(edge.source);
  }
  return connected;
}

function nodeEmphasis(node) {
  if (node.active || node.id === selectedId || node.id === hoveredId) return 1;
  if (searchQuery) {
    if (searchMatches.has(node.id)) return 1;
    const searchNeighbors = new Set(
      [...searchMatches].flatMap((id) => [...connectedIds(id)]),
    );
    return searchNeighbors.has(node.id) ? 0.58 : 0.1;
  }
  if (focusNeighbors && selectedId) {
    return connectedIds(selectedId).has(node.id) ? 0.78 : 0.1;
  }
  if (selectedId) {
    return connectedIds(selectedId).has(node.id) ? 0.82 : 0.34;
  }
  return node.type === "module" || node.type === "package" ? 0.72 : 1;
}

function edgeEmphasis(edge) {
  if (
    edge.source === selectedId ||
    edge.target === selectedId ||
    edge.source === hoveredId ||
    edge.target === hoveredId
  ) {
    return 0.9;
  }
  const source = nodeById.get(edge.source);
  const target = nodeById.get(edge.target);
  if (source?.active || target?.active) return 0.55;
  if (focusNeighbors && selectedId) return 0.04;
  if (searchQuery) {
    return searchMatches.has(edge.source) || searchMatches.has(edge.target)
      ? 0.46
      : 0.03;
  }
  return selectedId ? 0.08 : 0.14;
}

function resizeCanvas() {
  const rect = elements.graphShell.getBoundingClientRect();
  viewWidth = rect.width;
  viewHeight = rect.height;
  pixelRatio = Math.min(window.devicePixelRatio || 1, 2);
  elements.canvas.width = Math.round(viewWidth * pixelRatio);
  elements.canvas.height = Math.round(viewHeight * pixelRatio);
  elements.canvas.style.width = `${viewWidth}px`;
  elements.canvas.style.height = `${viewHeight}px`;
  canvasContext.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
  snowParticles = Array.from(
    { length: Math.max(28, Math.floor(viewWidth / 22)) },
    (_, index) => ({
      x: (stableHash(`snow-x-${index}`) % 10000) / 10000,
      y: (stableHash(`snow-y-${index}`) % 10000) / 10000,
      radius: 0.45 + (stableHash(`snow-r-${index}`) % 13) / 10,
      speed: 0.006 + (stableHash(`snow-s-${index}`) % 18) / 1000,
      sway: 4 + (stableHash(`snow-w-${index}`) % 15),
    }),
  );
}

function worldToScreen(node) {
  return {
    x: viewWidth / 2 + panX + node.x * zoom,
    y: viewHeight / 2 + panY + node.y * zoom,
  };
}

function screenToWorld(x, y) {
  return {
    x: (x - viewWidth / 2 - panX) / zoom,
    y: (y - viewHeight / 2 - panY) / zoom,
  };
}

function nodeScreenRadius(node) {
  const base = TYPE_META[node.type].radius;
  return Math.max(3, Math.min(base * Math.sqrt(zoom), base * 1.6));
}

function nodeAtPoint(x, y) {
  let winner = null;
  let winnerDistance = Number.POSITIVE_INFINITY;
  for (const node of visibleNodes) {
    const screen = worldToScreen(node);
    const distance = Math.hypot(screen.x - x, screen.y - y);
    const radius = nodeScreenRadius(node) + 6;
    if (distance <= radius && distance < winnerDistance) {
      winner = node;
      winnerDistance = distance;
    }
  }
  return winner;
}

function applyForces() {
  if (!motionEnabled || layoutEnergy < 0.002 || pointerState?.mode === "pan") {
    return;
  }

  const count = visibleNodes.length;
  for (let leftIndex = 0; leftIndex < count; leftIndex += 1) {
    const left = visibleNodes[leftIndex];
    for (let rightIndex = leftIndex + 1; rightIndex < count; rightIndex += 1) {
      const right = visibleNodes[rightIndex];
      let dx = right.x - left.x;
      let dy = right.y - left.y;
      let distanceSquared = dx * dx + dy * dy;
      if (distanceSquared < 1) {
        dx = 0.5;
        dy = 0.5;
        distanceSquared = 0.5;
      }
      if (distanceSquared > 42000) continue;
      const distance = Math.sqrt(distanceSquared);
      const strength =
        (left.type === "cluster" || right.type === "cluster" ? 180 : 82) /
        Math.max(distanceSquared, 80);
      const forceX = (dx / distance) * strength * layoutEnergy;
      const forceY = (dy / distance) * strength * layoutEnergy;
      left.vx -= forceX;
      left.vy -= forceY;
      right.vx += forceX;
      right.vy += forceY;
    }
  }

  for (const edge of visibleEdges) {
    const source = nodeById.get(edge.source);
    const target = nodeById.get(edge.target);
    if (!source || !target) continue;
    const dx = target.x - source.x;
    const dy = target.y - source.y;
    const distance = Math.max(Math.hypot(dx, dy), 1);
    const desired =
      edge.kind === "group" ? 178 : edge.kind === "uses" ? 128 : 84;
    const strength = (distance - desired) * 0.00024 * layoutEnergy;
    const forceX = (dx / distance) * strength;
    const forceY = (dy / distance) * strength;
    source.vx += forceX;
    source.vy += forceY;
    target.vx -= forceX;
    target.vy -= forceY;
  }

  for (const node of visibleNodes) {
    const targetStrength =
      node.type === "root" ? 0.075 : node.anchored ? 0.036 : 0.018;
    node.vx += (node.targetX - node.x) * targetStrength * layoutEnergy;
    node.vy += (node.targetY - node.y) * targetStrength * layoutEnergy;

    if (pointerState?.nodeId === node.id) continue;
    node.vx *= 0.87;
    node.vy *= 0.87;
    const speed = Math.hypot(node.vx, node.vy);
    if (speed > 7) {
      node.vx = (node.vx / speed) * 7;
      node.vy = (node.vy / speed) * 7;
    }
    node.x += node.vx;
    node.y += node.vy;
  }

  layoutEnergy *= 0.992;
}

function hexToRgba(hex, alpha) {
  const value = Number.parseInt(hex.slice(1), 16);
  const red = (value >> 16) & 255;
  const green = (value >> 8) & 255;
  const blue = value & 255;
  return `rgba(${red}, ${green}, ${blue}, ${alpha})`;
}

function drawSnow(timestamp) {
  const time = reducedMotion.matches ? 0 : timestamp / 1000;
  for (const particle of snowParticles) {
    const y = ((particle.y + time * particle.speed) % 1) * viewHeight;
    const x =
      particle.x * viewWidth +
      Math.sin(time * 0.35 + particle.y * Math.PI * 2) * particle.sway;
    canvasContext.beginPath();
    canvasContext.arc(x, y, particle.radius, 0, Math.PI * 2);
    canvasContext.fillStyle = `rgba(216, 239, 255, ${0.08 + particle.radius * 0.035})`;
    canvasContext.fill();
  }
}

function drawSnowflakeGuide() {
  const center = worldToScreen({ x: 0, y: 0 });
  const outerRadius =
    (Math.max(
      310,
      ...visibleNodes.map(
        (node) => Math.hypot(node.targetX, node.targetY) + 18,
      ),
    ) || 310) * zoom;

  for (let arm = 0; arm < 6; arm += 1) {
    const angle = -Math.PI / 2 + (arm / 6) * Math.PI * 2;
    const directionX = Math.cos(angle);
    const directionY = Math.sin(angle);
    const normalX = -directionY;
    const normalY = directionX;
    const endpointX = center.x + directionX * outerRadius;
    const endpointY = center.y + directionY * outerRadius;

    canvasContext.beginPath();
    canvasContext.moveTo(center.x, center.y);
    canvasContext.lineTo(endpointX, endpointY);
    for (const progress of [0.48, 0.67, 0.84]) {
      const branchX = center.x + directionX * outerRadius * progress;
      const branchY = center.y + directionY * outerRadius * progress;
      const branchLength = (11 + progress * 20) * Math.sqrt(zoom);
      canvasContext.moveTo(branchX, branchY);
      canvasContext.lineTo(
        branchX - directionX * branchLength + normalX * branchLength,
        branchY - directionY * branchLength + normalY * branchLength,
      );
      canvasContext.moveTo(branchX, branchY);
      canvasContext.lineTo(
        branchX - directionX * branchLength - normalX * branchLength,
        branchY - directionY * branchLength - normalY * branchLength,
      );
    }
    canvasContext.strokeStyle = "rgba(126, 186, 228, 0.065)";
    canvasContext.lineWidth = 1;
    canvasContext.stroke();
  }
}

function drawEdge(edge, timestamp) {
  const source = nodeById.get(edge.source);
  const target = nodeById.get(edge.target);
  if (!source || !target) return;
  const from = worldToScreen(source);
  const to = worldToScreen(target);
  const emphasis = edgeEmphasis(edge);
  const active = edge.active || source.active || target.active;

  canvasContext.beginPath();
  canvasContext.moveTo(from.x, from.y);
  canvasContext.lineTo(to.x, to.y);
  canvasContext.strokeStyle = active
    ? `rgba(234, 248, 255, ${emphasis})`
    : `rgba(126, 186, 228, ${emphasis})`;
  canvasContext.lineWidth = active ? 1.35 : 0.8;
  canvasContext.stroke();

  if (active && !reducedMotion.matches) {
    const progress =
      (((timestamp / 1700 + (stableHash(edge.id) % 100) / 100) % 1) + 1) % 1;
    const pulseX = from.x + (to.x - from.x) * progress;
    const pulseY = from.y + (to.y - from.y) * progress;
    canvasContext.save();
    canvasContext.shadowBlur = 10;
    canvasContext.shadowColor = "#7ebae4";
    canvasContext.beginPath();
    canvasContext.arc(pulseX, pulseY, 2, 0, Math.PI * 2);
    canvasContext.fillStyle = "rgba(234, 248, 255, 0.92)";
    canvasContext.fill();
    canvasContext.restore();
  }
}

function shouldDrawLabel(node) {
  if (!showLabels) return node.id === selectedId || node.id === hoveredId;
  if (
    node.type === "root" ||
    node.type === "cluster" ||
    node.type === "host" ||
    node.type === "rice"
  ) {
    return true;
  }
  return (
    zoom > 1.12 ||
    node.id === selectedId ||
    node.id === hoveredId ||
    searchMatches.has(node.id)
  );
}

function drawLabel(node, screen, radius, emphasis) {
  if (!shouldDrawLabel(node)) return;
  const fontSize = node.type === "root" ? 12 : node.type === "cluster" ? 10 : 9;
  canvasContext.font = `${node.type === "root" ? 650 : 500} ${fontSize}px "SFMono-Regular", "Cascadia Code", monospace`;
  canvasContext.textAlign = "center";
  canvasContext.textBaseline = "top";
  canvasContext.lineJoin = "round";
  canvasContext.lineWidth = 3;
  canvasContext.strokeStyle = `rgba(7, 16, 27, ${0.86 * emphasis})`;
  canvasContext.fillStyle = `rgba(237, 248, 255, ${Math.max(0.28, emphasis)})`;
  const labelY = screen.y + radius + 5;
  canvasContext.strokeText(node.label, screen.x, labelY);
  canvasContext.fillText(node.label, screen.x, labelY);
}

function drawNode(node, timestamp) {
  const screen = worldToScreen(node);
  const radius = nodeScreenRadius(node);
  const meta = TYPE_META[node.type];
  const emphasis = nodeEmphasis(node);
  const selected = node.id === selectedId;
  const hovered = node.id === hoveredId;

  if (node.active && !reducedMotion.matches) {
    const pulse = ((timestamp / 1100) % 1) * 14;
    canvasContext.beginPath();
    canvasContext.arc(screen.x, screen.y, radius + pulse, 0, Math.PI * 2);
    canvasContext.strokeStyle = `rgba(234, 248, 255, ${0.34 * (1 - pulse / 14)})`;
    canvasContext.lineWidth = 1;
    canvasContext.stroke();
  }

  if (selected || hovered) {
    canvasContext.beginPath();
    canvasContext.arc(
      screen.x,
      screen.y,
      radius + (selected ? 6 : 4),
      0,
      Math.PI * 2,
    );
    canvasContext.strokeStyle = selected
      ? "rgba(126, 186, 228, 0.95)"
      : "rgba(237, 248, 255, 0.58)";
    canvasContext.lineWidth = selected ? 1.6 : 1;
    canvasContext.stroke();
  }

  canvasContext.save();
  canvasContext.shadowBlur = node.active ? 18 : node.type === "root" ? 13 : 7;
  canvasContext.shadowColor = node.active ? "#edf8ff" : meta.color;
  canvasContext.beginPath();
  if (node.type === "root" || node.type === "cluster") {
    for (let side = 0; side < 6; side += 1) {
      const angle = -Math.PI / 2 + (side / 6) * Math.PI * 2;
      const pointX = screen.x + Math.cos(angle) * radius;
      const pointY = screen.y + Math.sin(angle) * radius;
      if (side === 0) canvasContext.moveTo(pointX, pointY);
      else canvasContext.lineTo(pointX, pointY);
    }
    canvasContext.closePath();
  } else {
    canvasContext.arc(screen.x, screen.y, radius, 0, Math.PI * 2);
  }
  canvasContext.fillStyle = node.active
    ? hexToRgba("#edf8ff", emphasis)
    : hexToRgba(meta.color, emphasis);
  canvasContext.fill();
  if (node.type === "root" || node.type === "cluster") {
    canvasContext.strokeStyle = hexToRgba(
      meta.color,
      Math.min(1, emphasis + 0.2),
    );
    canvasContext.lineWidth = 1;
    canvasContext.stroke();
  }
  canvasContext.restore();

  if (node.type === "root") {
    canvasContext.save();
    canvasContext.translate(screen.x, screen.y);
    canvasContext.strokeStyle = "rgba(7, 16, 27, 0.9)";
    canvasContext.lineWidth = 1;
    for (let arm = 0; arm < 6; arm += 1) {
      const angle = -Math.PI / 2 + (arm / 6) * Math.PI * 2;
      canvasContext.beginPath();
      canvasContext.moveTo(0, 0);
      canvasContext.lineTo(
        Math.cos(angle) * radius * 0.72,
        Math.sin(angle) * radius * 0.72,
      );
      canvasContext.stroke();
    }
    canvasContext.restore();
  }

  drawLabel(node, screen, radius, emphasis);
}

function draw(timestamp) {
  canvasContext.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
  canvasContext.clearRect(0, 0, viewWidth, viewHeight);

  applyForces();
  drawSnow(timestamp);
  drawSnowflakeGuide();
  for (const edge of visibleEdges) drawEdge(edge, timestamp);
  for (const node of visibleNodes) drawNode(node, timestamp);

  window.requestAnimationFrame(draw);
}

function updateStats() {
  elements.visibleCount.textContent = `${visibleNodes.length} nodes`;
  elements.graphStats.textContent = `${visibleNodes.length} nodes · ${visibleEdges.length} links`;
}

function detailEntries(node) {
  return Object.entries(node.details).filter(
    ([, value]) => value !== null && value !== undefined && value !== "",
  );
}

function updateInspector() {
  const node = nodeById.get(selectedId);
  if (!node || !visibleNodes.includes(node)) {
    elements.inspector.innerHTML = `
      <div class="inspector-empty">
        <span>SELECT A NODE</span>
        <strong>グラフから構成要素を選択</strong>
        <p>接続先と設定元をここで確認できます。</p>
      </div>
    `;
    return;
  }

  const connections = [...connectedIds(node.id)]
    .map((id) => nodeById.get(id))
    .filter(Boolean)
    .sort((left, right) => left.label.localeCompare(right.label));
  const meta = TYPE_META[node.type];

  elements.inspector.innerHTML = `
    <div class="inspector-header" style="--node-color: ${meta.color}">
      <span class="inspector-kicker">${escapeHtml(TYPE_LABELS[node.type])}</span>
      <div class="inspector-title-row">
        <i class="inspector-type-dot"></i>
        <h2>${escapeHtml(node.label)}</h2>
      </div>
      ${
        node.path
          ? `<p class="inspector-path">${escapeHtml(node.path)}</p>`
          : ""
      }
      ${node.active ? '<span class="active-badge">active now</span>' : ""}
    </div>
    ${
      detailEntries(node).length
        ? `<div class="detail-grid">
            ${detailEntries(node)
              .map(
                ([label, value]) => `
                  <div class="detail-item">
                    <span>${escapeHtml(label)}</span>
                    <strong>${escapeHtml(value)}</strong>
                  </div>
                `,
              )
              .join("")}
          </div>`
        : ""
    }
    <section class="inspector-section">
      <span>Connections · ${connections.length}</span>
      <div class="connection-list">
        ${
          connections.length
            ? connections
                .slice(0, 18)
                .map(
                  (connection) => `
                    <button
                      type="button"
                      class="connection-button"
                      data-node-id="${escapeHtml(connection.id)}"
                      style="--connection-color: ${TYPE_META[connection.type].color}"
                    >
                      <i></i>
                      <span>${escapeHtml(connection.label)}</span>
                      <small>${escapeHtml(TYPE_LABELS[connection.type])}</small>
                    </button>
                  `,
                )
                .join("")
            : '<div class="inspector-empty"><p>表示中の接続はありません。</p></div>'
        }
      </div>
    </section>
    <div class="inspector-actions">
      <button id="center-node" type="button">中央へ</button>
      <button
        id="focus-neighbors"
        type="button"
        aria-pressed="${focusNeighbors}"
      >接続だけ見る</button>
    </div>
  `;

  for (const button of elements.inspector.querySelectorAll(
    ".connection-button",
  )) {
    button.addEventListener("click", () =>
      selectNode(button.dataset.nodeId, true),
    );
  }
  elements.inspector
    .querySelector("#center-node")
    ?.addEventListener("click", () => centerOnNode(node, true));
  elements.inspector
    .querySelector("#focus-neighbors")
    ?.addEventListener("click", () => {
      focusNeighbors = !focusNeighbors;
      updateInspector();
    });
}

function selectNode(id, center = false) {
  if (!nodeById.has(id)) return;
  selectedId = id;
  focusNeighbors = false;
  updateInspector();
  if (center) centerOnNode(nodeById.get(id), true);
}

function setZoom(nextZoom, pivotX = viewWidth / 2, pivotY = viewHeight / 2) {
  const worldBefore = screenToWorld(pivotX, pivotY);
  zoom = Math.max(0.35, Math.min(2.8, nextZoom));
  panX = pivotX - viewWidth / 2 - worldBefore.x * zoom;
  panY = pivotY - viewHeight / 2 - worldBefore.y * zoom;
  elements.zoomLabel.textContent = `${Math.round(zoom * 100)}%`;
}

function centerOnNode(node, animated = false) {
  if (!node) return;
  const nextPanX = -node.x * zoom;
  const nextPanY = -node.y * zoom;
  if (!animated || reducedMotion.matches) {
    panX = nextPanX;
    panY = nextPanY;
    return;
  }
  const startX = panX;
  const startY = panY;
  const started = performance.now();
  const duration = 260;
  const step = (now) => {
    const progress = Math.min(1, (now - started) / duration);
    const eased = 1 - (1 - progress) ** 3;
    panX = startX + (nextPanX - startX) * eased;
    panY = startY + (nextPanY - startY) * eased;
    if (progress < 1) window.requestAnimationFrame(step);
  };
  window.requestAnimationFrame(step);
}

function fitGraph() {
  if (!visibleNodes.length) return;
  const xs = visibleNodes.map((node) => node.targetX);
  const ys = visibleNodes.map((node) => node.targetY);
  const minX = Math.min(...xs);
  const maxX = Math.max(...xs);
  const minY = Math.min(...ys);
  const maxY = Math.max(...ys);
  const paddingX = viewWidth < 900 ? 50 : 330;
  const paddingY = 120;
  const usableWidth = Math.max(180, viewWidth - paddingX * 2);
  const usableHeight = Math.max(180, viewHeight - paddingY * 2);
  const nextZoom = Math.min(
    1.35,
    usableWidth / Math.max(maxX - minX, 180),
    usableHeight / Math.max(maxY - minY, 180),
  );
  zoom = Math.max(0.42, nextZoom);
  panX = -((minX + maxX) / 2) * zoom;
  panY = -((minY + maxY) / 2) * zoom;
  elements.zoomLabel.textContent = `${Math.round(zoom * 100)}%`;
}

function pointerCoordinates(event) {
  const rect = elements.canvas.getBoundingClientRect();
  return { x: event.clientX - rect.left, y: event.clientY - rect.top };
}

elements.canvas.addEventListener("pointerdown", (event) => {
  const point = pointerCoordinates(event);
  const node = nodeAtPoint(point.x, point.y);
  elements.canvas.setPointerCapture(event.pointerId);
  pointerState = {
    pointerId: event.pointerId,
    mode: node ? "node" : "pan",
    nodeId: node?.id || null,
    startX: point.x,
    startY: point.y,
    lastX: point.x,
    lastY: point.y,
    moved: false,
  };
  elements.canvas.classList.add("is-dragging");
});

elements.canvas.addEventListener("pointermove", (event) => {
  const point = pointerCoordinates(event);
  lastPointer = point;

  if (!pointerState) {
    const node = nodeAtPoint(point.x, point.y);
    hoveredId = node?.id || null;
    elements.canvas.classList.toggle("is-node-hover", Boolean(node));
    return;
  }

  const deltaX = point.x - pointerState.lastX;
  const deltaY = point.y - pointerState.lastY;
  if (
    Math.hypot(point.x - pointerState.startX, point.y - pointerState.startY) > 3
  ) {
    pointerState.moved = true;
  }

  if (pointerState.mode === "pan") {
    panX += deltaX;
    panY += deltaY;
  } else {
    const node = nodeById.get(pointerState.nodeId);
    if (node) {
      const world = screenToWorld(point.x, point.y);
      node.x = world.x;
      node.y = world.y;
      node.vx = 0;
      node.vy = 0;
      layoutEnergy = Math.max(layoutEnergy, 0.16);
    }
  }

  pointerState.lastX = point.x;
  pointerState.lastY = point.y;
});

function endPointer(event) {
  if (!pointerState || pointerState.pointerId !== event.pointerId) return;
  if (!pointerState.moved && pointerState.nodeId) {
    selectNode(pointerState.nodeId);
  } else if (!pointerState.moved && pointerState.mode === "pan") {
    selectedId = null;
    focusNeighbors = false;
    updateInspector();
  }
  pointerState = null;
  elements.canvas.classList.remove("is-dragging");
}

elements.canvas.addEventListener("pointerup", endPointer);
elements.canvas.addEventListener("pointercancel", endPointer);
elements.canvas.addEventListener("pointerleave", () => {
  if (!pointerState) {
    hoveredId = null;
    elements.canvas.classList.remove("is-node-hover");
  }
});

elements.canvas.addEventListener(
  "wheel",
  (event) => {
    event.preventDefault();
    const point = pointerCoordinates(event);
    const factor = Math.exp(-event.deltaY * 0.0012);
    setZoom(zoom * factor, point.x, point.y);
  },
  { passive: false },
);

elements.search.addEventListener("input", (event) => {
  searchQuery = event.target.value.trim().toLowerCase();
  updateSearchMatches();
});

elements.search.addEventListener("keydown", (event) => {
  if (event.key === "Enter" && searchMatches.size) {
    const id = [...searchMatches][0];
    selectNode(id, true);
  }
  if (event.key === "Escape") {
    elements.search.value = "";
    searchQuery = "";
    updateSearchMatches();
    elements.canvas.focus();
  }
});

window.addEventListener("keydown", (event) => {
  if (
    event.key === "/" &&
    document.activeElement !== elements.search &&
    !event.metaKey &&
    !event.ctrlKey
  ) {
    event.preventDefault();
    elements.search.focus();
  }
  if (event.key === "Escape" && document.activeElement !== elements.search) {
    selectedId = null;
    focusNeighbors = false;
    updateInspector();
  }
});

elements.zoomIn.addEventListener("click", () => setZoom(zoom * 1.2));
elements.zoomOut.addEventListener("click", () => setZoom(zoom / 1.2));
elements.fitGraph.addEventListener("click", fitGraph);
elements.toggleLabels.addEventListener("click", () => {
  showLabels = !showLabels;
  elements.toggleLabels.setAttribute("aria-pressed", String(showLabels));
});
elements.toggleMotion.addEventListener("click", () => {
  motionEnabled = !motionEnabled;
  if (motionEnabled) {
    layoutEnergy = 0.5;
  } else {
    assignSnowflakeTargets();
  }
  elements.toggleMotion.setAttribute("aria-pressed", String(motionEnabled));
});

reducedMotion.addEventListener("change", (event) => {
  if (event.matches) {
    motionEnabled = false;
    assignSnowflakeTargets();
    elements.toggleMotion.setAttribute("aria-pressed", "false");
  }
});

new ResizeObserver(() => {
  resizeCanvas();
  if (sourceState && !panX && !panY) fitGraph();
}).observe(elements.graphShell);

async function loadState() {
  try {
    const response = await fetch("/api/state", { cache: "no-store" });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const nextState = await response.json();
    const { generatedAt: _generatedAt, ...stableState } = nextState;
    const nextFingerprint = JSON.stringify(stableState);
    const firstLoad = !sourceState;
    const changed = stateFingerprint && stateFingerprint !== nextFingerprint;

    sourceState = nextState;
    stateFingerprint = nextFingerprint;
    elements.error.hidden = true;
    elements.targetChip.textContent =
      nextState.runtime.target || nextState.runtime.host;
    const git = nextState.repository.git;
    elements.gitChip.textContent = `${git.branch} · ${git.commit.hash}${
      git.dirty ? ` · ${git.changes.length} changed` : ""
    }`;
    elements.syncStatus.classList.add("is-live");
    elements.syncStatus.innerHTML = `<i></i> ${new Date(
      nextState.generatedAt,
    ).toLocaleTimeString("ja-JP")}`;

    if (changed) {
      elements.syncStatus.classList.remove("is-updating");
      requestAnimationFrame(() =>
        elements.syncStatus.classList.add("is-updating"),
      );
    }

    if (firstLoad || changed) {
      buildGraph(nextState);
      if (firstLoad) {
        selectedId = `host:${nextState.runtime.host}`;
        updateInspector();
        window.setTimeout(fitGraph, 160);
      }
    }
  } catch (error) {
    elements.error.hidden = false;
    elements.error.textContent = `構成を読み込めません: ${error.message}`;
    elements.syncStatus.classList.remove("is-live");
    elements.syncStatus.innerHTML = "<i></i> offline";
  }
}

resizeCanvas();
renderFilters();
window.requestAnimationFrame(draw);
await loadState();
window.setInterval(loadState, 3000);
