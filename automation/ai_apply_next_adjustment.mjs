import fs from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";
import { spawn } from "node:child_process";
import OpenAI from "openai";
import { parse } from "csv-parse/sync";

/**
 * AI Apply Next Adjustment — RM_Project
 *
 * Core:
 * - Pick next open AJ from LOG_AJUSTES (Priority + WSJF)
 * - Ask model for unified diff patch (git apply)
 * - Apply patch
 *
 * Mandatory process (README_RM_MAIN):
 * - Ensure FuturasMelhorias has at least 1 item
 * - During homologation: (normally) create at least 1 new AJ BACKLOG
 * - Reprioritize open pool (WSJF_RANK) and refresh RPT_WSJF_OPEN_AJUSTES.csv
 * - Append-only CHANGE_LOG.csv
 * - Refresh checksums.sha256 + manifest.json for modules changed
 *
 * Requested custom behavior:
 * - Allow reading/editing RM_DIST and RM_LEGACY (still blocks binary patches)
 * - Stop creating NEW backlog AJs when next AJ id would reach AJ_001500 (configurable)
 */

// ===================== Config =====================
const LOG_PATH = process.env.LOG_PATH || "RM_QA/DATA/QA/LOG_AJUSTES.csv";
const CHANGE_LOG_PATH = process.env.CHANGE_LOG_PATH || "RM_QA/DATA/QA/CHANGE_LOG.csv";
const RPT_WSJF_PATH = process.env.RPT_WSJF_PATH || "RM_QA/DATA/QA/RPT_WSJF_OPEN_AJUSTES.csv";

const MODEL = process.env.OPENAI_MODEL || "gpt-5.2";
const MAX_FILES = Number(process.env.AI_MAX_FILES || 16);
const MAX_CHARS_PER_FILE = Number(process.env.AI_MAX_CHARS || 20000);
const MAX_MODEL_ATTEMPTS = Number(process.env.AI_MODEL_ATTEMPTS || 3);

// Quando o PRÓXIMO ID chegaria nesse número, paramos de criar novos AJs no backlog.
const STOP_NEW_BACKLOG_AT = Number(process.env.AI_STOP_NEW_BACKLOG_AT || 1500);

// Pastas permitidas (segurança) — agora inclui RM_DIST e RM_LEGACY
const ALLOWED_PREFIXES = [
  "RM_ACT1/",
  "RM_ART/",
  "RM_CORE/",
  "RM_DIST/",
  "RM_LEGACY/",
  "RM_QA/",
  "docs/",
  "scripts/",
  "README",
  ".github/workflows/",
  "automation/",
];

// Arquivos pinned (sempre entram no contexto se existirem)
const PINNED_CONTEXT_FILES = [
  "README.md",
  "RM_CORE/README_RM_MAIN.md",

  // Governança / políticas
  "RM_CORE/DATA/GOV/MANIFESTO_8_ARTEFATOS.json",
  "RM_CORE/DATA/GOV/AI_READABILITY_POLICY.json",
  "RM_CORE/DATA/GOV/LEGACY_BUNDLE_POLICY.json",
  "RM_CORE/DATA/GOV/MER_AI.csv",
  "RM_CORE/DATA/GOV/SPEC_FUNC_AI.csv",
  "RM_CORE/DATA/GOV/SPEC_TEC_AI.csv",

  // Índices / mapeamentos (quando existirem)
  "RM_CORE/DATA/DATA_INDEX.csv",
  "RM_CORE/DATA/sheet_name_map.json",
  "RM_QA/DATA/DATA_INDEX.csv",
  "RM_QA/DATA/sheet_name_map.json",
  "RM_ACT1/DATA/DATA_INDEX.csv",
  "RM_ACT1/DATA/sheet_name_map.json",

  // QA canonical
  "RM_QA/DATA/QA/LOG_AJUSTES.csv",
  "RM_QA/DATA/QA/CHANGE_LOG.csv",
  "RM_QA/DATA/QA/RPT_WSJF_OPEN_AJUSTES.csv",
  "RM_QA/DATA/QA/RMXP_KNOWLEDGE_BASE_CSV.csv",
  "RM_QA/DATA/QA/DIC_STATUS_AJUSTES.csv",
  "RM_QA/DATA/QA/DIC_SHEET_ALIASES.csv",
  "RM_QA/DATA/QA/LEGACY_BUNDLES.csv",
  "RM_QA/DATA/QA/LEGACY_BUNDLE_CONTENTS.csv",

  // Referências
  "RM_CORE/DATA/CORE/REFERENCIAS_MASTER.csv",
];

