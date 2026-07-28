import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { createServer } from "node:http";
import { dirname, extname, join, normalize, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(
  process.env.DOTFILES_REPO_ROOT || join(scriptDirectory, "../.."),
);
const publicRoot = join(scriptDirectory, "public");
const port = Number.parseInt(process.env.DOTFILES_EXPLORER_PORT || "43110", 10);
const host = "127.0.0.1";

const visibleEntries = [
  "flake.nix",
  "flake.lock",
  "README.md",
  "hosts",
  "modules",
  "rices",
  "home",
  "lib",
  "packages",
  "config",
  "scripts",
  "tools",
];
const ignoredNames = new Set([
  ".DS_Store",
  ".direnv",
  ".env",
  ".git",
  "keys",
  "legacy",
  "node_modules",
  "result",
  "secrets",
]);
const mimeTypes = {
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
};

function readText(path) {
  try {
    return readFileSync(path, "utf8");
  } catch {
    return "";
  }
}

function run(command, args = []) {
  try {
    return execFileSync(command, args, {
      cwd: repositoryRoot,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
      timeout: 1500,
    }).trim();
  } catch {
    return "";
  }
}

function quotedValue(source, key) {
  const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return (
    source.match(new RegExp(`${escapedKey}\\s*=\\s*"([^"]+)"`))?.[1] || null
  );
}

function quotedList(source, key) {
  const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const block = source.match(
    new RegExp(`${escapedKey}\\s*=\\s*\\[([\\s\\S]*?)\\];`),
  )?.[1];
  if (!block) return [];
  return [...block.matchAll(/"([^"]+)"/g)].map((match) => match[1]);
}

function identifierList(source, key) {
  const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const block = source.match(
    new RegExp(
      `${escapedKey}\\s*=\\s*(?:with\\s+pkgs;\\s*)?\\[([\\s\\S]*?)\\];`,
    ),
  )?.[1];
  if (!block) return [];

  return block
    .split("\n")
    .map((line) => line.replace(/#.*$/, "").trim())
    .map((line) => line.match(/^([A-Za-z0-9_.@+-]+)$/)?.[1])
    .filter(Boolean);
}

function listNixFiles(directory) {
  if (!existsSync(directory)) return [];
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    if (ignoredNames.has(entry.name)) return [];
    const path = join(directory, entry.name);
    if (entry.isDirectory()) return listNixFiles(path);
    return entry.isFile() && entry.name.endsWith(".nix") ? [path] : [];
  });
}

function collectHosts() {
  const hostsRoot = join(repositoryRoot, "hosts");
  if (!existsSync(hostsRoot)) return [];

  return readdirSync(hostsRoot, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => {
      const source = readText(join(hostsRoot, entry.name, "default.nix"));
      const enabled = [
        ...source.matchAll(/myconfig\.([\w.-]+)\.enable\s*=\s*true;/g),
      ].map((match) => match[1]);
      const disabled = [
        ...source.matchAll(/myconfig\.([\w.-]+)\.enable\s*=\s*false;/g),
      ].map((match) => match[1]);

      return {
        name: quotedValue(source, "name") || entry.name,
        type: quotedValue(source, "type") || "machine",
        system: quotedValue(source, "system") || "unknown",
        rice: quotedValue(source, "rice"),
        features: quotedList(source, "features"),
        enabled,
        disabled,
      };
    })
    .sort((left, right) => left.name.localeCompare(right.name));
}

function collectRices() {
  const riceRoot = join(repositoryRoot, "rices");
  return listNixFiles(riceRoot)
    .map((path) => {
      const source = readText(path);
      const toggles = [
        ...source.matchAll(/^\s+([\w-]+)\.enable\s*=\s*(true|false);/gm),
      ].map((match) => ({
        name: match[1],
        enabled: match[2] === "true",
      }));
      return {
        name:
          quotedValue(source, "name") ||
          path.split("/").at(-1).replace(".nix", ""),
        wallpaper: quotedValue(source, "wallpaper"),
        toggles,
      };
    })
    .sort((left, right) => left.name.localeCompare(right.name));
}

function moduleScope(source) {
  const scopes = [];
  if (source.includes("darwin.")) scopes.push("Darwin");
  if (source.includes("nixos.")) scopes.push("NixOS");
  if (source.includes("home.")) scopes.push("Home");
  return scopes.length ? scopes : ["Shared"];
}

function collectModules() {
  const modulesRoot = join(repositoryRoot, "modules");
  return listNixFiles(modulesRoot)
    .map((path) => {
      const source = readText(path);
      return {
        name:
          quotedValue(source, "name") ||
          path.slice(modulesRoot.length + 1).replace(/\.nix$/, ""),
        path: path.slice(repositoryRoot.length + 1),
        scope: moduleScope(source),
        configurable:
          source.includes("singleEnableOption") || source.includes("options ="),
      };
    })
    .sort((left, right) => left.name.localeCompare(right.name));
}

function collectFlakeInputs() {
  const source = readText(join(repositoryRoot, "flake.nix"));
  return [...source.matchAll(/^\s{4}([\w-]+)\.url\s*=\s*"([^"]+)";/gm)].map(
    (match) => ({
      name: match[1],
      source: match[2],
    }),
  );
}

