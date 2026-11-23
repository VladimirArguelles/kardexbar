-- ==============================================================================
-- MIGRACIÓN: CONEXIÓN Y SINCRONIZACIÓN DE AUTENTICACIÓN Y USUARIOS (PERFILES)
-- Archivo: supabase/migrations/20261122000001_auth_users_and_perfiles_sync.sql
-- ==============================================================================

-- 1. Función y trigger para sincronizar auth.users con public.perfiles automáticamente
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rol public.rol_usuario := 'BARTENDER'::public.rol_usuario;
  v_raw_rol text;
BEGIN
  v_raw_rol := UPPER(COALESCE(NEW.raw_user_meta_data->>'rol', 'BARTENDER'));
  IF v_raw_rol IN ('ADMINISTRADOR', 'SUPERVISOR', 'BARTENDER', 'CAJERO') THEN
    v_rol := v_raw_rol::public.rol_usuario;
  END IF;

  INSERT INTO public.perfiles (id, nombre, apellido, correo, rol, activo)
  VALUES (
    NEW.id,
    COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'nombre'), ''), 'Usuario'),
    COALESCE(NEW.raw_user_meta_data->>'apellido', ''),
    NEW.email,
    v_rol,
    true
  )
  ON CONFLICT (id) DO UPDATE SET
    nombre = EXCLUDED.nombre,
    apellido = EXCLUDED.apellido,
    correo = EXCLUDED.correo,
    rol = EXCLUDED.rol,
    updated_at = timezone('utc'::text, now());
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Evitar bloquear el registro en auth.users ante cualquier eventualidad
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 2. Vista pública usuarios como sinónimo estructurado de perfiles
CREATE OR REPLACE VIEW public.usuarios AS 
SELECT 
    id,
    nombre,
    apellido,
    correo,
    telefono,
    rol,
    activo,
    created_at,
    updated_at
FROM public.perfiles;
