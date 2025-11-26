// Delete a single image record + storage file for the current user.
// Expects: { storagePath: string }
// Auth: caller must be signed in; only deletes if user owns the record.

// deno-lint-ignore-file no-explicit-any
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SERVICE_ROLE_KEY') ?? '';

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders(req) });
  }

  try {
    const { storagePath } = (await req.json()) as { storagePath?: string };
    if (!storagePath) return json({ error: 'storagePath required' }, 400, req);

    const user = await getUser(req);
    if (!user) return json({ error: 'Unauthorized' }, 401, req);

    // Delete DB row (only if owned).
    const { error: dbErr } = await supabase
      .from('ai_images')
      .delete()
      .eq('user_id', user.id)
      .eq('storage_path', storagePath);
    if (dbErr) {
      console.error(dbErr);
      return json({ error: 'Failed to delete record' }, 500, req);
    }

    // Delete storage file.
    const { error: stErr } = await supabase.storage
      .from('ai-photo-remix')
      .remove([storagePath]);
    if (stErr) {
      console.error(stErr);
      return json({ error: 'Failed to delete storage file' }, 500, req);
    }

    return json({ status: 'ok' }, 200, req);
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