function collectHomebrew() {
  const source = readText(join(repositoryRoot, "modules/darwin-homebrew.nix"));
  const desktopBlock =
    source.match(
      /\+\+\s+lib\.optionals\s+host\.fullDesktopFeatured\s+\[([\s\S]*?)\];/,
    )?.[1] || "";
  const masBlock = source.match(/masApps\s*=\s*\{([\s\S]*?)\};/)?.[1] || "";

  return {
    brews: quotedList(source, "brews"),
    casks: quotedList(source, "casks"),
    desktopCasks: [...desktopBlock.matchAll(/"([^"]+)"/g)].map(
      (match) => match[1],
    ),
    masApps: [...masBlock.matchAll(/^\s*"?([^"=]+?)"?\s*=\s*\d+;/gm)].map(
      (match) => match[1].trim(),
    ),
  };
}

function collectNixPackages() {
  const source = readText(join(repositoryRoot, "lib/home-packages.nix"));
  const groups = [
    "commonPackages",
    "linuxCommonPackages",
    "linuxBasePackages",
    "nonServerPackages",
    "linuxNonServerPackages",
    "linuxDesktopPackages",
    "linuxFullDesktopPackages",
    "darwinDesktopPackages",
    "darwinCliPackages",
    "linuxServerPackages",
  ];
  return groups.map((name) => ({
    name,
    packages: identifierList(source, name),
  }));
}

function collectCustomPackages() {
  const packagesRoot = join(repositoryRoot, "packages");
  return listNixFiles(packagesRoot)
    .map((path) =>
      path
        .split("/")
        .at(-1)
        .replace(/\.nix$/, ""),
    )
    .sort();
}

function processRunning(name) {
  return Boolean(run("pgrep", ["-x", name]));
}

function collectRuntime(hosts, rices) {
  let rice = null;
  if (process.platform === "darwin") {
    if (processRunning("rift") || processRunning("Rift")) rice = "rift";
    else if (processRunning("AeroSpace")) rice = "aerospace";
    else rice = "mac";
  } else if (
    process.env.HYPRLAND_INSTANCE_SIGNATURE ||
    processRunning("Hyprland")
  ) {
    rice = "persona";
  } else {
    rice = hosts.find((item) => item.system.endsWith("-linux"))?.rice || null;
  }

  const hostName = run("hostname", ["-s"]) || "local";
  const configuredHost =
    hosts.find((item) => item.name === hostName) ||
    hosts.find((item) =>
      process.platform === "darwin"
        ? item.system.endsWith("-darwin")
        : item.system.endsWith("-linux"),
    );

  return {
    os: process.platform,
    arch: process.arch,
    hostname: hostName,
    host: configuredHost?.name || hostName,
    rice,
    target:
      configuredHost && rice
        ? `${configuredHost.name}-${rice}`
        : configuredHost?.name,
    riceKnown: rices.some((item) => item.name === rice),
  };
}

