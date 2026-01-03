import fs from "node:fs/promises";
import path from "node:path";
import { spawn } from "node:child_process";
import OpenAI from "openai";
import { parse } from "csv-parse/sync";

const LOG_PATH = process.env.LOG_PATH || "RM_QA/DATA/QA/LOG_AJUSTES.csv";
const MODEL = process.env.OPENAI_MODEL || "gpt-5.2";
const MAX_FILES = Number(process.env.AI_MAX_FILES || 10);
const MAX_CHARS = Number(process.env.AI_MAX_CHARS || 20000);

// Pastas permitidas (segurança)
const ALLOWED_PREFIXES = [
  "RM_ACT1/",
  "RM_CORE/",
  "RM_QA/",
  "RM_GOV/",
  "scripts/",
  "docs/",
  "README",
  ".github/workflows/",
  "automation/"
];

function norm(s) {
  return String(s ?? "")
    .normalize("NFKD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .trim();
}

function priorityWeight(p) {
  const m = norm(p).match(/^p(\d+)$/);
  return m ? Number(m[1]) : 999;
}

function numOrInf(x, inf = Number.POSITIVE_INFINITY) {
  const n = Number(x);
  return Number.isFinite(n) ? n : inf;
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

function extractTokens(s) {
  return String(s ?? "")
    .split(/[;,\n\r\t()]/g)
    .map((t) => t.trim())
    .filter((t) => t.length >= 4)
    .slice(0, 40);
}

function keywordize(title, desc) {
  const txt = `${title || ""} ${desc || ""}`.replace(/[^\p{L}\p{N}_ ]/gu, " ");
  const words = txt
    .split(/\s+/g)
    .map((w) => w.trim())
    .filter((w) => w.length >= 5)
    .slice(0, 30);
  return [...new Set(words)];
}

function pickBestMatches(allFiles, tokens) {
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
    .slice(0, MAX_FILES);
}

function validatePatchPaths(patchText) {
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

function buildContext(aj, picked) {
  const ajusteId = String(aj.AjusteID || "AJ_XXXXXX").trim();
  const titulo = String(aj.Titulo || "").trim();

  let ctx = "";
  ctx += `REGRAS IMPORTANTES:\n`;
  ctx += `- Retorne APENAS um patch unified diff compatível com 'git apply'.\n`;
  ctx += `- Mudanças mínimas, sem refatoração desnecessária.\n`;
  ctx += `- Não altere IDs de ajustes.\n`;
  ctx += `- Sem arquivos binários.\n`;
  ctx += `- Se faltar informação, faça a menor mudança segura e registre no patch via comentário.\n\n`;

  ctx += `AJUSTE (do LOG):\n`;
  ctx += `AjusteID: ${ajusteId}\n`;
  ctx += `Titulo: ${titulo}\n`;
  ctx += `Prioridade: ${aj.Prioridade}\n`;
  ctx += `WSJF_RANK: ${aj.WSJF_RANK}\n`;
  ctx += `WSJF_SCORE: ${aj.WSJF_SCORE}\n`;
  ctx += `Area: ${aj.Area}\n`;
  ctx += `Descricao: ${aj.Descricao}\n`;
  ctx += `CriteriosAceite: ${aj.CriteriosAceite}\n`;
  ctx += `DefinicaoDePronto: ${aj.DefinicaoDePronto}\n`;
  ctx += `WorkbooksImpactados: ${aj.WorkbooksImpactados}\n`;
  ctx += `SheetsImpactadas: ${aj.SheetsImpactadas}\n\n`;

  ctx += `ARQUIVOS PARA CONTEXTO (máx ${MAX_FILES}):\n`;
  ctx += picked.map((p) => `- ${p}`).join("\n") + "\n\n";

  return ctx;
}

async function main() {
  if (!process.env.OPENAI_API_KEY) {
    throw new Error("OPENAI_API_KEY não definido. No GitHub, crie um Secret OPENAI_API_KEY.");
  }

  await git(["rev-parse", "--is-inside-work-tree"]);

  const logAbs = path.resolve(process.cwd(), LOG_PATH);
  const logCsv = await fs.readFile(logAbs, "utf8");
  const rows = parse(logCsv, { columns: true, skip_empty_lines: true });

  const backlog = rows.filter((r) => norm(r.Status) === "backlog");
  if (!backlog.length) {
    await fs.writeFile("automation/_AI_PR_BODY.md", "Sem mudanças: nenhum ajuste BACKLOG encontrado.\n", "utf8");
    console.log("Nenhum BACKLOG. Saindo.");
    return;
  }

  // Ordenação: Prioridade (P1 antes), WSJF_RANK (menor melhor), WSJF_SCORE (maior melhor)
  backlog.sort((a, b) => {
    const pa = priorityWeight(a.Prioridade);
    const pb = priorityWeight(b.Prioridade);
    if (pa !== pb) return pa - pb;

    const ra = numOrInf(a.WSJF_RANK);
    const rb = numOrInf(b.WSJF_RANK);
    if (ra !== rb) return ra - rb;

    const sa = numOrInf(a.WSJF_SCORE, -Infinity);
    const sb = numOrInf(b.WSJF_SCORE, -Infinity);
    if (sa !== sb) return sb - sa;

    return String(a.AjusteID).localeCompare(String(b.AjusteID));
  });

  const aj = backlog[0];
  const ajusteId = String(aj.AjusteID || "AJ_XXXXXX").trim();
  const titulo = String(aj.Titulo || "").trim();

  const { out: ls } = await git(["ls-files"]);
  const allFiles = ls.split("\n").map((l) => l.trim()).filter(Boolean);

  const tokens = [
    ...extractTokens(aj.WorkbooksImpactados),
    ...extractTokens(aj.SheetsImpactadas),
    ...keywordize(aj.Titulo, aj.Descricao),
    ajusteId,
  ];

  const picked = pickBestMatches(allFiles, tokens);

  const prBody =
`### AI: ${ajusteId} — ${titulo}

**LOG:** \`${LOG_PATH}\`

**Campos do ajuste:**
- Prioridade: \`${aj.Prioridade}\`
- WSJF_RANK: \`${aj.WSJF_RANK}\` | WSJF_SCORE: \`${aj.WSJF_SCORE}\`
- Area: \`${aj.Area}\`

**Arquivos considerados:**
${picked.map((p) => `- \`${p}\``).join("\n")}

> PR gerada automaticamente. Revise antes de mergear.
`;
  await fs.writeFile("automation/_AI_PR_BODY.md", prBody, "utf8");

  // montar contexto + anexar conteúdo dos arquivos
  let ctx = buildContext(aj, picked);
  for (const f of picked) {
    try {
      const txt = await fs.readFile(path.resolve(process.cwd(), f), "utf8");
      ctx += `\n\n===== FILE: ${f} =====\n${txt.slice(0, MAX_CHARS)}\n`;
    } catch {
      // ignora
    }
  }

  const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

  const tools = [
  {
    type: "function",
    name: "emit_patch",
    description: "Retorna um patch unified diff (compatível com git apply).",
    strict: true,
    parameters: {
      type: "object",
      additionalProperties: false,
      properties: {
        patch: { type: "string" },
      },
      required: ["patch"],
    },
  },
];

const resp = await client.responses.create({
  model: MODEL,
  input: [
    {
      role: "system",
      content:
        "Você é um bot de manutenção de projeto RPG Maker XP. Retorne SOMENTE um patch unified diff (git apply).",
    },
    { role: "user", content: ctx },
  ],
  tools,
  tool_choice: { type: "function", name: "emit_patch" },
});


  const call = (resp.output || []).find((o) => o.type === "function_call" && o.name === "emit_patch");
  if (!call) throw new Error("Modelo não retornou function_call emit_patch.");

  const args = JSON.parse(call.arguments || "{}");
  const patch = String(args.patch || "").trim();
  if (!patch.startsWith("diff --git")) throw new Error("Patch inválido: não começa com 'diff --git'.");

  validatePatchPaths(patch);

  await fs.writeFile("automation/_last_patch.diff", patch + "\n", "utf8");
  await git(["apply", "--whitespace=nowarn", "automation/_last_patch.diff"]);

  const { out: st } = await git(["status", "--porcelain"]);
  if (!st.trim()) {
    console.log("Patch aplicado, mas sem mudanças rastreáveis.");
  } else {
    console.log("Mudanças aplicadas. Workflow vai criar PR.");
  }
}

main().catch((e) => {
  console.error(e?.stack || e?.message || String(e));
  process.exit(1);
});