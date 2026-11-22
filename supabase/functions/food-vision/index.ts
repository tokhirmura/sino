// Sino «Rasmdan aniqlash» (beta): a photo of a plate → up to 3 guesses of
// the dish with an estimated weight and nutrients.
//
// Uses the same secrets as `assistant` (never in the app or repo):
//   GEMINI_API_KEY (preferred, free tier) or ANTHROPIC_API_KEY.
// Deploy (lead only):
//   npx supabase functions deploy food-vision --use-api
//
// Only signed-in users (incl. guests). The photo is used for this one call
// and not stored. The app falls back to a demo guess on any error.

const CLAUDE_MODEL = "claude-haiku-5-5";
const GEMINI_MODELS = ["gemini-flash-latest", "gemini-flash-lite-latest"];
const GEMINI_ATTEMPT_MS = 11000;
/// ~1.5 MB of JPEG in base64; the app sends ≤ 1024 px.
const MAX_IMAGE_CHARS = 2_000_000;

const SYSTEM = `You estimate food from a photo for a nutrition diary in Uzbekistan.
- Identify the dish on the plate (Uzbek cuisine is common: plov/osh, lagman, manti, samsa, shurpa, mastava, dimlama, chuchvara, non, shashlik, salads), or a packaged product / fruit / drink.
- Give up to 3 alternatives, most likely first, each with: a short dish name in Uzbek (Latin script), Russian and English; one emoji; the estimated weight in grams of what is visible; kcal, protein, fat and carbs in grams for that weight; confidence 0..1 (the three should add up to at most 1).
- Be realistic about portion size (use the plate, cutlery and hands for scale). Round grams to 10, kcal to 5.
- If there is no food on the photo, return an empty list.`;

const DISH = {
  type: "object",
  properties: {
    name_uz: { type: "string" },
    name_ru: { type: "string" },
    name_en: { type: "string" },
    emoji: { type: "string" },
    grams: { type: "number" },
    kcal: { type: "number" },
    protein: { type: "number" },
    fat: { type: "number" },
    carbs: { type: "number" },
    confidence: { type: "number" },
  },
  required: [
    "name_uz",
    "name_ru",
    "name_en",
    "emoji",
    "grams",
    "kcal",
    "protein",
    "fat",
    "carbs",
    "confidence",
  ],
};

const REPLY_TOOL = {
  name: "dishes",
  description: "Dishes recognized on the photo.",
  input_schema: {
    type: "object",
    properties: { dishes: { type: "array", maxItems: 3, items: DISH } },
    required: ["dishes"],
  },
};

/// The same shape in Gemini's schema dialect.
const GEMINI_SCHEMA = {
  type: "OBJECT",
  properties: {
    dishes: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: Object.fromEntries(
          Object.entries(DISH.properties).map(([k, v]) => [
            k,
            { type: v.type === "number" ? "NUMBER" : "STRING" },
          ]),
        ),
        required: DISH.required,
      },
    },
  },
  required: ["dishes"],
};

type Dish = Record<string, unknown>;

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

/// The bearer token is a valid user session (asks Supabase Auth).
async function isSignedIn(req: Request): Promise<boolean> {
  const auth = req.headers.get("Authorization") ?? "";
  const token = auth.replace(/^Bearer\s+/i, "");
  if (!token || token.startsWith("sb_")) return false;
  const res = await fetch(`${Deno.env.get("SUPABASE_URL")}/auth/v1/user`, {
    headers: {
      Authorization: `Bearer ${token}`,
      apikey: Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    },
  });
  return res.ok;
}

async function askClaude(key: string, image: string): Promise<Dish[]> {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": key,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: CLAUDE_MODEL,
      max_tokens: 800,
      system: SYSTEM,
      tools: [REPLY_TOOL],
      tool_choice: { type: "tool", name: "dishes" },
      messages: [{
        role: "user",
        content: [
          {
            type: "image",
            source: { type: "base64", media_type: "image/jpeg", data: image },
          },
          { type: "text", text: "What food is this?" },
        ],
      }],
    }),
  });
  if (!res.ok) throw new Error(`claude ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const tool = (data.content ?? []).find(
    (c: { type: string }) => c.type === "tool_use",
  );
  return tool?.input?.dishes ?? [];
}

async function askGemini(key: string, image: string): Promise<Dish[]> {
  const custom = Deno.env.get("GEMINI_VISION_MODEL");
  const models = [...(custom ? [custom] : []), ...GEMINI_MODELS].slice(0, 2);
  const body = JSON.stringify({
    systemInstruction: { parts: [{ text: SYSTEM }] },
    contents: [{
      role: "user",
      parts: [
        { inlineData: { mimeType: "image/jpeg", data: image } },
        { text: "What food is this?" },
      ],
    }],
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
      continue;
    }
    if ([404, 429, 500, 503].includes(res.status)) {
      lastError = `${model} ${res.status}: ${await res.text()}`;
      continue;
    }
    if (!res.ok) {
      throw new Error(`gemini ${model} ${res.status}: ${await res.text()}`);
    }
    const data = await res.json();
    const parts: { text?: string }[] =
      data.candidates?.[0]?.content?.parts ?? [];
    return JSON.parse(parts.map((p) => p.text ?? "").join("")).dishes ?? [];
  }
  throw new Error(`gemini: all models failed — ${lastError}`);
}

const num = (v: unknown, max: number) => {
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) ? Math.min(Math.max(n, 0), max) : 0;
};
const str = (v: unknown) =>
  typeof v === "string" ? v.trim().slice(0, 60) : "";

/// App shape: {name: {uz, ru, en}, emoji, grams, kcal, protein, fat, carbs,
/// confidence}; drops dishes without a name or weight.
function clean(raw: unknown): Dish[] {
  if (!Array.isArray(raw)) return [];
  const out: Dish[] = [];
  for (const d of raw.slice(0, 3)) {
    const uz = str(d?.name_uz), ru = str(d?.name_ru), en = str(d?.name_en);
    const grams = num(d?.grams, 3000);
    if (!(uz || ru || en) || grams <= 0) continue;
    out.push({
      name: { uz: uz || en || ru, ru: ru || en || uz, en: en || uz || ru },
      emoji: str(d?.emoji).slice(0, 8) || "🍽️",
      grams,
      kcal: num(d?.kcal, 5000),
      protein: num(d?.protein, 500),
      fat: num(d?.fat, 500),
      carbs: num(d?.carbs, 1000),
      confidence: num(d?.confidence, 1),
    });
  }
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!(await isSignedIn(req))) return json({ error: "unauthorized" }, 401);

  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  const claudeKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!geminiKey && !claudeKey) return json({ error: "not_configured" }, 503);

  let body: { image?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad_request" }, 400);
  }
  const image = (body.image ?? "").replace(/^data:image\/\w+;base64,/, "");
  if (!image) return json({ error: "no_image" }, 400);
  if (image.length > MAX_IMAGE_CHARS) return json({ error: "too_big" }, 413);

  try {
    const dishes = geminiKey
      ? await askGemini(geminiKey, image)
      : await askClaude(claudeKey!, image);
    return json({ dishes: clean(dishes) });
  } catch (e) {
    console.error("vision error", e);
    return json({ error: "llm_failed" }, 502);
  }
});
