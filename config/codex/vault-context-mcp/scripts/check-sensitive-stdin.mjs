#!/usr/bin/env node

import { readFileSync } from "node:fs";
import { suspectedSensitive } from "../src/core.mjs";

const input = readFileSync(0, "utf8");
if (suspectedSensitive(input)) {
  console.error("sensitive content suspected");
  process.exit(1);
}

console.log(JSON.stringify({ ok: true, sensitive_suspected: false }));
