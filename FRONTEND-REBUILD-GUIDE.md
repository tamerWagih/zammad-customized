# Frontend Asset Rebuild Guide for Docker

## 🚨 IMPORTANT: Frontend Changes Not Showing?

If you've made changes to CoffeeScript, JavaScript, Vue, or CSS files and they're not appearing after a git pull, you **MUST rebuild the frontend assets**.

---

## Quick Rebuild (Recommended)

Run this script on the VM:

```bash
cd /path/to/zammad-customized
chmod +x rebuild-frontend-assets.sh
./rebuild-frontend-assets.sh
```

This will:
1. Stop and remove the `zammad-assets` container
2. Remove the old assets volume
3. Rebuild the assets container
4. Run asset precompilation
5. Restart all services

**Time: ~5-10 minutes**

---

## Manual Rebuild Steps

If the script doesn't work, run these commands manually:

### Step 1: Stop and remove assets container
```bash
docker compose stop zammad-assets
docker compose rm -f zammad-assets
```

### Step 2: Remove old assets volume
```bash
docker volume rm zammad-customized_zammad-assets
```

### Step 3: Rebuild assets container
```bash
docker compose build --no-cache zammad-assets
```

### Step 4: Run asset precompilation
```bash
docker compose up zammad-assets
```

Wait for it to complete (you'll see "Assets precompiled successfully" or similar).

### Step 5: Restart services
```bash
docker compose restart zammad-nginx zammad-railsserver zammad-websocket
```

### Step 6: Clear browser cache
Press `Ctrl+Shift+R` (or `Cmd+Shift+R` on Mac) to hard refresh the page.

---

## Why This Is Needed

The Docker setup uses a **multi-stage build**:

1. **`zammad-assets` container** compiles CoffeeScript → JS and bundles all frontend assets
2. Assets are stored in a **Docker volume** (`zammad-assets`)
3. Other containers mount this volume as **read-only**

This means:
- ✅ Fast startup (assets are pre-compiled)
- ❌ Manual rebuild needed after frontend changes
- ❌ Changes in `.coffee`, `.js`, `.vue`, `.css` files won't auto-update

---

## Alternative: Development Mode (Not Recommended for Production)

For rapid frontend development, you can mount your local files directly:

```yaml
# Add to zammad-railsserver in docker-compose.yml
volumes:
  - ./app/assets:/opt/zammad/app/assets
  - ./app/frontend:/opt/zammad/app/frontend
```

Then restart:
```bash
docker compose restart zammad-railsserver
```

**⚠️ Warning:** This bypasses the optimized build process and may cause performance issues.

---

## Troubleshooting

### Assets not updating after rebuild?
1. Check browser cache (hard refresh with Ctrl+Shift+R)
2. Check browser console for 404 errors on asset files
3. Verify assets volume was recreated: `docker volume ls | grep assets`
4. Check asset container logs: `docker compose logs zammad-assets`

### Rebuild fails with "volume in use" error?
Stop all containers first:
```bash
docker compose down
```
Then retry the rebuild.

### Want to see what changed?
Check the asset container logs:
```bash
docker compose logs zammad-assets | tail -100
```

---

## Files That Require Asset Rebuild

Any changes to these file types require a rebuild:
- `**/*.coffee` (CoffeeScript)
- `**/*.js` (JavaScript)
- `**/*.ts` (TypeScript)
- `**/*.vue` (Vue components)
- `**/*.css`, `**/*.scss` (Stylesheets)
- `**/*.eco` (Eco templates)

Backend changes (Ruby `.rb` files) do **NOT** require asset rebuild, just a service restart.

---

## Quick Reference

| Change Type | Command |
|------------|---------|
| Frontend (JS/Coffee/Vue/CSS) | `./rebuild-frontend-assets.sh` |
| Backend (Ruby) | `docker compose restart zammad-railsserver` |
| Database Migration | `docker compose restart zammad-init` |
| All Services | `docker compose restart` |

---

**Last Updated:** 2025-10-09