function treeNode(path, relativePath, budget) {
  if (budget.count >= budget.max) return null;
  const name = relativePath.split("/").at(-1);
  if (ignoredNames.has(name)) return null;

  let stats;
  try {
    stats = statSync(path);
  } catch {
    return null;
  }

  budget.count += 1;
  if (!stats.isDirectory()) {
    return {
      name,
      path: relativePath,
      type: "file",
      extension: extname(name).replace(".", "") || "file",
    };
  }

  const children = readdirSync(path, { withFileTypes: true })
    .filter((entry) => !ignoredNames.has(entry.name))
    .sort((left, right) => {
      if (left.isDirectory() !== right.isDirectory()) {
        return left.isDirectory() ? -1 : 1;
      }
      return left.name.localeCompare(right.name);
    })
    .map((entry) =>
      treeNode(join(path, entry.name), `${relativePath}/${entry.name}`, budget),
    )
    .filter(Boolean);

  return {
    name,
    path: relativePath,
    type: "directory",
    children,
  };
}

function collectTree() {
  const budget = { count: 0, max: 900 };
  return visibleEntries
    .filter((entry) => existsSync(join(repositoryRoot, entry)))
    .map((entry) => treeNode(join(repositoryRoot, entry), entry, budget))
    .filter(Boolean);
}

function countTree(nodes) {
  return nodes.reduce(
    (total, node) => total + 1 + (node.children ? countTree(node.children) : 0),
    0,
  );
}

function collectGit() {
  const changes = run("git", ["status", "--short"])
    .split("\n")
    .filter(Boolean)
    .map((line) => ({
      status: line.slice(0, 2).trim() || "changed",
      path: line.slice(3),
    }));
  const commit = run("git", ["log", "-1", "--format=%h%x00%s%x00%cr"]).split(
    "\0",
  );

  return {
    branch: run("git", ["branch", "--show-current"]) || "detached",
    dirty: changes.length > 0,
    changes,
    commit: {
      hash: commit[0] || "unknown",
      subject: commit[1] || "No commits",
      age: commit[2] || "",
    },
  };
}

function collectState() {
  const hosts = collectHosts();
  const rices = collectRices();
  const modules = collectModules();
  const tree = collectTree();
  const nixFiles = listNixFiles(repositoryRoot).length;

  return {
    generatedAt: new Date().toISOString(),
    repository: {
      name: ".dotfiles",
      description: "denix control plane for NixOS and nix-darwin",
      filesVisible: countTree(tree),
      nixFiles,
      git: collectGit(),
    },
    runtime: collectRuntime(hosts, rices),
    hosts,
    rices,
    modules,
    inventory: {
      flakeInputs: collectFlakeInputs(),
      homebrew: collectHomebrew(),
      nixGroups: collectNixPackages(),
      customPackages: collectCustomPackages(),
    },
    tree,
  };
}

function sendJson(response, status, value) {
  response.writeHead(status, {
    "cache-control": "no-store",
    "content-type": "application/json; charset=utf-8",
  });
  response.end(JSON.stringify(value));
}

function sendStatic(response, pathname) {
  const requested = pathname === "/" ? "/index.html" : pathname;
  const sanitized = normalize(requested).replace(/^(\.\.[/\\])+/, "");
  const path = resolve(publicRoot, `.${sanitized}`);

  if (!path.startsWith(publicRoot) || !existsSync(path)) {
    sendJson(response, 404, { error: "Not found" });
    return;
  }

  response.writeHead(200, {
    "cache-control": "no-store",
    "content-type": mimeTypes[extname(path)] || "application/octet-stream",
  });
  response.end(readFileSync(path));
}

const server = createServer((request, response) => {
  const url = new URL(request.url || "/", `http://${host}:${port}`);
  if (url.pathname === "/api/health") {
    sendJson(response, 200, { ok: true, repositoryRoot });
    return;
  }
  if (url.pathname === "/api/state") {
    try {
      sendJson(response, 200, collectState());
    } catch (error) {
      sendJson(response, 500, {
        error: "Could not read the dotfiles state",
        detail: error instanceof Error ? error.message : String(error),
      });
    }
    return;
  }
  sendStatic(response, url.pathname);
});

server.on("error", (error) => {
  console.error(`dotfiles explorer: ${error.message}`);
  process.exitCode = 1;
});

server.listen(port, host, () => {
  console.log(`dotfiles explorer listening on http://${host}:${port}`);
});

for (const signal of ["SIGINT", "SIGTERM", "SIGHUP"]) {
  process.on(signal, () => server.close(() => process.exit(0)));
}
