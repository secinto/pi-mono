# pi-mono (secinto fork) — maintenance guide

This repo is **`secinto/pi-mono`**, a fork of the upstream **`earendil-works/pi`**
(formerly `badlogic/pi-mono`). We carry a small number of local commits on top of
upstream and periodically resync.

## Remotes

Both remotes use **HTTPS** (auth via the `gh` CLI credentials — there is no SSH key
on this host, so SSH `git@github.com:` URLs fail with `publickey`):

```
origin    https://github.com/secinto/pi-mono.git      # our fork
upstream  https://github.com/earendil-works/pi.git     # the parent
```

If `upstream` is missing: `git remote add upstream https://github.com/earendil-works/pi.git`

## Our local commits (what we reapply on every sync)

Only **non-generated** work is carried forward:

- `fix(agent): retry vLLM finish_reason "abort"` — real fix + test in
  `packages/coding-agent/src/core/agent-session.ts`
- `chore(scripts): add local pi build and status scripts` —
  `scripts/build-pi-local.sh`, `scripts/pi-status.sh`

## Sync workflow (keep our commits on top of upstream)

```bash
git fetch upstream
git rebase upstream/main          # replays our commits onto the latest upstream
git push --force-with-lease origin main
```

`--force-with-lease` is required because the rebase rewrites our commit SHAs; it
safely aborts if someone else pushed to `origin/main` first.

### Why GitHub's "Sync fork" button does not work

Our `main` is **ahead** of upstream (it has our local commits), so GitHub can only
fast-forward — it refuses and leaves the fork diverged. We must rebase locally
instead. Uncommitted changes also block the rebase, so commit or stash first.

## Generated files are disposable — do NOT carry them forward

`packages/ai/src/models.generated.ts` and `packages/ai/src/image-models.generated.ts`
are produced by `packages/ai/scripts/generate-models.ts` /
`generate-image-models.ts`. Upstream regenerates them with fresher data, so local
edits/regenerations are stale noise that only cause conflicts and revert upstream's
newer model catalog. During a sync, **discard** local changes to these files and let
upstream's versions win. If you need new model data, regenerate fresh after syncing
rather than reapplying an old diff.

> Note: model entries like `claude-opus-4-8` and the `cloudflare-ai-gateway` provider
> are already upstream. The Cloudflare gateway is just one optional provider variant
> (needs `CLOUDFLARE_API_KEY` + account/gateway IDs); the same model is also available
> via the direct `anthropic` provider, so no Cloudflare account is required.

## Safe-by-default sync (recommended for big resyncs)

```bash
git branch backup/main-presync-$(date +%Y%m%d) main   # snapshot first
git fetch upstream
git rebase upstream/main
# ...verify build/tests, then:
git push --force-with-lease origin main
git branch -D backup/main-presync-YYYYMMDD             # clean up once happy
```
