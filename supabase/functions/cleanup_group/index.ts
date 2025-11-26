// Cleanup group: delete storage objects + DB rows for a given group_id (per user).
// Expects: { groupId: string }
// Auth: caller must be signed in; deletes only their own records.

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
    const { groupId } = (await req.json()) as { groupId?: string };
    if (!groupId) return json({ error: 'groupId required' }, 400, req);

    const user = await getUser(req);
    if (!user) return json({ error: 'Unauthorized' }, 401, req);

    // Fetch rows for this group/user.
    const { data: rows, error: selectErr } = await supabase
      .from('ai_images')
      .select('storage_path')
      .eq('user_id', user.id)
      .eq('group_id', groupId);
    if (selectErr) {
      console.error(selectErr);
      return json({ error: 'Failed to fetch group' }, 500, req);
    }

    const paths = (rows ?? [])
      .map((r: any) => r.storage_path)
      .filter((p: any) => typeof p === 'string' && p.length > 0);

    // Delete storage files.
    if (paths.length > 0) {
      const { error: delErr } = await supabase.storage
        .from('ai-photo-remix')
        .remove(paths);
      if (delErr) {
        console.error(delErr);
        return json({ error: 'Failed to delete storage files' }, 500, req);
      }
    }

    // Delete DB rows.
    const { error: dbDelErr } = await supabase
      .from('ai_images')
      .delete()
      .eq('user_id', user.id)
      .eq('group_id', groupId);
    if (dbDelErr) {
      console.error(dbDelErr);
      return json({ error: 'Failed to delete records' }, 500, req);
    }

    return json({ status: 'ok', deleted: paths.length }, 200, req);
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
