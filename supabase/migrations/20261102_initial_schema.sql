-- ============================================================================
-- VoicePen Cloud Backend - Initial Schema Migration
-- Migration: 20261102_initial_schema.sql
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. PROFILES TABLE & SIGNUP TRIGGER
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    display_name TEXT,
    avatar_url TEXT,
    daily_polish_count INT DEFAULT 0,
    last_polish_date DATE DEFAULT CURRENT_DATE,
    audio_backup_enabled BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- Index for profile lookups
CREATE INDEX IF NOT EXISTS idx_profiles_id ON public.profiles(id);

-- Trigger to automatically create a profile row when a new user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, email, display_name, avatar_url)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
        NEW.raw_user_meta_data->>'avatar_url'
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- 2. NOTES TABLE (Local-First Sync with Tombstones & Last-Write-Wins)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL DEFAULT '',
    content TEXT NOT NULL DEFAULT '',
    raw_transcript TEXT DEFAULT '',
    audio_storage_path TEXT,
    tags TEXT[] DEFAULT '{}',
    category TEXT DEFAULT 'General',
    duration_seconds INT DEFAULT 0,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    client_created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- Sync & query performance indexes
CREATE INDEX IF NOT EXISTS idx_notes_user_id ON public.notes(user_id);
CREATE INDEX IF NOT EXISTS idx_notes_user_updated ON public.notes(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_notes_user_deleted ON public.notes(user_id, is_deleted);

-- Automatic updated_at trigger for notes
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::TEXT, NOW());
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_notes_updated_at ON public.notes;
CREATE TRIGGER set_notes_updated_at
    BEFORE UPDATE ON public.notes
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- 3. GEMINI API KEY POOL (Backend Only - Zero Client Exposure)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.gemini_key_pool (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    api_key TEXT NOT NULL UNIQUE,
    label TEXT DEFAULT 'Gemini Key',
    is_active BOOLEAN DEFAULT TRUE,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'rpm_cooldown', 'rpd_exhausted', 'suspended')),
    cooldown_until TIMESTAMPTZ,
    daily_usage_count INT DEFAULT 0,
    last_reset_utc DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_gemini_pool_status ON public.gemini_key_pool(is_active, status, cooldown_until);

-- Atomically leases an active key with load distribution
CREATE OR REPLACE FUNCTION public.get_active_gemini_key()
RETURNS TABLE (
    key_id UUID,
    selected_key TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id UUID;
    v_key TEXT;
BEGIN
    -- 1. Daily midnight UTC reset for keys
    UPDATE public.gemini_key_pool
    SET daily_usage_count = 0,
        status = 'active',
        cooldown_until = NULL,
        last_reset_utc = CURRENT_DATE
    WHERE last_reset_utc < CURRENT_DATE;

    -- 2. Recover RPM cooldown keys whose cooldown has passed
    UPDATE public.gemini_key_pool
    SET status = 'active',
        cooldown_until = NULL
    WHERE status = 'rpm_cooldown'
      AND cooldown_until IS NOT NULL
      AND cooldown_until <= NOW();

    -- 3. Atomically select and lock the least-used available active key
    SELECT id, api_key INTO v_id, v_key
    FROM public.gemini_key_pool
    WHERE is_active = TRUE
      AND status = 'active'
      AND (cooldown_until IS NULL OR cooldown_until <= NOW())
    ORDER BY daily_usage_count ASC, RANDOM()
    LIMIT 1
    FOR UPDATE SKIP LOCKED;

    IF v_id IS NOT NULL THEN
        UPDATE public.gemini_key_pool
        SET daily_usage_count = daily_usage_count + 1
        WHERE id = v_id;

        key_id := v_id;
        selected_key := v_key;
        RETURN NEXT;
    ELSE
        RETURN;
    END IF;
END;
$$;

-- Reports an error against a key to rotate it out of the pool
CREATE OR REPLACE FUNCTION public.report_gemini_key_failure(
    p_key_id UUID,
    p_error_type TEXT -- 'RPM' (Rate Limit) or 'RPD' (Daily Quota)
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF p_error_type = 'RPM' THEN
        -- 60 second temporary cooldown
        UPDATE public.gemini_key_pool
        SET status = 'rpm_cooldown',
            cooldown_until = NOW() + INTERVAL '60 seconds'
        WHERE id = p_key_id;
    ELSIF p_error_type = 'RPD' THEN
        -- Daily quota exhausted: suspend until midnight UTC
        UPDATE public.gemini_key_pool
        SET status = 'rpd_exhausted',
            cooldown_until = (CURRENT_DATE + INTERVAL '1 day')::TIMESTAMPTZ
        WHERE id = p_key_id;
    END IF;
END;
$$;

-- ============================================================================
-- 4. PLAY STORE COMPLIANCE: ACCOUNT DELETION
-- ============================================================================
CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Delete user from auth.users (cascades to profiles and notes)
    DELETE FROM auth.users WHERE id = v_user_id;
END;
$$;

-- ============================================================================
-- 5. ROW-LEVEL SECURITY (RLS) POLICIES
-- ============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gemini_key_pool ENABLE ROW LEVEL SECURITY;

-- Profiles: Users can view and update only their own profile
CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Notes: Full CRUD restricted to authenticated owner
CREATE POLICY "Users can view own notes"
    ON public.notes FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own notes"
    ON public.notes FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own notes"
    ON public.notes FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own notes"
    ON public.notes FOR DELETE
    USING (auth.uid() = user_id);

-- Gemini Key Pool: Revoke all client permissions; service_role only
REVOKE ALL ON public.gemini_key_pool FROM anon, authenticated;
GRANT ALL ON public.gemini_key_pool TO service_role;

-- Grant execution permissions
GRANT EXECUTE ON FUNCTION public.get_active_gemini_key() TO service_role;
GRANT EXECUTE ON FUNCTION public.report_gemini_key_failure(UUID, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;
