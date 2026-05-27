# Work PC Bootstrap

A portable, idempotent setup for a Windows dev box geared toward **Python +
Node/React + C# .NET**. Mirrors the personal-PC setup but skips the Rust
toolchain and Rust-specific extras.

Run it any time to install missing tools or pick up new ones — `winget`,
`uv tool install`, and `dotnet tool install` all skip what's already there.

## Files

| File | What it is |
|---|---|
| `bootstrap.ps1` | Idempotent installer. Run from any **elevated or non-elevated** `pwsh`. Installs everything, configures `$PROFILE`, configures `git`. |
| `profile.ps1` | Standalone copy of the `$PROFILE` content (what `bootstrap.ps1` writes). |
| `README.md` | This file. |

## Quick start (on a fresh Work PC)

```powershell
# 0. Ensure PowerShell 7 (pwsh) is installed
winget install --silent Microsoft.PowerShell

# 1. Clone or copy this folder somewhere on the new PC, e.g.:
#    C:\Users\<you>\Documents\work-pc-bootstrap

# 2. Allow local scripts to run for your user
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

# 3. Run the bootstrap (re-run any time to top up new tools)
pwsh -File .\bootstrap.ps1

# 4. Close all PowerShell windows and reopen so PATH and $PROFILE pick up
```

After running, open a new shell. You should have:

- All CLIs below on `PATH`
- A modern `$PROFILE` with completions, predictions, atuin, starship, PSFzf
- `git diff` rendered through `delta`
- `ls`, `ps`, `cat`, `du`, `df`, `top` overridden with modern alternatives
- Per-runtime version managers wired in (`mise` for Node, `uv` for Python)

---

## What's installed

### Core CLIs (winget)

