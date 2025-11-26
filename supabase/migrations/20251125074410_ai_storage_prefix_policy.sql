-- Allow reads based on path prefix (user id) for ai-photo-remix bucket, useful when uploads use service role.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'ai-photo-remix prefix select'
  ) THEN
    CREATE POLICY "ai-photo-remix prefix select"
      ON storage.objects
      FOR SELECT
      TO authenticated
      USING (
        bucket_id = 'ai-photo-remix'
        AND name LIKE (auth.uid()::text || '/%')
      );
  END IF;
END$$;
