// Supabase Edge Function stub for AI Image Gen app.
// This stays isolated from the Mirror app tables/buckets by using the
// dedicated schema/bucket (see supabase/sql/ai_image_setup.sql).

// deno-lint-ignore-file no-explicit-any
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SERVICE_ROLE_KEY') ?? '';
const aiProvider = 'openai';
const openAiKey =
  Deno.env.get('OPENAI_API_KEY') ?? Deno.env.get('AI_API_KEY') ?? '';

if (!supabaseUrl || !serviceRoleKey) {
  console.error('Missing SUPABASE_URL or SERVICE_ROLE_KEY env.');
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

type RequestBody = {
  imageBase64?: string;
  prompt?: string;
  mode?: 'text' | 'edit';
  groupId?: string;
  aspect?: '1:1' | '2:3' | '3:2';
  quality?: 'low' | 'medium' | 'high';
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders(req) });
  }

  try {
    const {
      imageBase64,
      prompt,
      mode,
      groupId: clientGroupId,
      aspect,
      quality,
    } =
      (await req.json()) as RequestBody;

    const user = await getUser(req);
    if (!user) return json({ error: 'Unauthorized' }, 401, req);

    const genMode: 'text' | 'edit' = mode === 'edit' ? 'edit' : 'text';

    // Require prompt for text/edit; require image for image/edit.
    if (genMode !== 'edit' && !prompt) {
      return json({ error: 'prompt required' }, 400, req);
    }
    if (genMode === 'edit' && !imageBase64) {
      return json({ error: 'imageBase64 required for edit mode' }, 400, req);
    }

    const groupId = clientGroupId ?? crypto.randomUUID();
    let generated: Uint8Array | null = null;
    try {
      generated = await generateImage({
        mode: genMode,
        prompt: prompt ?? '',
        imageBase64,
        aspect: aspect ?? '1:1',
        quality: quality ?? 'low',
      });
    } catch (e) {
      console.error('AI generation threw', e);
      return json(
        { error: 'AI generation failed', detail: String(e) },
        502,
        req,
      );
    }
    if (!generated) {
      return json({ error: 'AI generation failed' }, 502, req);
    }

    const sceneLabel = `${genMode === 'edit' ? 'Edit' : 'Text'} · ${
      aspect ?? '1:1'
    } · ${quality ?? 'low'}`;

    const filePath = `${user.id}/${crypto.randomUUID()}.jpg`;
    const blob = new Blob([generated], { type: 'image/jpeg' });
    const upload = await supabase.storage
      .from('ai-photo-remix')
      .upload(filePath, blob, {
        contentType: 'image/jpeg',
        upsert: false,
      });
    if (upload.error) {
      console.error(upload.error);
      return json(
        { error: 'Failed to upload image', detail: upload.error.message },
        500,
        req,
      );
    }

    const insert = await supabase
      .from('ai_images')
      .insert({
        user_id: user.id,
        kind: 'generated',
        scene: sceneLabel,
        storage_path: filePath,
        prompt,
        group_id: groupId,
      })
      .select('id, storage_path, scene, prompt, kind, group_id')
      .single();
    if (insert.error || !insert.data) {
      console.error(insert.error);
      return json(
        { error: 'Failed to record image', detail: insert.error?.message },
        500,
        req,
      );
    }

    return json({ data: [insert.data] }, 200, req);
  } catch (err) {
    console.error(err);
    return json({ error: 'Unexpected error', detail: String(err) }, 500, req);
  }
});

function corsHeaders(req: Request): HeadersInit {
  const origin = req.headers.get('origin') ?? '*';
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };
}

function json(body: any, status: number, req: Request): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders(req) },
  });
}

async function getUser(req: Request) {
  const authHeader = req.headers.get('authorization');
  if (!authHeader) return null;
  const jwt = authHeader.replace('Bearer ', '');
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser(jwt);
  if (error || !user) {
    console.error(error ?? 'No user in token');
    return null;
  }
  return user;
}

async function generateImage(params: {
  mode: 'text' | 'image' | 'edit';
  prompt: string;
  imageBase64?: string;
  aspect: '1:1' | '2:3' | '3:2';
  quality: 'low' | 'medium' | 'high';
}): Promise<Uint8Array | null> {
  if (aiProvider === 'openai') {
    if (params.mode === 'text') {
      return generateWithOpenAIText(params.prompt, params.aspect, params.quality);
    }
    return generateWithOpenAIImageEdit(
      params.imageBase64!,
      params.prompt,
      params.aspect,
      params.quality,
    );
  }

  if (aiProvider === 'nanobanana') {
    return generateWithNanoBanana(params);
  }

  console.error(`Unsupported AI_PROVIDER ${aiProvider}`);
  return null;
}

