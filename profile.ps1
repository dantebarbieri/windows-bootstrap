# =====================================================================
# Cached + deferred PowerShell 7 profile.
#
# Why this exists:
#   The naive way of activating every modern CLI in $PROFILE is to dot-
#   source the output of each tool's `init` subcommand on every shell
#   start. That spawns ~10 external processes synchronously before the
#   first prompt; on a typical Windows dev box that's 8-15 seconds.
#
# Strategy:
#   * Cache the output of every "spawn external tool and Invoke-Expression
#     its stdout" call to %LOCALAPPDATA%\PSCompletions\*.ps1.
#   * Auto-invalidate when EITHER the tool's exe mtime is newer than the
#     cache OR the generator scriptblock itself has changed (cache file
#     embeds a hash of the generator in a header comment). This catches:
#       - winget upgrade -ru --force                   (exe mtime bump)
#       - editing this profile to change an init flag  (generator hash)
#       - first install when the tool wasn't on PATH   (cache absent)
#   * Synchronously load only what's needed before the first prompt
#     (prompt, env, aliases). Defer completions / PSFzf / atuin /
#     EDITOR detection to first idle so the prompt appears instantly.
#   * Validate generated cache content (non-empty + tool-specific marker)
#     before persisting, so a transient failure doesn't poison the cache.
#
# Helpers:
#   * `Update-CompletionCache` (alias `Rebuild-CompletionCache`)
#     wipes and regenerates everything — run after a big winget upgrade
#     burst if you want to pre-warm rather than let the next prompt heal.
#   * `Measure-ProfileLoad` reloads this profile under Measure-Command so
#     you can see what the cached version actually costs.
# =====================================================================

$__CompletionCacheDir = Join-Path $env:LOCALAPPDATA 'PSCompletions'
if (-not (Test-Path $__CompletionCacheDir)) {
    New-Item -ItemType Directory -Force -Path $__CompletionCacheDir | Out-Null
}

# Bump to force a global cache regen across all items on next launch.
$__CompletionCacheSchema = 3

function __Get-GeneratorHash {
    param([scriptblock]$Generator)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Generator.ToString())
    $sha   = [System.Security.Cryptography.SHA256]::Create()
    try {
        ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
    } finally {
        $sha.Dispose()
    }
}

# Ensure $Name.ps1 in the cache is fresh; regenerate via $Generator when stale.
# Returns the cache file path, or $null if the exe isn't on PATH (so we don't
# choke when a tool is uninstalled or hasn't landed in PATH yet).
#
# Validator is an optional scriptblock that receives the generated text and
# must return $true for the cache to be written; lets us refuse to persist a
# half-baked init script (e.g. zoxide that's missing `Set-Alias -Name cd`).
function Update-CompletionCacheItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]      $Name,
        [Parameter(Mandatory)] [string]      $Exe,
        [Parameter(Mandatory)] [scriptblock] $Generator,
        [scriptblock]                        $Validator,
        [switch]                             $Force
    )
    $cacheFile = Join-Path $__CompletionCacheDir "$Name.ps1"
    $cmd       = Get-Command $Exe -ErrorAction SilentlyContinue
    if (-not $cmd) { return $null }

    $genHash = __Get-GeneratorHash $Generator
    # Marker line embedded at the top of every cache file. Format:
    #   # __CACHE schema=<n> hash=<sha256> exe=<path>
    $marker = "# __CACHE schema=$__CompletionCacheSchema hash=$genHash exe=$($cmd.Source)"

    $stale = $Force -or -not (Test-Path $cacheFile)
    if (-not $stale) {
        $firstLine = (Get-Content -LiteralPath $cacheFile -TotalCount 1 -ErrorAction SilentlyContinue)
        if ($firstLine -ne $marker) { $stale = $true }
        elseif ((Get-Item $cacheFile).LastWriteTime -lt (Get-Item $cmd.Source).LastWriteTime) { $stale = $true }
    }

    if ($stale) {
        try {
            $generated = & $Generator 2>$null | Out-String
            if ([string]::IsNullOrWhiteSpace($generated)) {
                Write-Warning "Empty output from generator for ${Name}; keeping previous cache."
                return (Test-Path $cacheFile) ? $cacheFile : $null
            }
            if ($Validator -and -not (& $Validator $generated)) {
                Write-Warning "Validator rejected generated cache for ${Name}; keeping previous cache."
                return (Test-Path $cacheFile) ? $cacheFile : $null
            }
            # Atomic-ish replace via temp file in the same directory.
            $tmp = "$cacheFile.tmp"
            Set-Content -Path $tmp -Value ($marker + "`n" + $generated) -Encoding UTF8
            Move-Item -LiteralPath $tmp -Destination $cacheFile -Force
        } catch {
            Write-Warning "Failed to regenerate completion cache for ${Name}: $_"
            return $null
        }
    }
    return $cacheFile
}

