import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface PolishRequestBody {
  mode: "text" | "audio";
  rawText?: string;
  audioBase64?: string;
  audioStoragePath?: string;
  mimeType?: string;
  tone?: string;
  format?: string;
  language?: string;
}

const SYSTEM_INSTRUCTION = `You are VoicePen, an editorial transcription and writing assistant.
Convert spoken thoughts into clean, structured, and eloquently polished notes while strictly preserving the speaker's original intent, core vocabulary, and authentic voice.
Return a structured output with:
1. A concise, engaging title.
2. The beautifully structured polished content formatted in markdown.
3. A 1-2 sentence executive summary.
4. 2-4 relevant topic tags.`;

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Supabase environment configuration missing");
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 1. Authenticate user via JWT
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Invalid or expired token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Check & increment user's daily quota (e.g. 30 requests/day)
    const { data: profile } = await supabase
      .from("profiles")
      .select("daily_polish_count, last_polish_date")
      .eq("id", user.id)
      .single();

    const today = new Date().toISOString().split("T")[0];
    let dailyCount = profile?.daily_polish_count ?? 0;
    const lastDate = profile?.last_polish_date;

    if (lastDate !== today) {
      dailyCount = 0;
    }

    const DAILY_LIMIT = 30;
    if (dailyCount >= DAILY_LIMIT) {
      return new Response(
        JSON.stringify({
          error: "Daily VoicePen Cloud AI quota reached (30/30 notes). Please try again tomorrow or switch to your personal Gemini key in Settings.",
          quota_exceeded: true,
        }),
        {
          status: 429,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Parse request body
    const body: PolishRequestBody = await req.json();
    const { mode, rawText, audioBase64, mimeType = "audio/m4a", tone = "Clear & Concise", format = "Executive Summary", language = "auto" } = body;

    // 3. Key pool rotation & failover loop (Up to 3 retries)
    const MAX_RETRIES = 3;
    let attempts = 0;
    let lastError: string | null = null;

    while (attempts < MAX_RETRIES) {
      attempts++;

      // Atomically lease an available active key from the pool
      const { data: keyData, error: keyError } = await supabase.rpc("get_active_gemini_key");

      if (keyError || !keyData || keyData.length === 0) {
        return new Response(
          JSON.stringify({
            error: "All VoicePen Cloud AI keys are currently at capacity. Please retry in a few moments or use your personal key in Settings.",
            pool_exhausted: true,
          }),
          {
            status: 503,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      const { key_id, selected_key } = keyData[0];

      try {
        // Construct Gemini request payload
        const promptInstruction = `Tone: ${tone}. Format: ${format}. Spoken Language: ${language}.\nTransform the following into clean structured notes.`;
        
        let contentsParts: any[] = [];
        if (mode === "audio" && audioBase64) {
          contentsParts = [
            { text: promptInstruction },
            {
              inlineData: {
                mimeType: mimeType,
                data: audioBase64,
              },
            },
          ];
        } else {
          contentsParts = [
            { text: `${promptInstruction}\n\nSpoken verbatim draft:\n"""\n${rawText ?? ""}\n"""` },
          ];
        }

        const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent`;
        const geminiRes = await fetch(geminiUrl, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": selected_key,
          },
          body: JSON.stringify({
            contents: [{ parts: contentsParts }],
            systemInstruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
            generationConfig: {
              temperature: 0.3,
              responseMimeType: "application/json",
              responseSchema: {
                type: "OBJECT",
                properties: {
                  title: { type: "STRING" },
                  summary: { type: "STRING" },
                  content: { type: "STRING" },
                  tags: { type: "ARRAY", items: { type: "STRING" } },
                  verbatim_transcript: { type: "STRING" },
                },
                required: ["title", "content", "summary", "tags"],
              },
            },
          }),
        });

        if (geminiRes.status === 429) {
          const errBody = await geminiRes.text();
          const isDailyQuota = errBody.toLowerCase().includes("daily") || errBody.toLowerCase().includes("day");
          const errorType = isDailyQuota ? "RPD" : "RPM";

          // Report failure to rotate key out
          await supabase.rpc("report_gemini_key_failure", {
            p_key_id: key_id,
            p_error_type: errorType,
          });

          lastError = `Key ${key_id} hit ${errorType} rate limit. Rotating...`;
          continue; // Try next key
        }

        if (!geminiRes.ok) {
          const errText = await geminiRes.text();
          lastError = `Gemini API returned ${geminiRes.status}: ${errText}`;
          continue;
        }

        const resultJson = await geminiRes.json();
        const candidate = resultJson.candidates?.[0];

        // Gracefully handle Gemini safety filter blocks
        if (candidate?.finishReason === "SAFETY") {
          return new Response(
            JSON.stringify({
              title: "Voice Note",
              summary: "Polishing skipped due to content safety filters.",
              content: rawText ?? "Audio content could not be polished due to safety guidelines.",
              tags: ["Note"],
              safety_blocked: true,
            }),
            {
              status: 200,
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            }
          );
        }

        const textOutput = candidate?.content?.parts?.[0]?.text;
        if (!textOutput) {
          throw new Error("Empty response returned from AI model");
        }

        const parsedOutput = JSON.parse(textOutput);

        // Update user's daily usage count
        await supabase
          .from("profiles")
          .update({
            daily_polish_count: dailyCount + 1,
            last_polish_date: today,
            updated_at: new Date().toISOString(),
          })
          .eq("id", user.id);

        return new Response(JSON.stringify(parsedOutput), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });

      } catch (err: any) {
        lastError = err.message;
      }
    }

    return new Response(
      JSON.stringify({
        error: "Failed to polish note after pool failovers. " + (lastError ?? ""),
      }),
      {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );

  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
