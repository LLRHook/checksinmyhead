# Auto-sync web-bill-viewer → Vercel repo

## Completed
- [x] Create `.github/workflows/sync-web-viewer.yml` — triggers on push to `main` touching `web-bill-viewer/**`, subtree splits and force pushes to `dhaliwalg/checksinmyhead`
- [x] Manual sync — pushed current `web-bill-viewer/` contents to `dhaliwalg/checksinmyhead` main via `git subtree split`

## Manual steps (you do these in GitHub UI)

### Set up deploy key so the Action can push to the private repo

1. Generate an SSH key pair (run locally):
   ```bash
   ssh-keygen -t ed25519 -f vercel-sync-key -N ""
   ```

2. Add the **public** key (`vercel-sync-key.pub`) as a deploy key on `dhaliwalg/checksinmyhead`:
   - Go to **Settings → Deploy keys → Add deploy key**
   - Title: `sync-from-monorepo`
   - Check **Allow write access**
   - Paste contents of `vercel-sync-key.pub`

3. Add the **private** key (`vercel-sync-key`) as a secret on `LLRHook/checksinmyhead`:
   - Go to **Settings → Secrets and variables → Actions → New repository secret**
   - Name: `VERCEL_DEPLOY_KEY`
   - Paste contents of `vercel-sync-key`

4. Delete the local key files:
   ```bash
   rm vercel-sync-key vercel-sync-key.pub
   ```

## Verification
- After step 3, push any change to `web-bill-viewer/` on `main` → check Actions tab → confirm private repo updates → Vercel auto-deploys