# Convenience: ensure-fresh + dot-source in one call.
function Import-CachedScript {
    param(
        [Parameter(Mandatory)] [string]      $Name,
        [Parameter(Mandatory)] [string]      $Exe,
        [Parameter(Mandatory)] [scriptblock] $Generator,
        [scriptblock]                        $Validator
    )
    $f = Update-CompletionCacheItem -Name $Name -Exe $Exe -Generator $Generator -Validator $Validator
    if ($f) { . $f }
}

# --- Sync: needed before first prompt --------------------------------
# IMPORTANT load order: starship -> mise -> zoxide.
#
# Each of these installs a `prompt` function. starship REPLACES `prompt`
# wholesale (no chaining to the previous one); mise and zoxide WRAP the
# existing prompt and call through. So whoever loads after starship must
# come last, or its hook silently never fires.
#
# Concrete symptom of getting this wrong: zoxide's `cd` alias works for
# literal paths but `zoxide add` is never called, so the DB never learns
# the directories you visit and fuzzy `cd <substring>` returns
# "zoxide: no match found" forever.
#
# Also: `starship init powershell` only emits a thin shim that re-spawns
# starship at runtime to get the real init. We bypass that and cache the
# full init via `--print-full-init` — saves the per-launch spawn AND
# avoids the shim's Invoke-Expression replacing the prompt a second time
# (which would clobber a previously-installed zoxide/mise wrapper).
Import-CachedScript starship      starship { starship init powershell --print-full-init }
Import-CachedScript mise-activate mise     { mise activate pwsh }
Import-CachedScript zoxide zoxide `
    { zoxide init powershell --cmd cd } `
    { param($t) $t -match 'Set-Alias -Name cd' }

# Self-healing assertion: if `cd` still isn't pointing at zoxide after the
# cached init dot-sourced, force-regenerate the cache once and retry. If
# THAT fails, warn loudly with enough info to diagnose without re-running
# the whole profile. (See README "Troubleshooting -> zoxide.")
function __Assert-ZoxideCd {
    $a = Get-Alias cd -ErrorAction SilentlyContinue
    if ($a -and $a.Definition -eq '__zoxide_z') { return $true }
    return $false
}
if (-not (__Assert-ZoxideCd) -and (Get-Command zoxide -ErrorAction SilentlyContinue)) {
    Import-CachedScript zoxide zoxide `
        { zoxide init powershell --cmd cd } `
        { param($t) $t -match 'Set-Alias -Name cd' } `
        -ErrorAction SilentlyContinue
    if (-not (__Assert-ZoxideCd)) {
        $zx = Get-Command zoxide -ErrorAction SilentlyContinue
        Write-Warning ("zoxide cd-alias not active. profile=$PROFILE, zoxide={0}, cache={1}. " +
            "Run Rebuild-CompletionCache, or `& zoxide init powershell --cmd cd | iex` to test live." `
            -f $zx.Source, (Join-Path $__CompletionCacheDir 'zoxide.ps1'))
    }
}