// ===================== Utils =====================
function norm(s) {
  return String(s ?? "")
    .normalize("NFKD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .trim();
}

function utcNowISO() {
  return new Date().toISOString();
}

function utcNowHuman() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())} ${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}:${pad(d.getUTCSeconds())}`;
}

function priorityWeight(p) {
  const m = norm(p).match(/^p(\d+)$/);
  return m ? Number(m[1]) : 999;
}

function num(x, fallback = NaN) {
  const n = Number(x);
  return Number.isFinite(n) ? n : fallback;
}

function ajNumber(id) {
  // aceita AJ_001500, AJ-001500, AJ001500 etc
  const m = String(id ?? "").match(/AJ[_-]?(\d{6})/i);
  return m ? Number(m[1]) : NaN;
}

async function exists(rel) {
  try {
    await fs.access(path.resolve(process.cwd(), rel));
    return true;
  } catch {
    return false;
  }
}

async function run(cmd, args, { cwd } = {}) {
  return await new Promise((resolve, reject) => {
    const child = spawn(cmd, args, {
      cwd,
      stdio: ["ignore", "pipe", "pipe"],
      shell: false,
    });

    let out = "";
    let err = "";

    child.stdout.on("data", (d) => (out += d.toString("utf8")));
    child.stderr.on("data", (d) => (err += d.toString("utf8")));
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) resolve({ out, err });
      else reject(new Error(`${cmd} ${args.join(" ")} failed (${code})\n${err}`));
    });
  });
}

async function git(args) {
  return await run("git", args);
}

async function readTextSafe(rel, maxChars) {
  const abs = path.resolve(process.cwd(), rel);
  const buf = await fs.readFile(abs);

  // Heurística simples para detectar binário
  const slice = buf.subarray(0, Math.min(buf.length, 4096));
  let zeroCount = 0;
  for (const b of slice) if (b === 0) zeroCount++;
  if (zeroCount > 0) throw new Error(`Arquivo parece binário: ${rel}`);

  const txt = buf.toString("utf8");
  return txt.slice(0, maxChars);
}

function csvEscape(val) {
  const s = String(val ?? "");
  if (/[",\n\r]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

function toCsv(rows, columns) {
  const header = columns.join(",");
  const lines = [header];
  for (const r of rows) {
    lines.push(columns.map((c) => csvEscape(r?.[c] ?? "")).join(","));
  }
  return lines.join("\n") + "\n";
}

async function readCsvWithColumns(rel) {
  const abs = path.resolve(process.cwd(), rel);
  const raw = await fs.readFile(abs, "utf8");
  const rows = parse(raw, { columns: true, skip_empty_lines: true });
  const firstLine = raw.split(/\r?\n/)[0] || "";
  const columns = firstLine.split(",").map((c) => c.trim()).filter(Boolean);
  return { rows, columns, raw };
}

function extractTokens(s) {
  return String(s ?? "")
    .split(/[;,\n\r\t()]/g)
    .map((t) => t.trim())
    .filter((t) => t.length >= 4)
    .slice(0, 50);
}

function keywordize(title, desc) {
  const txt = `${title || ""} ${desc || ""}`.replace(/[^\p{L}\p{N}_ ]/gu, " ");
  const words = txt
    .split(/\s+/g)
    .map((w) => w.trim())
    .filter((w) => w.length >= 5)
    .slice(0, 60);
  return [...new Set(words)];
}

function pickBestMatches(allFiles, tokens, maxN) {
  const nAll = allFiles.map((f) => ({ f, nf: norm(f) }));
  const hits = new Map();

  for (const t of tokens) {
    const nt = norm(t);
    if (!nt) continue;
    for (const { f, nf } of nAll) {
      const base = path.posix.basename(nf);
      if (base.includes(nt) || nf.includes(`/${nt}`)) hits.set(f, (hits.get(f) || 0) + 3);
      else if (nf.includes(nt)) hits.set(f, (hits.get(f) || 0) + 1);
    }
  }

  return [...hits.entries()]
    .sort((a, b) => b[1] - a[1])
    .map(([f]) => f)
    .slice(0, maxN);
}

function uniqueKeepOrder(arr) {
  const seen = new Set();
  const out = [];
  for (const x of arr) {
    if (!x) continue;
    if (seen.has(x)) continue;
    seen.add(x);
    out.push(x);
  }
  return out;
}

async function listGitFiles() {
  const { out } = await git(["ls-files"]);
  return out.split("\n").map((l) => l.trim()).filter(Boolean);
}

function validatePatchPaths(patchText) {
  if (patchText.includes("GIT binary patch")) {
    throw new Error("Patch bloqueado: contém 'GIT binary patch' (binário).");
  }

  const lines = patchText.split("\n");
  const paths = [];

  for (const line of lines) {
    if (line.startsWith("diff --git ")) {
      const m = line.match(/^diff --git a\/(.+?) b\/(.+?)\s*$/);
      if (m) paths.push(m[2]);
    }
  }

  if (!paths.length) throw new Error("Patch inválido: não achei linhas 'diff --git a/... b/...'");

  for (const p of paths) {
    if (p.includes("..")) throw new Error(`Patch bloqueado (path traversal): ${p}`);
    const ok = ALLOWED_PREFIXES.some((pre) => p.startsWith(pre));
    if (!ok) throw new Error(`Patch bloqueado (fora de pastas permitidas): ${p}`);
  }
}

function computeWSJFFields(r) {
  const bv = num(r.BV, NaN);
  const tc = num(r.TC, NaN);
  const rr = num(r.RR_OE, NaN);
  const js = num(r.JobSize, NaN);

  const cod = Number.isFinite(bv) && Number.isFinite(tc) && Number.isFinite(rr)
    ? (bv + tc + rr)
    : num(r.CoD, NaN);

  const score = Number.isFinite(cod) && Number.isFinite(js) && js > 0
    ? (cod / js)
    : num(r.WSJF_SCORE, NaN);

  if (Number.isFinite(cod)) r.CoD = cod;
  if (Number.isFinite(score)) r.WSJF_SCORE = score;
}

function sortOpenPool(rows) {
  return [...rows].sort((a, b) => {
    const pa = priorityWeight(a.Prioridade);
    const pb = priorityWeight(b.Prioridade);
    if (pa !== pb) return pa - pb;

    const sa = num(a.WSJF_SCORE, -Infinity);
    const sb = num(b.WSJF_SCORE, -Infinity);
    if (sa !== sb) return sb - sa;

    const ca = num(a.CoD, -Infinity);
    const cb = num(b.CoD, -Infinity);
    if (ca !== cb) return cb - ca;

    const ja = num(a.JobSize, Infinity);
    const jb = num(b.JobSize, Infinity);
    if (ja !== jb) return ja - jb;

    return String(a.AjusteID).localeCompare(String(b.AjusteID));
  });
}

function isOpenStatus(status) {
  return norm(status) !== "concluido";
}

function maxAjNum(rows) {
  let maxN = 0;
  for (const r of rows) {
    const n = ajNumber(r.AjusteID);
    if (Number.isFinite(n)) maxN = Math.max(maxN, n);
  }
  return maxN;
}

function nextAjId(rows) {
  const next = String(maxAjNum(rows) + 1).padStart(6, "0");
  return `AJ_${next}`;
}

function buildContext(aj, picked) {
  const ajusteId = String(aj.AjusteID || "AJ_XXXXXX").trim();
  const titulo = String(aj.Titulo || "").trim();

  let ctx = "";
  ctx += `PROCESSO:\n`;
  ctx += `- Retorne APENAS um patch unified diff compatível com 'git apply'.\n`;
  ctx += `- O patch DEVE começar com 'diff --git'.\n`;
  ctx += `- Mudanças mínimas; sem refatoração desnecessária.\n`;
  ctx += `- Não altere IDs de ajustes.\n`;
  ctx += `- Sem binários.\n`;
  ctx += `- Se faltar info, faça a menor mudança segura e deixe comentário inline.\n\n`;

  ctx += `AJUSTE:\n`;
  ctx += `AjusteID: ${ajusteId}\n`;
  ctx += `Titulo: ${titulo}\n`;
  ctx += `Prioridade: ${aj.Prioridade}\n`;
  ctx += `WSJF_RANK: ${aj.WSJF_RANK}\n`;
  ctx += `WSJF_SCORE: ${aj.WSJF_SCORE}\n`;
  ctx += `Area: ${aj.Area}\n`;
  ctx += `Descricao: ${aj.Descricao}\n`;
  ctx += `CriteriosAceite: ${aj.CriteriosAceite || aj.CriteriosDeAceite}\n`;
  ctx += `DefinicaoDePronto: ${aj.DefinicaoDePronto}\n`;
  ctx += `Dependencias: ${aj.Dependencias}\n`;
  ctx += `WorkbooksImpactados: ${aj.WorkbooksImpactados}\n`;
  ctx += `SheetsImpactadas: ${aj.SheetsImpactadas}\n\n`;

  ctx += `ARQUIVOS PARA CONTEXTO (máx ${MAX_FILES}):\n`;
  ctx += picked.map((p) => `- ${p}`).join("\n") + "\n\n";

  return ctx;
}

// ===================== Integrity (checksums + manifest) =====================
async function sha256File(absPath) {
  const buf = await fs.readFile(absPath);
  return crypto.createHash("sha256").update(buf).digest("hex");
}

async function walkFiles(dirAbs) {
  const out = [];
  const stack = [dirAbs];
  while (stack.length) {
    const cur = stack.pop();
    const entries = await fs.readdir(cur, { withFileTypes: true });
    for (const e of entries) {
      const p = path.join(cur, e.name);
      if (e.isDirectory()) {
        if (e.name === ".git" || e.name === "node_modules") continue;
        stack.push(p);
      } else if (e.isFile()) {
        out.push(p);
      }
    }
  }
  return out;
}

async function refreshModuleIntegrity(moduleId, versionAj) {
  const moduleRoot = path.resolve(process.cwd(), moduleId);
  const manifestPath = path.join(moduleRoot, "manifest.json");
  const checksPath = path.join(moduleRoot, "checksums.sha256");

  const hasManifest = await exists(path.posix.join(moduleId, "manifest.json"));
  const hasChecks = await exists(path.posix.join(moduleId, "checksums.sha256"));
  if (!hasManifest && !hasChecks) return;

  const allAbs = await walkFiles(moduleRoot);

  const filesAbs = allAbs.filter((p) => {
    const rel = path.relative(moduleRoot, p).replace(/\\/g, "/");
    if (rel === "manifest.json") return false;
    if (rel === "checksums.sha256") return false;
    return true;
  });

  const entries = [];
  for (const abs of filesAbs) {
    const rel = path.relative(moduleRoot, abs).replace(/\\/g, "/");
    const st = await fs.stat(abs);
    const sha = await sha256File(abs);
    entries.push({ relpath: rel, bytes: st.size, sha256: sha });
  }
  entries.sort((a, b) => a.relpath.localeCompare(b.relpath));

  if (hasChecks) {
    const lines = ["# sha256  relpath", ...entries.map((e) => `${e.sha256}  ${e.relpath}`)];
    await fs.writeFile(checksPath, lines.join("\n") + "\n", "utf8");
  }

  if (hasManifest) {
    let manifest = {};
    try {
      manifest = JSON.parse(await fs.readFile(manifestPath, "utf8"));
    } catch {
      manifest = { module: moduleId, manifest_version: 1 };
    }

    manifest.module = manifest.module || moduleId;
    manifest.manifest_version = manifest.manifest_version || 1;
    manifest.generated_utc = utcNowISO();
    manifest.version_aj = versionAj;
    manifest.files = entries;

    await fs.writeFile(manifestPath, JSON.stringify(manifest, null, 2) + "\n", "utf8");
  }
}

async function refreshIntegrityForChangedFiles(versionAj) {
  const { out } = await git(["diff", "--name-only", "HEAD"]);
  const changed = out.split("\n").map((s) => s.trim()).filter(Boolean);

  const modules = new Set();
  for (const f of changed) {
    const top = f.split("/")[0];
    if (top && top.startsWith("RM_")) modules.add(top);
  }

  for (const m of modules) {
    await refreshModuleIntegrity(m, versionAj);
  }
}

// ===================== LOG_AJUSTES process =====================
function ensureFutureImprovement(ajRow) {
  const field = "FuturasMelhorias";
  const cur = String(ajRow?.[field] ?? "").trim();
  if (cur) return;

  const base = String(ajRow?.Titulo ?? "").trim() || String(ajRow?.AjusteID ?? "").trim();
  ajRow[field] = `Follow-up: revisar/homologar efeitos colaterais de "${base}" e criar AJ dedicado para melhorias adicionais.`;
}

function addNoteNoNewBacklog(ajRow) {
  const field = "FuturasMelhorias";
  const cur = String(ajRow?.[field] ?? "").trim();
  const note = `AUTO: follow-ups desativados a partir de AJ_${String(STOP_NEW_BACKLOG_AT).padStart(6, "0")} (pedido do projeto).`;
  if (!cur) {
    ajRow[field] = note;
    return;
  }
  if (!cur.includes("follow-ups desativados")) {
    ajRow[field] = `${cur}\n- ${note}`;
  }
}

function closeAjRow(ajRow, changedFiles) {
  const now = utcNowHuman();
  ajRow.Status = "CONCLUIDO";
  ajRow.UltAtualizacaoUTC = now;

  const maxList = 60;
  const listed = changedFiles.slice(0, maxList);
  const tail = changedFiles.length > maxList ? `; ...(+${changedFiles.length - maxList} files)` : "";
  const summary = `Auto: patch aplicado via automation/ai_apply_next_adjustment.mjs. Arquivos alterados: ${listed.join("; ")}${tail}`;

  if (!String(ajRow.ResultadoConclusao ?? "").trim()) ajRow.ResultadoConclusao = summary;
  if (!String(ajRow.Evidencias ?? "").trim()) ajRow.Evidencias = "Ver diff do commit.";
  if (!String(ajRow.Decisoes ?? "").trim()) ajRow.Decisoes = "Mudanças mínimas; sem refatoração ampla.";
}

function createFollowupAjRow(templateRow, newId) {
  const now = utcNowHuman();
  const t = String(templateRow?.Titulo ?? "").trim();
  const area = String(templateRow?.Area ?? "").trim();

  const follow = {};
  for (const k of Object.keys(templateRow)) follow[k] = "";

  follow.AjusteID = newId;
  follow.Titulo = `Follow-up: ${t}`.slice(0, 120);
  follow.Descricao = `Criado automaticamente como melhoria futura / homologação após ${templateRow.AjusteID}.`;
  follow.Area = area || "QA/CI";
  follow.Prioridade = "P2";
  follow.Status = "BACKLOG";
  follow.DataCriacaoUTC = now;
  follow.UltAtualizacaoUTC = now;

  follow.BV = 5;
  follow.TC = 4;
  follow.RR_OE = 4;
  follow.JobSize = 5;

  computeWSJFFields(follow);
  return follow;
}

function recomputeRanks(logRows) {
  for (const r of logRows) computeWSJFFields(r);

  const open = logRows.filter((r) => isOpenStatus(r.Status));
  const sorted = sortOpenPool(open);

  for (const r of open) r.WSJF_RANK = "";
  let i = 1;
  for (const r of sorted) r.WSJF_RANK = i++;
}

async function refreshWsrfReportFromLog(logRows) {
  const defaultCols = [
    "AjusteID","Titulo","Area","Prioridade","Status",
    "WSJF_SCORE","WSJF_RANK","BV","TC","RR_OE","CoD","JobSize",
    "Dependencias","DefinicaoDePronto","Notas"
  ];

  let cols = defaultCols;
  if (await exists(RPT_WSJF_PATH)) {
    const { raw } = await readCsvWithColumns(RPT_WSJF_PATH);
    const first = raw.split(/\r?\n/)[0] || "";
    const c = first.split(",").map((x) => x.trim()).filter(Boolean);
    if (c.length >= 5) cols = c;
  }

  const open = sortOpenPool(logRows.filter((r) => isOpenStatus(r.Status)));
  const rows = open.map((r) => {
    const out = {};
    for (const c of cols) out[c] = r?.[c] ?? "";
    return out;
  });

  await fs.writeFile(path.resolve(process.cwd(), RPT_WSJF_PATH), toCsv(rows, cols), "utf8");
}

async function appendChangeLog(ajusteId, changedFiles) {
  if (!(await exists(CHANGE_LOG_PATH))) return;

  const { rows, columns } = await readCsvWithColumns(CHANGE_LOG_PATH);
  const cols = columns.length ? columns : ["Versão","Data_UTC","Alterações","TimestampUTC","AjusteID","Descricao"];

  const nowHuman = utcNowHuman();
  const version = `auto_${ajusteId}_${utcNowISO().replace(/[:.]/g, "-")}`;

  const newRow = {};
  for (const c of cols) newRow[c] = "";
  newRow["Versão"] = version;
  newRow["Data_UTC"] = nowHuman;
  newRow["Alterações"] = `AI applied patch + process closure. Files: ${changedFiles.join("; ")}`;
  newRow["TimestampUTC"] = utcNowISO();
  newRow["AjusteID"] = ajusteId;
  newRow["Descricao"] = "Automated AJ run (see commit diff).";

  rows.push(newRow);
  await fs.writeFile(path.resolve(process.cwd(), CHANGE_LOG_PATH), toCsv(rows, cols), "utf8");
}

// ===================== OpenAI patch generation =====================
async function requestPatch(client, ctx, attempt) {
  const tools = [
    {
      type: "function",
      function: {
        name: "emit_patch",
        description: "Retorna um patch unified diff compatível com git apply (deve começar com 'diff --git').",
        parameters: {
          type: "object",
          additionalProperties: false,
          properties: { patch: { type: "string" } },
          required: ["patch"],
        },
        strict: true,
      },
    },
  ];

  const sys = [
    "Você é um bot de manutenção de projeto RPG Maker XP.",
    "RETORNE SOMENTE um patch unified diff compatível com `git apply`.",
    "O patch DEVE começar com `diff --git`.",
    "Nada de explicações, nada fora do diff.",
    "Mudanças mínimas; sem refatoração desnecessária.",
  ].join("\n");

  const user =
    attempt === 1
      ? ctx
      : `Sua resposta anterior foi inválida.\nRegras:\n- Retorne APENAS o patch unified diff.\n- Deve começar com 'diff --git'.\n\n${ctx}`;

  const resp = await client.responses.create({
    model: MODEL,
    input: [
      { role: "system", content: sys },
      { role: "user", content: user },
    ],
    tools,
    tool_choice: { type: "function", function: { name: "emit_patch" } },
  });

  const call = (resp.output || []).find(
    (o) => o.type === "function_call" && (o.name === "emit_patch" || o?.function?.name === "emit_patch")
  );
  if (!call) throw new Error("Modelo não retornou function_call emit_patch.");

  const rawArgs = call.arguments ?? call?.function?.arguments;
  const args = typeof rawArgs === "string" ? JSON.parse(rawArgs || "{}") : (rawArgs || {});
  return String(args.patch || "").trim();
}

// ===================== Main =====================
async function main() {
  if (!process.env.OPENAI_API_KEY) {
    throw new Error("OPENAI_API_KEY não definido. No GitHub, crie um Secret OPENAI_API_KEY.");
  }

  await git(["rev-parse", "--is-inside-work-tree"]);

  // Exigir árvore limpa (bom para Actions). Se quiser liberar local: AI_ALLOW_DIRTY=1
  const { out: porcelain } = await git(["status", "--porcelain"]);
  if (porcelain.trim() && norm(process.env.AI_ALLOW_DIRTY) !== "1") {
    throw new Error("Working tree não está limpa. Faça commit/stash, ou rode com AI_ALLOW_DIRTY=1.");
  }

  // 1) Ler LOG
  const { rows: logRows, columns: logCols } = await readCsvWithColumns(LOG_PATH);

  // 2) Repriorizar pool aberto
  recomputeRanks(logRows);
  const open = sortOpenPool(logRows.filter((r) => isOpenStatus(r.Status)));
  if (!open.length) {
    console.log("Nenhum AJ aberto. Saindo.");
    return;
  }

  const aj = open[0];
  const ajusteId = String(aj.AjusteID || "AJ_XXXXXX").trim();
  const titulo = String(aj.Titulo || "").trim();

  // 3) Arquivos de contexto
  const allFiles = await listGitFiles();

  const tokens = [
    ...extractTokens(aj.WorkbooksImpactados),
    ...extractTokens(aj.SheetsImpactadas),
    ...keywordize(aj.Titulo, aj.Descricao),
    ajusteId,
  ];

  const pinned = [];
  for (const f of PINNED_CONTEXT_FILES) if (await exists(f)) pinned.push(f);

  const matches = pickBestMatches(allFiles, tokens, Math.max(0, MAX_FILES - pinned.length));
  const picked = uniqueKeepOrder([...pinned, ...matches]).slice(0, MAX_FILES);

  // 4) Contexto com conteúdo dos arquivos
  let ctx = buildContext(aj, picked);
  for (const f of picked) {
    try {
      const txt = await readTextSafe(f, MAX_CHARS_PER_FILE);
      ctx += `\n\n===== FILE: ${f} =====\n${txt}\n`;
    } catch (e) {
      ctx += `\n\n===== FILE: ${f} =====\n[unreadable/binary: ${e?.message || "error"}]\n`;
    }
  }

  // 5) Pedir patch ao modelo (com retries)
  const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

  let patch = "";
  let lastErr = null;
  for (let attempt = 1; attempt <= MAX_MODEL_ATTEMPTS; attempt++) {
    try {
      patch = await requestPatch(client, ctx, attempt);
      if (!patch.startsWith("diff --git")) throw new Error("Patch inválido: não começa com 'diff --git'.");
      validatePatchPaths(patch);
      break;
    } catch (e) {
      lastErr = e;
      patch = "";
    }
  }
  if (!patch) throw lastErr || new Error("Falha ao obter patch válido do modelo.");

  // 6) Aplicar patch
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "rm_ai_patch_"));
  const patchPath = path.join(tmpDir, `last_patch_${ajusteId}.diff`);
  await fs.writeFile(patchPath, patch + "\n", "utf8");

  await git(["apply", "--check", "--whitespace=nowarn", patchPath]);
  await git(["apply", "--whitespace=nowarn", patchPath]);

  // 7) Arquivos alterados
  const { out: changed1 } = await git(["diff", "--name-only", "HEAD"]);
  const changedFiles = changed1.split("\n").map((s) => s.trim()).filter(Boolean);

  // 8) Processo obrigatório
  ensureFutureImprovement(aj);

  // --- Controle: parar de criar novos backlog AJs ao chegar em AJ_001500
  const nextId = nextAjId(logRows);
  const nextN = ajNumber(nextId);
  const curN = ajNumber(ajusteId);

  const allowNewBacklog =
    Number.isFinite(nextN) &&
    nextN < STOP_NEW_BACKLOG_AT &&
    !(Number.isFinite(curN) && curN >= STOP_NEW_BACKLOG_AT);

  closeAjRow(aj, changedFiles);

  if (allowNewBacklog) {
    const followRow = createFollowupAjRow(aj, nextId);
    logRows.push(followRow);
  } else {
    // Ainda registra a intenção no FuturasMelhorias (sem criar novo AJ)
    addNoteNoNewBacklog(aj);
  }

  // Reprioriza e salva LOG
  recomputeRanks(logRows);
  await fs.writeFile(path.resolve(process.cwd(), LOG_PATH), toCsv(logRows, logCols), "utf8");

  // Atualiza report + change log
  await refreshWsrfReportFromLog(logRows);
  await appendChangeLog(ajusteId, changedFiles);

  // 9) Integridade módulos alterados
  await refreshIntegrityForChangedFiles(ajusteId);

  console.log(`OK: ${ajusteId} aplicado. follow_up=${allowNewBacklog ? nextId : "DISABLED"}`);
}

main().catch((e) => {
  console.error(e?.stack || e?.message || String(e));
  process.exit(1);
});
