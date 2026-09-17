# pi-mono (secinto fork) — maintenance guide

This repo is **`secinto/pi-mono`**, a fork of **`earendil-works/pi`** (formerly
`badlogic/pi-mono`). We carry a few local commits on top of upstream and
periodically rebase them onto the latest upstream `main`.

## Remotes — not version-controlled, set up once per clone

```
origin    https://github.com/secinto/pi-mono.git      # our fork
upstream  https://github.com/earendil-works/pi.git     # the parent
```

Use HTTPS (auth via the `gh` CLI); SSH `git@github.com:` URLs fail on this host
(no key). Pin `upstream` to fetch only `main`, otherwise every fetch pulls dozens
of upstream feature branches:

```bash
git remote add upstream https://github.com/earendil-works/pi.git
git config remote.upstream.fetch '+refs/heads/main:refs/remotes/upstream/main'
```

## Our local commits

Only **non-generated** work is carried. The authoritative list, and the files
each commit touches, is `git log --stat upstream/main..main` — do not duplicate
it here. What git does not record:

- `feat(coding-agent): persist compaction trigger reason in the session file` —
  upstreamable; drop it if upstream lands an equivalent.

## Sync workflow

Never use GitHub's "Sync fork" button: it merges upstream *into* our branch,
burying our commits under merge commits instead of keeping them on top, and it
refuses outright on any conflict. Rebase locally instead (uncommitted changes
block the rebase — commit or stash first):

```bash
git branch backup/main-presync-$(date +%Y%m%d) main   # snapshot
git fetch upstream
git rebase upstream/main                             # replays our commits onto upstream
# resolve conflicts, verify (next section), then:
git push --force-with-lease origin main              # rebase rewrote our SHAs; aborts if origin moved
git branch -D backup/main-presync-*                  # once happy
```

Conflict rules:

- **Generated files** (header says "auto-generated", e.g. everything under
  `packages/ai/src/` produced by `scripts/generate-models.ts`): take upstream's
  version. Local regenerations are stale noise; regenerate after the sync if you
  need fresher data.
- **Carried tests that copy an upstream test harness** (e.g.
  `agent-session-retry.test.ts`): when upstream changes the harness, port our
  test and fold it into the original commit (`git commit --fixup=<sha>`, then
  `GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash upstream/main`).

## Verifying after a sync — refresh the local environment first

Two gitignored, locally generated inputs go stale between syncs and produce
errors that look like upstream bugs (or tempt you to hack the source to compile):

```bash
npm ci                        # node_modules must match the (upstream-bumped) lockfile;
                              # never add `as any` casts to work around an old install
npm run hydrate:model-data    # regenerates packages/ai/src/providers/data/*.json;
                              # upstream tests reference current model IDs
npm run check                 # what the husky pre-commit hook runs (tsgo, biome, ...)
```

Upstream CI does the same (`npm ci` → `npm run build` → `npm run check`), so if
`check` fails only in files that are byte-identical to `upstream/main`, the local
environment is stale — not the code.
