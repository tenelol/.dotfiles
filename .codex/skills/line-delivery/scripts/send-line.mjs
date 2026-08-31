#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import { existsSync } from "node:fs";
import { homedir, userInfo } from "node:os";
import { join } from "node:path";

const LINE_PUSH_URL = "https://api.line.me/v2/bot/message/push";
const LINE_BOT_INFO_URL = "https://api.line.me/v2/bot/info";
const TOKEN_SERVICE = "dev.tenelol.codex.line-bot.channel-access-token";
const RECIPIENT_SERVICE = "dev.tenelol.codex.line-bot.destination-user-id";
const CHUNK_SIZE = 4700;
const MESSAGES_PER_REQUEST = 5;
const REQUEST_TIMEOUT_MS = 20_000;
const MAX_ATTEMPTS = 2;
const KEYCHAIN_READ_ATTEMPTS = 2;
const KEYCHAIN_RETRY_MS = 250;
const graphemeSegmenter = new Intl.Segmenter("ja", { granularity: "grapheme" });
const keychainAccount =
  process.env.LINE_KEYCHAIN_ACCOUNT?.trim() ||
  process.env.USER?.trim() ||
  process.env.LOGNAME?.trim() ||
  userInfo().username;
const keychainPath =
  process.env.LINE_KEYCHAIN_PATH?.trim() ||
  join(homedir(), "Library", "Keychains", "login.keychain-db");

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

function parseArgs(argv) {
  const options = { check: false, dryRun: false, title: "" };

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--check") {
      options.check = true;
    } else if (argument === "--dry-run") {
      options.dryRun = true;
    } else if (argument === "--title") {
      index += 1;
      if (index >= argv.length) fail("--title には値が必要です");
      options.title = argv[index].trim();
    } else {
      fail(`未対応の引数です: ${argument}`);
    }
  }

  if (options.check && options.dryRun) {
    fail("--check と --dry-run は同時に指定できません");
  }
  return options;
}

function pause(milliseconds) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, milliseconds);
}

function keychainQueries(service) {
  const scopedKeychain = existsSync(keychainPath) ? [keychainPath] : [];
  const queries = [];

  if (keychainAccount) {
    queries.push([
      "find-generic-password",
      "-a",
      keychainAccount,
      "-s",
      service,
      "-w",
      ...scopedKeychain,
    ]);
  }
  queries.push([
    "find-generic-password",
    "-s",
    service,
    "-w",
    ...scopedKeychain,
  ]);

  return queries;
}

function keychainItemExists(service) {
  return keychainQueries(service).some((args) => {
    try {
      execFileSync(
        "/usr/bin/security",
        args.filter((argument) => argument !== "-w"),
        { stdio: ["ignore", "ignore", "ignore"] },
      );
      return true;
    } catch {
      return false;
    }
  });
}

function readKeychain(service, label) {
  const failures = [];

  for (let attempt = 1; attempt <= KEYCHAIN_READ_ATTEMPTS; attempt += 1) {
    for (const args of keychainQueries(service)) {
      try {
        const value = execFileSync("/usr/bin/security", args, {
          encoding: "utf8",
          stdio: ["ignore", "pipe", "pipe"],
        }).trim();
        if (value) return value;
      } catch (error) {
        failures.push(String(error?.stderr || error?.message || ""));
      }
    }
    if (attempt < KEYCHAIN_READ_ATTEMPTS) pause(KEYCHAIN_RETRY_MS);
  }

  if (
    keychainItemExists(service) ||
    failures.some((message) =>
      /user interaction is not allowed|keychain.*locked|auth.?denied|integrity|authfailed/i.test(
        message,
      ),
    )
  ) {
    fail(
      `${label}はmacOS Keychainに保存済みですが、Macのロック中は読み取れません`,
    );
  }
  fail(`${label}が環境変数またはmacOS Keychainに設定されていません`);
}

