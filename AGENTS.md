# AGENTS.md

This is a **personal fork** of [binwiederhier/ntfy](https://github.com/binwiederhier/ntfy).
It is not the upstream project. Do not open upstream PRs from this branch, and do not
expect upstream to match it.

| Remote     | URL                                  | Role                          |
| ---------- | ------------------------------------ | ----------------------------- |
| `origin`   | `git@github.com:Tyler-Hardin/ntfy.git` | This fork — force-push freely |
| `upstream` | `https://github.com/binwiederhier/ntfy.git` | Read-only source of truth |

`main` is a **linear stack**: one or more fork-local commits rebased directly on top of
`upstream/main`. Nothing else lives on `main`.

## The one rule

> **Every commit must look as if it had been written today, against the newly pulled
> `upstream/main`.**

A commit in this fork is not a historical record of what happened. It is a patch that
*should apply cleanly and make sense to a reader who has never seen the old base*.
Concretely, when rebasing:

- **Amend, don't append.** Fixups to a fork commit belong *inside* that commit, not as a
  new "fix rebase" commit. Git history here should read like a clean feature branch, not
  like a log of maintenance work.
- **Prefer the modern API.** If upstream renamed a function, bumped a dependency, or
  changed a signature, rewrite the fork commit to use it directly. Do not preserve a
  shim, a compatibility layer, or a stale call shape.
- **No functionality may be dropped.** Rebasing is not refactoring-by-attrition. If a
  conflict is hard, the answer is to re-implement the intent against the new code, not to
  delete the feature, the test, or the config option. If something genuinely cannot be
  preserved, stop and ask — do not silently discard it.
- **Keep upstream's commits untouched.** Only fork-local commits are rewritten. Never
  amend, reorder, or edit the content of an upstream commit.
- **Merge conflicts are a signal, not an obstacle.** An auto-merged file can still be
  semantically wrong. A conflict-free rebase is not a correct rebase.

## Maintenance process

```sh
git switch main
git branch backup/pre-rebase-$(date +%Y%m%d-%H%M%S)   # always take a backup
git fetch upstream --prune
git rebase upstream/main
```

1. **Resolve conflicts, then compile.** A clean `git rebase --continue` proves nothing:

   ```sh
   go build ./...
   go vet ./client/... ./cmd/...
   ```

   Watchers: `go.mod` / `go.sum` (upstream bump vs. fork-added deps — keep *both*),
   and any fork signature change (e.g. `client.New` returning `(client, error)`) whose
   *new* upstream call sites never conflicted and so were never updated.

2. **Run the affected tests**, not just the ones you think you touched:

   ```sh
   go test ./client/...
   go test ./cmd/...
   ```

   `server` and `cmd` embed `server/docs` and `server/site`, which are generated and
   gitignored — create throwaway stubs to compile without a full web/docs build, and
   delete them afterwards:

   ```sh
   mkdir -p server/docs server/site && touch server/docs/index.html server/site/app.html
   # ... build/test ...
   rm -rf server/docs server/site
   ```

   `TestCLI_Publish_Wait_PID_And_Cmd` needs `/bin/false`, which does not exist on
   NixOS. Verify against a pristine `upstream/main` worktree before blaming the rebase.

3. **Update and test the Nix flake.** The flake is fork-local and its inputs float;
   an upstream dependency bump *will* invalidate pinned hashes.

   ```sh
   nix flake update                                  # refresh flake.lock inputs
   nix build .#ntfy                                  # server/CLI, runs checks
   nix build .#ntfy-full                             # + web UI and docs
   nix flake check --no-build                        # packages, devShell, NixOS modules
   nix develop --command bash -c 'go version; node --version'
   ```

   Both `vendorHash` (tracks `go.mod`) and `npmDepsHash` (tracks
   `web/package-lock.json`) must be refreshed when their inputs change. To get a new
   hash, temporarily set it to `lib.fakeHash` and read the `got:` value from the
   mismatch error:

   ```sh
   nix build .#ntfy 2>&1 | grep -E 'specified:|got:'
   ```

   Never ship a flake that was not `nix build`-tested.

4. **Fold the work back into the commit it belongs to**, then re-test the final tree:

   ```sh
   git add <files> && git commit -m 'fixup! add flake.nix'
   GIT_SEQUENCE_EDITOR=true git rebase --autosquash upstream/main
   ```

   `nix flake update` results and hash refreshes are part of the flake commit — a flake
   written "today" would pin today's inputs. Likewise, a devShell tweak forced by a
   nixpkgs change belongs in the flake commit, not in a follow-up "fix devShell" commit.

5. **Push.** Rewriting history is expected here:

   ```sh
   git fetch origin --prune
   git push --force-with-lease origin main
   ```

   Prefer `--force-with-lease` over `--force`; it refuses if anyone else pushed.

## Notes for agents

- Confirm the working tree is clean, and record a `backup/` branch, before any rewrite.
- Do not commit generated artifacts: `server/docs/`, `server/site/`, `dist/`, `venv/`,
  `web/build/`.
- Documentation-only or process changes (like this file) get their **own commit** and are
  not squashed into feature commits.
- Report what you verified and what you did not — an untested `nix build` or a skipped
  test suite should be stated explicitly, not implied to pass.