# PSReadLine: menu tab completion + inline list-view predictions
if ($Host.Name -eq 'ConsoleHost') {
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
}

# fzf defaults: use fd, sensible TUI behavior, Ctrl-/ toggles preview
$env:FZF_DEFAULT_OPTS    = '--height 40% --layout=reverse --border --inline-info --bind=ctrl-/:toggle-preview'
$env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --follow --exclude .git'
$env:FZF_CTRL_T_COMMAND  = $env:FZF_DEFAULT_COMMAND
$env:FZF_ALT_C_COMMAND   = 'fd --type d --hidden --follow --exclude .git'

# Pager (EDITOR is deferred — it's only needed when a tool actually shells out to an editor)
$env:PAGER = 'bat --paging=always --plain'

# Drop-in replacements (interactive only; $PROFILE doesn't load in `pwsh -File` scripts)
# Bypass any of these with the original cmdlet (Get-ChildItem, Get-Process, Get-Content, ...)
# PowerShell resolves aliases before functions, so remove the built-in aliases first.
Remove-Item Alias:ls  -Force -ErrorAction SilentlyContinue
Remove-Item Alias:ps  -Force -ErrorAction SilentlyContinue
Remove-Item Alias:cat -Force -ErrorAction SilentlyContinue

function ls   { eza --git --icons --group-directories-first @args }
function ll   { eza --git --icons -l --group-directories-first @args }
function la   { eza --git --icons -la --group-directories-first @args }
function lt   { eza --git --icons --tree --level 2 @args }
function ps   { procs @args }
function cat  {
    # Render Markdown with glow; everything else with bat
    $mdFile = $args | Where-Object { $_ -is [string] -and $_ -match '\.(md|mkd|mdx|markdown)$' } | Select-Object -First 1
    if ($mdFile) { glow @args } else { bat --paging=never @args }
}
function du   { dust @args }
function df   { duf @args }
function top  { btm @args }
function htop { btm @args }
function lg   { lazygit @args }
function lzd  { lazydocker @args }

# --- Deferred: fires once when the engine first goes idle ------------
# Completions, PSFzf, atuin, and EDITOR detection don't need to block
# the first prompt. OnIdle runs after PowerShell has nothing else to do
# (typically a few ms after the prompt is drawn).
#
# Each deferred step is wrapped individually so one failing item (e.g.
# a missing module) doesn't prevent the rest of the setup from running.
$null = Register-EngineEvent PowerShell.OnIdle -MaxTriggerCount 1 -Action {
    function __Try($label, [scriptblock]$Block) {
        try { & $Block } catch { Write-Warning ("Deferred init failed: {0}: {1}" -f $label, $_) }
    }

    __Try 'mise-completion' { Import-CachedScript mise-completion mise    { mise completion powershell } }
    __Try 'rustup'          { Import-CachedScript rustup          rustup  { rustup completions powershell } }
    __Try 'gh'              { Import-CachedScript gh              gh      { gh completion -s powershell } }
    __Try 'docker'          { Import-CachedScript docker          docker  { docker completion powershell } }
    __Try 'kubectl'         { Import-CachedScript kubectl         kubectl { kubectl completion powershell } }
    __Try 'uv'              { Import-CachedScript uv              uv      { uv generate-shell-completion powershell } }
    __Try 'pnpm'            { Import-CachedScript pnpm            pnpm    { pnpm completion pwsh } }

    # PSFzf: Ctrl+T (file picker), Alt+C (dir picker).
    # Ctrl+R intentionally NOT bound — atuin owns it (loaded just below).
    __Try 'PSFzf' {
        if ($Host.Name -eq 'ConsoleHost') {
            Import-Module PSFzf
            Set-PsFzfOption -PSReadlineChordProvider       'Ctrl+t' `
                            -PSReadlineChordSetLocation    'Alt+c'  `
                            -PSReadlineChordReverseHistory $null
        }
    }

    __Try 'atuin' { Import-CachedScript atuin atuin { atuin init powershell } }

    # Editor auto-detect: zed (personal) -> code (work) -> vi (git-bundled fallback)
    __Try 'EDITOR' {
        $env:EDITOR = if     (Get-Command zed  -ErrorAction SilentlyContinue) { 'zed --wait' }
                      elseif (Get-Command code -ErrorAction SilentlyContinue) { 'code --wait' }
                      else                                                     { 'vi' }
        $env:VISUAL = $env:EDITOR
    }
}

