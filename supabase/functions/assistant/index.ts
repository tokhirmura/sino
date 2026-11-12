// Sino health assistant: one chat turn → LLM → short structured reply.
//
// Secrets (never in the app or repo) — one of:
//   npx supabase secrets set GEMINI_API_KEY=...     (free tier, Google AI Studio)
//   npx supabase secrets set ANTHROPIC_API_KEY=...  (Claude)
// If both are set, Gemini is used. Optional: GEMINI_MODEL to change the model.
// Deploy (lead only):
//   npx supabase functions deploy assistant --use-api
//
// Only signed-in users (incl. guests) can call it — checked below. The app
// falls back to its offline rules on any error, and handles red flags
// locally before calling this function.

const CLAUDE_MODEL = "claude-haiku-5-5";
/// Free tier, tried in order: busy (503/429) or retired (404) → next.
/// `-latest` aliases follow Google's current models. The GEMINI_MODEL
/// secret, if set, is tried first.
const GEMINI_MODELS = [
  "gemini-flash-lite-latest",
  "gemini-3.5-flash-lite",
  "gemini-flash-latest",
];
/// The app waits 20 s in total.
const GEMINI_ATTEMPT_MS = 9000;
const MAX_HISTORY = 8;
const MAX_CHARS = 1000;

/// Screens an action button may open (must match AppRoutes in the app).
const ROUTES = [
  "/doctors",
  "/vitals",
  "/reminders",
  "/nutrition",
  "/workouts",
  "/weather",
  "/sos",
];

const LANG_NAME: Record<string, string> = {
  uz: "Uzbek (Latin script)",
  ru: "Russian",
  en: "English",
};

const SYSTEM = `You are the health assistant inside Sino, a wellness app in Uzbekistan.
Rules:
- You do not diagnose and do not replace a doctor. Give short, practical self-care tips and say when to see a doctor.
- Never name prescription drugs or doses. For over-the-counter relief, suggest asking a pharmacist; you may add a pharmacy search action with a generic name (e.g. "paracetamol", "ibuprofen").
- Emergencies (chest pain, trouble breathing, fainting, stroke signs, heavy bleeding, suicidal thoughts, severe allergic reaction, a child with very high fever): set red_flag = true, tell them to call 103 now, and add a call action for 103.
- Off-topic questions: politely say you only help with health and wellness.
- Answer in the user's language given below. At most 4 short sentences, plain text, no markdown.
- Always answer in the required structured format: text, red_flag, actions (up to 3).`;

const REPLY_TOOL = {
  name: "reply",
  description: "The assistant's answer shown in the app.",
  input_schema: {
    type: "object",
    properties: {
      text: { type: "string", description: "Answer, max 4 short sentences." },
      red_flag: {
        type: "boolean",
        description: "True if this may be an emergency (call 103).",
      },
      actions: {
        type: "array",
        maxItems: 3,
        items: {
          type: "object",
          properties: {
            type: { type: "string", enum: ["open", "pharmacy", "call"] },
            route: { type: "string", enum: ROUTES },
            query: { type: "string", description: "Generic medicine name." },
            number: { type: "string", enum: ["103"] },
          },
          required: ["type"],
        },
      },
    },
    required: ["text", "red_flag", "actions"],
  },
};

/// The same shape in Gemini's schema dialect.
const GEMINI_SCHEMA = {
  type: "OBJECT",
  properties: {
    text: { type: "STRING" },
    red_flag: { type: "BOOLEAN" },
    actions: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          type: { type: "STRING", enum: ["open", "pharmacy", "call"] },
          route: { type: "STRING", enum: ROUTES },
          query: { type: "STRING" },
          number: { type: "STRING", enum: ["103"] },
        },
        required: ["type"],
      },
    },
  },
  required: ["text", "red_flag", "actions"],
};

type Turn = { role: "user" | "assistant"; text: string };
type Msg = { role: "user" | "assistant"; content: string };
type Action = { type: string; route?: string; query?: string; number?: string };
type Reply = Record<string, unknown>;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

/// Keep only actions the app can run.
function cleanActions(raw: unknown): Action[] {
  if (!Array.isArray(raw)) return [];
  const out: Action[] = [];
  for (const a of raw.slice(0, 3)) {
    if (a?.type === "open" && ROUTES.includes(a.route)) {
      out.push({ type: "open", route: a.route });
    } else if (a?.type === "pharmacy" && typeof a.query === "string") {
      const q = a.query.trim().slice(0, 40);
      if (q) out.push({ type: "pharmacy", query: q });
    } else if (a?.type === "call" && a.number === "103") {
      out.push({ type: "call", number: "103" });
    }
  }
  return out;
}

