# Deployment - June 2, 2026

## Summary
Fixed critical database migration issue and deployed v0.1.0 to production.

## Changes

### Migration Fix: Exercise Template Slug Normalization
**File**: `priv/repo/migrations/20260529154852_create_normalized_exercise_library.exs`

**Issue**: 
- Migration failed with duplicate key violation on `exercise_templates_slug_index`
- Slug "jumping-jacks" already existed, causing constraint violation when multiple exercises normalized to the same slug

**Solution**:
- Updated the slug assignment logic to use PostgreSQL `ROW_NUMBER()` window function
- Duplicate slugs now append a sequence number (e.g., "jumping-jacks", "jumping-jacks-2", "jumping-jacks-3")
- Ensures all slugs are unique while maintaining semantic consistency

**SQL Change**:
```sql
-- Before: Simple REGEXP_REPLACE caused duplicates
UPDATE exercise_templates
SET slug = regexp_replace(lower(trim(name)), '[^a-z0-9]+', '-', 'g')
WHERE slug IS NULL

-- After: Window function handles duplicates
WITH normalized AS (
  SELECT 
    id,
    regexp_replace(lower(trim(name)), '[^a-z0-9]+', '-', 'g') as base_slug,
    ROW_NUMBER() OVER (PARTITION BY regexp_replace(...) ORDER BY id) as rn,
    ...
)
UPDATE exercise_templates et
SET slug = CASE 
  WHEN normalized.rn > 1 THEN normalized.base_slug || '-' || normalized.rn
  ELSE normalized.base_slug
END
```

## Deployment Steps Executed
1. ✅ Rolled back problematic migration and dependent migrations
2. ✅ Applied fixed migration
3. ✅ Compiled application code
4. ✅ Built and deployed assets
5. ✅ Generated production release
6. ✅ Restarted systemd service

## Verification
- All 28 migrations applied successfully
- Service running: `● fittrack.service - Fittrack Phoenix App - Active: active (running)`
- Memory usage: 157.1M
- No errors in application logs

## Deployed Version
- **Release**: fittrack-0.1.0
- **Path**: `_build/prod/rel/fittrack`
- **Date**: June 2, 2026 19:40:48 UTC

## Related Database Tables
- `exercise_templates` - Exercise library templates with normalized slugs
- `exercise_aliases` - Alternative names and slugs for exercises
- `exercise_muscles`, `exercise_equipment` - Template mappings
- `exercise_variations`, `exercise_substitutions` - Exercise relationships