function decodeBase64(b64: string): Uint8Array {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

function aspectToSize(aspect: '1:1' | '2:3' | '3:2'): string {
  switch (aspect) {
    case '2:3':
      return '1024x1536';
    case '3:2':
      return '1536x1024';
    case '1:1':
    default:
      return '1024x1024';
  }
}

function qualityToParam(
  quality: 'low' | 'medium' | 'high',
): 'low' | 'medium' | 'high' | 'auto' {
  // OpenAI accepts: low, medium, high, auto.
  if (quality === 'high') return 'high';
  if (quality === 'medium') return 'medium';
  return 'low';
}

async function generateWithOpenAIImageEdit(
  imageBase64: string,
  prompt: string,
  aspect: '1:1' | '2:3' | '3:2',
  quality: 'low' | 'medium' | 'high',
): Promise<Uint8Array | null> {
  if (!openAiKey) {
    console.error('OPENAI_API_KEY missing');
    return null;
  }

  // Using images/edits to guide scene change. Requires multipart/form-data.
  const endpoint = 'https://api.openai.com/v1/images/edits';

  // Decode base64 to bytes for upload.
  const bytes = decodeBase64(imageBase64);
  const form = new FormData();
  form.append('model', 'gpt-image-1');
  form.append(
    'image',
    new File([bytes], 'input.jpg', { type: 'image/jpeg' }),
  );
  form.append('prompt', prompt || 'Enhance this image.');
  form.append('n', '1');
  form.append('size', aspectToSize(aspect));
  form.append('quality', qualityToParam(quality));

  const res = await fetch(endpoint, {
    method: 'POST',
    headers: { Authorization: `Bearer ${openAiKey}` },
    body: form,
  });

  if (!res.ok) {
    const detail = await res.text();
    console.error('OpenAI request failed', res.status, detail);
    throw new Error(`openai image edit ${res.status}: ${detail}`);
  }

  const jsonRes = await res.json();
  const data =
    jsonRes.data?.[0]?.b64_json ??
    jsonRes.data?.[0]?.image_base64 ??
    jsonRes.data?.[0]?.base64 ??
    null;
  if (data) {
    return decodeBase64(data);
  }

  const url =
    jsonRes.data?.[0]?.url ??
    jsonRes.data?.[0]?.image_url ??
    jsonRes.data?.[0]?.image ??
    null;
  if (url) {
    const fetchRes = await fetch(url);
    if (!fetchRes.ok) {
      console.error('Failed to fetch image URL', fetchRes.status);
      return null;
    }
    const array = new Uint8Array(await fetchRes.arrayBuffer());
    return array;
  }

  if (!data) {
    console.error('Unexpected OpenAI response', jsonRes);
    return null;
  }
  return null;
}

async function generateWithNanoBanana(
  params: {
    mode: 'text' | 'image' | 'edit';
    prompt: string;
    imageBase64?: string;
    aspect: '1:1' | '2:3' | '3:2';
    quality: 'low' | 'medium' | 'high';
  },
): Promise<Uint8Array | null> {
  if (!nanoKey) {
    console.error('NANOBANANA_API_KEY missing');
    return null;
  }

  const payload: Record<string, unknown> = {
    model: 'gpt-image-1-mini',
    prompt: params.prompt,
    n: 1,
    size: aspectToSize(params.aspect),
    response_format: 'b64_json',
  };
  if (params.mode !== 'text' && params.imageBase64) {
    payload.image_base64 = params.imageBase64;
  }

  const res = await fetch(nanoEndpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${nanoKey}`,
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const detail = await res.text();
    console.error('NanoBanana request failed', res.status, detail);
    throw new Error(`nanobanana ${res.status}: ${detail}`);
  }

  const jsonRes = await res.json();
  const data =
    jsonRes.data?.[0]?.b64_json ??
    jsonRes.data?.[0]?.image_base64 ??
    jsonRes.image ??
    jsonRes.result ??
    null;
  if (!data) {
    console.error('Unexpected NanoBanana response', jsonRes);
    return null;
  }
  return decodeBase64(data);
}

async function generateWithOpenAIText(
  prompt: string,
  aspect: '1:1' | '2:3' | '3:2',
  quality: 'low' | 'medium' | 'high',
): Promise<Uint8Array | null> {
  if (!openAiKey) {
    console.error('OPENAI_API_KEY missing');
    return null;
  }
  const endpoint = 'https://api.openai.com/v1/images/generations';
  const body = {
    model: 'gpt-image-1',
    prompt,
    n: 1,
    size: aspectToSize(aspect),
    quality: qualityToParam(quality),
  };
  const res = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${openAiKey}`,
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const detail = await res.text();
    console.error('OpenAI text gen failed', res.status, detail);
    throw new Error(`openai text ${res.status}: ${detail}`);
  }
  const jsonRes = await res.json();
  const data =
    jsonRes.data?.[0]?.b64_json ??
    jsonRes.data?.[0]?.image_base64 ??
    jsonRes.data?.[0]?.base64 ??
    null;
  if (data) return decodeBase64(data);

  const url =
    jsonRes.data?.[0]?.url ??
    jsonRes.data?.[0]?.image_url ??
    jsonRes.data?.[0]?.image ??
    null;
  if (url) {
    const fetchRes = await fetch(url);
    if (!fetchRes.ok) {
      console.error('Failed to fetch image URL', fetchRes.status);
      return null;
    }
    return new Uint8Array(await fetchRes.arrayBuffer());
  }
  console.error('Unexpected OpenAI text response', jsonRes);
  return null;
}