/// The bearer token is a valid user session (asks Supabase Auth).
async function isSignedIn(req: Request): Promise<boolean> {
  const auth = req.headers.get("Authorization") ?? "";
  const token = auth.replace(/^Bearer\s+/i, "");
  // A publishable / anon key is not a user session.
  if (!token || token.startsWith("sb_")) return false;
  const res = await fetch(`${Deno.env.get("SUPABASE_URL")}/auth/v1/user`, {
    headers: {
      Authorization: `Bearer ${token}`,
      apikey: Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    },
  });
  return res.ok;
}

/// Claude: forced `reply` tool → its input.
async function askClaude(
  key: string,
  system: string,
  messages: Msg[],
): Promise<Reply> {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": key,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: CLAUDE_MODEL,
      max_tokens: 600,
      system,
      tools: [REPLY_TOOL],
      tool_choice: { type: "tool", name: "reply" },
      messages,
    }),
  });
  if (!res.ok) throw new Error(`claude ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const tool = (data.content ?? []).find(
    (c: { type: string }) => c.type === "tool_use",
  );
  return tool?.input ?? {};
}

/// Gemini: JSON output constrained by GEMINI_SCHEMA; falls through the
/// model list while models are busy or retired. At most 2 attempts.
async function askGemini(
  key: string,
  system: string,
  messages: Msg[],
): Promise<Reply> {
  const custom = Deno.env.get("GEMINI_MODEL");
  const models = [...(custom ? [custom] : []), ...GEMINI_MODELS].slice(0, 2);
  const body = JSON.stringify({
    systemInstruction: { parts: [{ text: system }] },
    contents: messages.map((m) => ({
      role: m.role === "assistant" ? "model" : "user",
      parts: [{ text: m.content }],
    })),
    generationConfig: {
      maxOutputTokens: 1024,
      responseMimeType: "application/json",
      responseSchema: GEMINI_SCHEMA,
    },
  });
  let lastError = "";
  for (const model of models) {
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
    let res: Response;
    try {
      res = await fetch(url, {
        method: "POST",
        headers: { "x-goog-api-key": key, "content-type": "application/json" },
        body,
        signal: AbortSignal.timeout(GEMINI_ATTEMPT_MS),
      });
    } catch (e) {
      lastError = `${model}: ${e}`;
      continue; // timeout → next model
    }
    if ([404, 429, 500, 503].includes(res.status)) {
      lastError = `${model} ${res.status}: ${await res.text()}`;
      continue;
    }
    if (!res.ok) throw new Error(`gemini ${model} ${res.status}: ${await res.text()}`);
    const data = await res.json();
    const parts: { text?: string }[] =
      data.candidates?.[0]?.content?.parts ?? [];
    return JSON.parse(parts.map((p) => p.text ?? "").join(""));
  }
  throw new Error(`gemini: all models failed — ${lastError}`);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  // Only a signed-in user (incl. guests) — the publishable key alone is
  // public, so the gateway check is not enough to protect the LLM quota.
  if (!(await isSignedIn(req))) return json({ error: "unauthorized" }, 401);

  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  const claudeKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!geminiKey && !claudeKey) return json({ error: "not_configured" }, 503);

  let body: { message?: string; lang?: string; history?: Turn[] };
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad_request" }, 400);
  }
  const message = (body.message ?? "").trim().slice(0, MAX_CHARS);
  if (!message) return json({ error: "empty_message" }, 400);
  const lang = LANG_NAME[body.lang ?? ""] ? body.lang! : "uz";

  // Alternating user/assistant turns, ending with the new message.
  const history = (Array.isArray(body.history) ? body.history : [])
    .filter((t) => (t.role === "user" || t.role === "assistant") && t.text)
    .slice(-MAX_HISTORY);
  const messages: Msg[] = [];
  for (const t of history) {
    const text = String(t.text).slice(0, MAX_CHARS);
    const last = messages[messages.length - 1];
    if (last?.role === t.role) last.content += "\n" + text;
    else if (messages.length > 0 || t.role === "user") {
      messages.push({ role: t.role, content: text });
    }
  }
  if (messages[messages.length - 1]?.role === "user") {
    messages[messages.length - 1].content += "\n" + message;
  } else {
    messages.push({ role: "user", content: message });
  }

  const system = `${SYSTEM}\nUser's language: ${LANG_NAME[lang]}.`;
  let input: Reply;
  try {
    input = geminiKey
      ? await askGemini(geminiKey, system, messages)
      : await askClaude(claudeKey!, system, messages);
  } catch (e) {
    console.error("llm error", e);
    return json({ error: "llm_failed" }, 502);
  }
  const text = typeof input.text === "string" ? input.text.trim() : "";
  if (!text) return json({ error: "llm_empty" }, 502);

  const red = input.red_flag === true;
  const actions = cleanActions(input.actions);
  if (red && !actions.some((a) => a.type === "call")) {
    actions.unshift({ type: "call", number: "103" });
  }
  return json({ text, red_flag: red, actions });
});