| Tool | Winget ID | Why |
|---|---|---|
| **Git** | `Git.Git` | (probably pre-installed) |
| **GitHub CLI** | `GitHub.cli` | `gh pr`, `gh issue`, `gh api`, etc. |
| **Git LFS** | `GitHub.GitLFS` | Large-file binary tracking |
| **PowerShell 7** | `Microsoft.PowerShell` | Modern cross-platform shell |
| **ripgrep** | `BurntSushi.ripgrep.MSVC` | `rg` — search files for text, respects `.gitignore` |
| **fd** | `sharkdp.fd` | Find files by name (modern `find`) |
| **fzf** | `junegunn.fzf` | Interactive fuzzy picker |
| **ast-grep** | `ast-grep.ast-grep` | `sg` — structural code search/refactor via AST |
| **bat** | `sharkdp.bat` | `cat` with syntax highlighting + pager |
| **delta** | `dandavison.delta` | Beautiful `git diff` |
| **eza** | `eza-community.eza` | Modern `ls` with git status + icons |
| **zoxide** | `ajeetdsouza.zoxide` | `cd` that learns where you go |
| **glow** | `charmbracelet.glow` | Render Markdown in the terminal |
| **starship** | `Starship.Starship` | Cross-shell prompt with context |
| **atuin** | `Atuinsh.Atuin` | Searchable shell history (`Ctrl+R`) |
| **jq** | `jqlang.jq` | JSON query/manipulation |
| **yq** | `MikeFarah.yq` | Same for YAML/TOML/XML/JSON |
| **just** | `Casey.Just` | Lightweight task runner (`justfile`) |
| **mise** | `jdx.mise` | Polyglot runtime version manager (Node, Go, Java, …; **not** Python) |
| **lazygit** | `JesseDuffield.lazygit` | Git TUI |
| **gitleaks** | `Gitleaks.Gitleaks` | Pre-push secret scanner |
| **trivy** | `AquaSecurity.Trivy` | Container/repo CVE + misconfig scanner |
| **mkcert** | `FiloSottile.mkcert` | Local trusted dev TLS certs (`https://localhost`) |
| **dive** | `wagoodman.dive` | Inspect Docker image layers |
| **lazydocker** | `JesseDuffield.Lazydocker` | Docker compose TUI |
| **actionlint** | `rhysd.actionlint` | Lint GitHub Actions workflows |
| **xh** | `ducaale.xh` | HTTPie-compatible HTTP client |
| **hyperfine** | `sharkdp.hyperfine` | Statistical benchmarking |
| **tokei** | `XAMPPRocky.Tokei` | Count LOC by language |
| **tealdeer** | `dbrgn.tealdeer` | `tldr` — fast offline command examples |
| **bottom (btm)** | `Clement.bottom` | `top`/`htop` replacement |
| **dust** | `bootandy.dust` | Better `du` (disk usage) |
| **procs** | `dalance.procs` | Better `ps` (process list) |
| **duf** | `muesli.duf` | Better `df` (disk free) |
| **pandoc** | `JohnMacFarlane.Pandoc` | Universal document converter (md→docx, html→pdf, etc.) |
| **7-Zip** | `7zip.7zip` | Archive tool (winget ensures it's on PATH) |


### Python tools (via `uv tool install`)

`uv` itself comes from winget (`astral-sh.uv`). Then:

- **ruff** — lint + format
- **yamllint** — YAML linter
- **pre-commit** — git hooks framework

```powershell
uv tool install ruff yamllint pre-commit
```

### .NET global tools (via `dotnet tool install -g`)

Assumes `dotnet` SDK is already installed. Adjust to what your projects use:

- **CSharpier** — code formatter (Prettier-style)
- **dotnet-outdated-tool** — check for outdated NuGet packages
- **GitVersion.Tool** — semver from git history
- **dotnet-ef** — Entity Framework Core CLI (if you use EF)
- **dotnet-script** — C# REPL / scripts

```powershell
dotnet tool install -g CSharpier dotnet-outdated-tool GitVersion.Tool dotnet-ef dotnet-script
```

### Node.js (via `mise`)

`mise` manages Node versions; `pnpm` is the package manager:

```powershell
mise use -g node@lts pnpm@latest
mise use -g usage   # required for mise's tab completions
```

For per-project pinning, drop a `mise.toml` in the project root:

```toml
[tools]
node = "22"
pnpm = "11"
```

### PowerShell modules

- **PSFzf** — `Ctrl+T` (file picker), `Alt+C` (dir picker)

```powershell
Install-Module -Name PSFzf -Scope CurrentUser -Force
```

### Optionally — not on winget

Tools that need a different installer. Skip unless you actually use them:

| Tool | Install | Use |
|---|---|---|
| **watchexec** | `scoop install watchexec` (preferred) or `cargo install --locked watchexec-cli` (if you have Rust) | Re-run a command when files change |
| **scoop** | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned; iwr -useb get.scoop.sh \| iex` | Alternative package manager for things missing from winget |
| **markdownlint** | `pnpm add -g markdownlint-cli2` | Lint Markdown |
| **Biome** | per-project: `pnpm add -D --save-exact @biomejs/biome` | Fast JS/TS lint + format |

### Deliberately excluded

These tools overlap with what's already in the set. **Uninstall them** if
previously installed to avoid confusion:

| Tool | Why excluded | Use instead |
|---|---|---|
| **HTTPie** (`http`/`https` CLI) | `xh` is HTTPie-compatible, single Rust binary, faster startup, no Python runtime | `xh` (drop-in replacement, same syntax) |
| **dotnet-format** | Built into the .NET SDK since v6 — just run `dotnet format` | `dotnet format` (built-in) + **CSharpier** (opinionated formatter) |
| **csharprepl** | Duplicates `dotnet-script` which is already installed as a global tool | `dotnet-script` (C# REPL + scripting) |
| **neovim** | Editor preference is zed (personal) / code (work); profile auto-detects | `zed --wait` or `code --wait` |
| **GPG (Gpg4win)** | Commits are signed with SSH keys, not GPG; `pass` is Linux-only | SSH signing (`gpg.format = ssh` in gitconfig) |

---

## What's configured

### `$PROFILE` (`Microsoft.PowerShell_profile.ps1`)

Loaded only in interactive `pwsh` sessions (scripts skip it). Contents:

- **zoxide** activated as `cd` (with a self-healing assertion — see [Troubleshooting](#troubleshooting))
- **mise** activated (polyglot runtime shims)
- **Tab completions** for: mise, gh, docker, kubectl, uv, pnpm (deferred to first idle)
- **PSReadLine** — menu tab completion + inline list-view predictions
- **PSFzf** — `Ctrl+T` files, `Alt+C` dirs (leaves `Ctrl+R` for atuin; deferred)
- **fzf defaults** — uses `fd`, sensible TUI behavior, `Ctrl-/` toggles preview
- **atuin** — `Ctrl+R` history search (deferred)
- **starship** — prompt
- **Env vars** — `EDITOR`/`VISUAL` auto-detect (`zed --wait` → `code --wait`), `PAGER='bat --paging=always --plain'`
- **Drop-in overrides** for built-in aliases (`ls`/`ps`/`cat` → eza/procs/bat+glow) and missing Unix commands (`du`/`df`/`top` → dust/duf/btm)
- **Smart `cat`** — `.md` files are rendered with `glow` (Markdown renderer); everything else uses `bat` (syntax highlighting)
- **Convenience functions** — `lg` (lazygit), `lzd` (lazydocker), `ll`, `la`, `lt`

#### Why the profile is fast (caching + deferral)

The naive way to wire up every modern CLI in `$PROFILE` is to dot-source
the output of each tool's `init` subcommand on every shell start. That
spawns ~10 external processes synchronously and adds 8-15 s to startup on
a typical Windows dev box.

This profile sidesteps that:

- **Cache every `tool init` output** to `%LOCALAPPDATA%\PSCompletions\*.ps1`.
  On boot we dot-source the cache instead of re-running the tool. Cold
  start drops from 10+ s to ~1-2 s.
- **Auto-invalidate** when EITHER the tool's `.exe` mtime is newer than
  the cache OR the generator scriptblock itself changed (each cache file
  embeds a SHA-256 hash of its generator in the header). This catches
  `winget upgrade --force` AND profile edits like adding `--cmd cd`.
- **Validate generated content** before persisting — e.g. the zoxide cache
  is only written if it contains `Set-Alias -Name cd`. Half-baked init
  output never poisons the cache.
- **Defer** completions, PSFzf, atuin, and EDITOR detection to
  `PowerShell.OnIdle` (fires a few ms after the first prompt is drawn).
  Each deferred step is wrapped in its own try/catch so a missing module
  doesn't break the rest.

Helpers:

| Helper | What it does |
|---|---|
| `Measure-ProfileLoad` | Spawns a few fresh `pwsh` and reports avg startup time with/without profile. Use to spot regressions. |
| `Rebuild-CompletionCache` | Force-regenerate every cached `*.ps1`. Useful after a big `winget upgrade -ru --force` burst. |

### `~/.gitconfig`

Adds delta as pager + a handful of best-practice settings if not already
present. The script is conservative — it only sets keys it owns and leaves
your existing config untouched.

```ini
[core]
    pager = delta
[interactive]
    diffFilter = delta --color-only
[delta]
    navigate = true        # n / N to jump between sections
    line-numbers = true
    hyperlinks = true
```

If your work PC's `.gitconfig` doesn't already have these, you may also want
the personal-PC set of best practices (rebase pulls, ff-only, fsck on
fetch/push, etc.). They're listed at the end of `bootstrap.ps1` and applied
only if you uncomment the block.

---

## Updating

Re-run any time. Each command is idempotent:

```powershell
# Update everything winget knows about
winget upgrade --all --silent --accept-source-agreements --accept-package-agreements

# Update Python global tools
uv tool upgrade --all

# Update .NET global tools
dotnet tool update -g --all   # newer .NET SDKs; on older ones: update each by name

# Update Node + pnpm via mise
mise upgrade

# Update PSFzf
Update-Module PSFzf -Force
```

---

## Bringing this with you

This folder is intentionally portable. Options:

1. **OneDrive / Google Drive** — drop it in a synced folder; identical
   everywhere automatically.
2. **Git repo** — `git init` here, push to a private GitHub repo,
   `git clone` on the work PC.
3. **Manual copy** — zip and email yourself. Fine for one-time bootstrap;
   loses the ability to keep two PCs in sync over time.

If you ever add a new tool you like on either PC, edit `bootstrap.ps1`
to include it, sync, and re-run on the other side.

---

## Troubleshooting

### Slow startup (10+ seconds)

You're probably running an older copy of `profile.ps1` that doesn't cache
`init` output. Re-run `bootstrap.ps1` — it rewrites `$PROFILE` from the
cached version in this repo and wipes stale cache files. Then in a fresh
shell:

```powershell
Measure-ProfileLoad   # should be ~1-2 s on top of pwsh's own ~1.3 s baseline
```

If it's still slow, run `Rebuild-CompletionCache` once to force-regenerate
every cached tool, then re-measure. A single tool with a very large
completion script (e.g. `uv`'s is ~700 KB) is normal; what's NOT normal is
spawning every tool's init on every shell.

### `cd <fuzzy>` returns "zoxide: no match found" even for dirs you just visited

This is a **prompt-hook chain bug** — `cd` (the alias) works fine, but
`zoxide add` is never called, so the database never learns the
directories you visit.

Zoxide records visits via a hook installed in `prompt`. The hook wraps
whatever `prompt` already existed and calls through to it. **Starship,
however, replaces `prompt` wholesale without chaining** — so if starship
loads after zoxide, the zoxide hook is orphaned. Mise's hook (which DOES
chain) is fine either way relative to itself.

Correct sync load order in `profile.ps1` is therefore:

```
starship  ->  mise-activate  ->  zoxide
```

If you reorder these, expect the symptom above. Verify the chain in a
fresh shell:

```powershell
$function:prompt.ToString() -match '__zoxide_hook'   # must be True
```

There's a closely related trap: **`starship init powershell` only emits
a shim** that re-spawns starship at runtime to fetch the real init. If
you cache that shim, every shell start still spawns `starship.exe` AND
the shim's `Invoke-Expression` replaces `prompt` *again* after zoxide
already wrapped it — silently breaking the chain a second time. Use
`starship init powershell --print-full-init` for the cache (the profile
in this repo already does).

### `cd` doesn't behave like zoxide (`cd <fuzzy>` fails)

This means zoxide's `cd` alias was never installed. Diagnose in order:

```powershell
Get-Alias cd          # Definition should be __zoxide_z, not Set-Location
Get-Command zoxide    # confirm zoxide is on PATH
Get-Item (Join-Path $env:LOCALAPPDATA 'PSCompletions\zoxide.ps1') |
    Select-Object FullName, Length, LastWriteTime
```

The current `profile.ps1` warns at every shell start if the alias check
fails, so you don't have to guess. Common causes:

| Cause | Fix |
|---|---|
| Stale cache from a first launch where zoxide wasn't on PATH yet (cache file is empty / missing the `Set-Alias` line). | `Rebuild-CompletionCache` — or just re-run `bootstrap.ps1`, which wipes the cache as part of redeploy. |
| `zoxide` genuinely not installed. | `winget install ajeetdsouza.zoxide`, open new shell. |
| Old `profile.ps1` deployed (pre-caching). | Re-run `bootstrap.ps1` from this repo. |
| You're in **Windows PowerShell 5.1** (`powershell.exe`), not pwsh 7. The profile lives at `Documents\PowerShell\…`, not `Documents\WindowsPowerShell\…`. | Launch `pwsh`, or set Windows Terminal's default profile to PowerShell 7. |

The cache is at `%LOCALAPPDATA%\PSCompletions\zoxide.ps1`. You can inspect
it directly — the header comment tells you the schema version, generator
hash, and source `.exe` path that produced it.

### Profile change didn't take effect

The cache invalidates on (1) `.exe` mtime change, (2) generator-scriptblock
hash change, or (3) schema version bump (`$__CompletionCacheSchema` at the
top of `profile.ps1`). If you edited a `Generator` in a way that doesn't
change the scriptblock text, bump the schema constant — that invalidates
everything cluster-wide.

---

## Bypassing the overrides

The profile overrides `ls`/`ps`/`cat` with modern tools that emit text, not
.NET objects. When you need the original PowerShell behavior (e.g., to pipe
to `Where-Object`), use the full cmdlet:

| Function | When you need objects, use |
|---|---|
| `ls` | `Get-ChildItem` |
| `ps` | `Get-Process` |
| `cat` | `Get-Content` |

The functions only apply in interactive shells anyway — `pwsh -File foo.ps1`
skips your `$PROFILE`, so scripts that rely on the PowerShell-native behavior
keep working.