# --- Helper: force-refresh every cached script -----------------------
# Use after a big upgrade burst (e.g., `winget upgrade -ru --force`) if you
# want to pre-warm rather than let the next prompt regenerate lazily.
# (Normal upgrades self-heal: cache invalidates on exe mtime / generator hash.)
function Update-CompletionCache {
    [CmdletBinding()]
    param([switch]$Quiet)

    $items = @(
        @{ Name='zoxide';          Exe='zoxide';   Gen={ zoxide init powershell --cmd cd };          Val={ param($t) $t -match 'Set-Alias -Name cd' } }
        @{ Name='mise-activate';   Exe='mise';     Gen={ mise activate pwsh } }
        @{ Name='starship';        Exe='starship'; Gen={ starship init powershell --print-full-init } }
        @{ Name='mise-completion'; Exe='mise';     Gen={ mise completion powershell } }
        @{ Name='rustup';          Exe='rustup';   Gen={ rustup completions powershell } }
        @{ Name='gh';              Exe='gh';       Gen={ gh completion -s powershell } }
        @{ Name='docker';          Exe='docker';   Gen={ docker completion powershell } }
        @{ Name='kubectl';         Exe='kubectl';  Gen={ kubectl completion powershell } }
        @{ Name='uv';              Exe='uv';       Gen={ uv generate-shell-completion powershell } }
        @{ Name='pnpm';            Exe='pnpm';     Gen={ pnpm completion pwsh } }
        @{ Name='atuin';           Exe='atuin';    Gen={ atuin init powershell } }
    )

    foreach ($i in $items) {
        $params = @{ Name=$i.Name; Exe=$i.Exe; Generator=$i.Gen; Force=$true }
        if ($i.ContainsKey('Val')) { $params['Validator'] = $i.Val }
        $f = Update-CompletionCacheItem @params
        if (-not $Quiet) {
            if ($f) { Write-Host "  ok  $($i.Name)" -ForegroundColor Green }
            else    { Write-Host "  --  $($i.Name)  (exe not on PATH)" -ForegroundColor DarkYellow }
        }
    }
    if (-not $Quiet) {
        Write-Host "Cache: $__CompletionCacheDir" -ForegroundColor DarkGray
    }
}
Set-Alias Rebuild-CompletionCache Update-CompletionCache

# --- Helper: time the profile so regressions are visible ------------
# Spawns a fresh pwsh that loads this profile and reports wall time.
function Measure-ProfileLoad {
    [CmdletBinding()] param([int]$Runs = 3)
    $times = 1..$Runs | ForEach-Object {
        (Measure-Command { pwsh -NoLogo -Command exit }).TotalMilliseconds
    }
    $base = 1..$Runs | ForEach-Object {
        (Measure-Command { pwsh -NoLogo -NoProfile -Command exit }).TotalMilliseconds
    }
    [pscustomobject]@{
        WithProfileMs    = [math]::Round(($times | Measure-Object -Average).Average, 0)
        NoProfileMs      = [math]::Round(($base  | Measure-Object -Average).Average, 0)
        ProfileOverheadMs= [math]::Round((($times | Measure-Object -Average).Average) - (($base | Measure-Object -Average).Average), 0)
        Runs             = $Runs
    }
}