function credentials() {
  const token =
    process.env.LINE_CHANNEL_ACCESS_TOKEN?.trim() ||
    readKeychain(TOKEN_SERVICE, "LINEチャネルアクセストークン");
  const recipient =
    process.env.LINE_DESTINATION_USER_ID?.trim() ||
    readKeychain(RECIPIENT_SERVICE, "LINE送信先ユーザーID");

  if (!token) fail("LINEチャネルアクセストークンが空です");
  if (!/^U[0-9a-f]{32}$/i.test(recipient)) {
    fail("LINE送信先ユーザーIDの形式が正しくありません");
  }
  return { recipient, token };
}

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  return Buffer.concat(chunks).toString("utf8").trim();
}

function splitText(text) {
  const characters = Array.from(
    graphemeSegmenter.segment(text),
    ({ segment }) => segment,
  );
  const rawChunks = [];
  for (let offset = 0; offset < characters.length; offset += CHUNK_SIZE) {
    rawChunks.push(characters.slice(offset, offset + CHUNK_SIZE).join(""));
  }
  if (rawChunks.length <= 1) return rawChunks;
  return rawChunks.map(
    (chunk, index) => `[${index + 1}/${rawChunks.length}]\n${chunk}`,
  );
}

function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function retryDelay(response) {
  const retryAfter = Number(response?.headers.get("retry-after"));
  if (Number.isFinite(retryAfter) && retryAfter > 0) {
    return Math.min(retryAfter * 1000, 5000);
  }
  return 1000;
}

function isRetryableStatus(status) {
  return status === 429 || status >= 500;
}

function isAcceptedRetry(response) {
  return (
    response.status === 409 &&
    Boolean(response.headers.get("x-line-accepted-request-id"))
  );
}

async function requestWithRetry(url, options) {
  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt += 1) {
    try {
      const response = await fetch(url, {
        ...options,
        signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
      });
      if (response.ok || isAcceptedRetry(response)) return response;
      if (attempt < MAX_ATTEMPTS && isRetryableStatus(response.status)) {
        await sleep(retryDelay(response));
        continue;
      }
      fail(`LINE APIエラー (${response.status})`);
    } catch {
      if (attempt < MAX_ATTEMPTS) {
        await sleep(1000);
        continue;
      }
      fail("LINE APIへの接続に失敗しました");
    }
  }
  fail("LINE APIへの接続に失敗しました");
}

async function checkConfiguration(token) {
  await requestWithRetry(LINE_BOT_INFO_URL, {
    headers: { Authorization: `Bearer ${token}` },
  });
  process.stdout.write("LINE設定確認OK\n");
}

async function sendMessages(token, recipient, messages) {
  for (let offset = 0; offset < messages.length; offset += MESSAGES_PER_REQUEST) {
    const batch = messages.slice(offset, offset + MESSAGES_PER_REQUEST);
    const retryKey = randomUUID();
    await requestWithRetry(LINE_PUSH_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
        "X-Line-Retry-Key": retryKey,
      },
      body: JSON.stringify({
        to: recipient,
        messages: batch.map((text) => ({ type: "text", text })),
        notificationDisabled: false,
      }),
    });
  }
}

const options = parseArgs(process.argv.slice(2));
const { recipient, token } = options.dryRun
  ? { recipient: "", token: "" }
  : credentials();

if (options.check) {
  await checkConfiguration(token);
  process.exit(0);
}

const report = await readStdin();
if (!report) fail("送信する本文が空です");

const text = options.title ? `${options.title}\n\n${report}` : report;
const messages = splitText(text);

if (options.dryRun) {
  process.stdout.write(
    `LINE dry-run OK: ${messages.length}件、${Array.from(graphemeSegmenter.segment(text)).length}文字\n`,
  );
  process.exit(0);
}

await sendMessages(token, recipient, messages);
process.stdout.write(`LINE送信完了: ${messages.length}件\n`);
