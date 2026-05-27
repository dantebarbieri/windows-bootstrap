# =============================================================================
# Work PC bootstrap — Python + Node/React + C# .NET
# =============================================================================
# Idempotent: re-run any time to install missing tools or new additions.
# Requires PowerShell 7 (`pwsh`). Does NOT require admin (winget installs
# per-user by default).
#
# Companion: README.md (in this folder) explains what each tool does.
# =============================================================================

$ErrorActionPreference = 'Continue'  # don't bail on a single failed install

function Section($name) { Write-Host "`n=== $name ===" -ForegroundColor Cyan }
function Info($msg)     { Write-Host "  $msg" }
function Warn($msg)     { Write-Host "  WARN: $msg" -ForegroundColor Yellow }
function Ok($msg)       { Write-Host "  OK: $msg" -ForegroundColor Green }

# -----------------------------------------------------------------------------
# Pre-flight
# -----------------------------------------------------------------------------
Section 'Pre-flight'
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Warn "Running PowerShell $($PSVersionTable.PSVersion); recommend pwsh 7+."
    Warn "Install with: winget install --silent Microsoft.PowerShell"
}
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget not found. Install "App Installer" from the Microsoft Store first.'
}
Ok "winget: $(winget --version)"

# -----------------------------------------------------------------------------
# winget packages
# -----------------------------------------------------------------------------
Section 'winget packages'

$wingetPackages = @(
    # Git ecosystem
    'Git.Git',
    'GitHub.cli',
    'GitHub.GitLFS',

    # Shells / runtimes
    'Microsoft.PowerShell',

    # Search / find
    'BurntSushi.ripgrep.MSVC',   # rg
    'sharkdp.fd',
    'junegunn.fzf',
    'ast-grep.ast-grep',         # sg — structural code search/refactor

    # File viewing / diffs
    'sharkdp.bat',
    'dandavison.delta',
    'eza-community.eza',
    'charmbracelet.glow',

    # Prompt / navigation / history
    'Starship.Starship',
    'ajeetdsouza.zoxide',
    'Atuinsh.Atuin',

    # Structured data
    'jqlang.jq',
    'MikeFarah.yq',

    # Tasks / version managers
    'Casey.Just',
    'jdx.mise',
    'astral-sh.uv',

    # Git TUI
    'JesseDuffield.lazygit',

    # Security
    'Gitleaks.Gitleaks',
    'AquaSecurity.Trivy',
    'FiloSottile.mkcert',

    # Docker (skip if no Docker on work PC; harmless otherwise)
    'wagoodman.dive',
    'JesseDuffield.Lazydocker',

    # CI helpers
    'rhysd.actionlint',

    # HTTP / system
    'ducaale.xh',
    'sharkdp.hyperfine',
    'XAMPPRocky.Tokei',
    'dbrgn.tealdeer',
    'Clement.bottom',
    'bootandy.dust',
    'dalance.procs',
    'muesli.duf',

    # Document conversion / archiving
    'JohnMacFarlane.Pandoc',
    '7zip.7zip'

)

foreach ($id in $wingetPackages) {
    # `winget list` exits 0 only if installed; suppress noisy output
    $check = winget list --id $id --exact --source winget 2>$null | Select-String $id
    if ($check) {
        Info "$id (already installed; skipping)"
    } else {
        Info "Installing $id..."
        winget install --silent --accept-source-agreements --accept-package-agreements --id $id --source winget 2>&1 |
            Out-Null
        if ($LASTEXITCODE -ne 0) {
            Warn "$id install exited $LASTEXITCODE (may still have succeeded; check next run)"
        }
    }
}

# Refresh PATH in this session so subsequent uv/dotnet/mise commands work
$env:Path = "$([Environment]::GetEnvironmentVariable('Path','Machine'));$([Environment]::GetEnvironmentVariable('Path','User'))"

# 7-Zip: winget installs it but doesn't always add to PATH
$sevenZipDir = @("$env:ProgramFiles\7-Zip","${env:ProgramFiles(x86)}\7-Zip") |
    Where-Object { Test-Path "$_\7z.exe" } | Select-Object -First 1
if ($sevenZipDir -and -not (Get-Command 7z -ErrorAction SilentlyContinue)) {
    $userPath = [Environment]::GetEnvironmentVariable('Path','User')
    if ($userPath -notlike "*$sevenZipDir*") {
        [Environment]::SetEnvironmentVariable('Path', "$userPath;$sevenZipDir", 'User')
        $env:Path += ";$sevenZipDir"
        Ok "Added $sevenZipDir to User PATH"
    }
} elseif (Get-Command 7z -ErrorAction SilentlyContinue) {
    Info '7z already on PATH'
} else {
    Warn '7-Zip not found — install manually or re-run after winget completes'
}

# -----------------------------------------------------------------------------
# Python tools (via uv)
# -----------------------------------------------------------------------------
Section 'Python global tools (uv)'
if (Get-Command uv -ErrorAction SilentlyContinue) {
    foreach ($t in @('ruff','yamllint','pre-commit')) {
        Info "uv tool install $t (idempotent)..."
        uv tool install $t 2>&1 | Select-Object -Last 2
    }
} else {
    Warn 'uv not on PATH yet — open a new shell and re-run this script to install Python tools.'
}

# -----------------------------------------------------------------------------
# .NET global tools
# -----------------------------------------------------------------------------
Section '.NET global tools'
if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    $dotnetTools = @(
        'CSharpier',
        'dotnet-outdated-tool',
        'GitVersion.Tool',
        'dotnet-ef',
        'dotnet-script'
    )
    # `dotnet tool list -g` shows what's installed
    $installed = (dotnet tool list -g 2>$null | Select-Object -Skip 2 | ForEach-Object { ($_ -split '\s+')[0] })
    foreach ($t in $dotnetTools) {
        if ($installed -contains $t.ToLower()) {
            Info "$t (already installed)"
        } else {
            Info "dotnet tool install -g $t..."
            dotnet tool install -g $t 2>&1 | Select-Object -Last 2
        }
    }
} else {
    Warn 'dotnet SDK not found. Install from https://dot.net or `winget install Microsoft.DotNet.SDK.9` then re-run.'
}

# -----------------------------------------------------------------------------
# Node + pnpm via mise
# -----------------------------------------------------------------------------
Section 'Node + pnpm (mise)'
if (Get-Command mise -ErrorAction SilentlyContinue) {
    # Disable command-not-found hook — it calls PSReadLine GetHistoryItems()
    # during profile load before history is initialized, causing NullReferenceException.
    mise settings set not_found_auto_install false 2>&1 | Out-Null
    Info 'Disabled mise not_found_auto_install (known PSReadLine race condition)'
    Info 'mise use -g node@lts pnpm@latest usage...'
    mise use -g node@lts pnpm@latest usage 2>&1 | Select-Object -Last 3
} else {
    Warn 'mise not on PATH yet — open a new shell and re-run.'
}

# -----------------------------------------------------------------------------
# PowerShell modules
# -----------------------------------------------------------------------------
Section 'PowerShell modules'
if (-not (Get-Module -ListAvailable -Name PSFzf)) {
    Info 'Install-Module PSFzf...'
    Install-Module -Name PSFzf -Scope CurrentUser -Force -AllowClobber
} else {
    Info 'PSFzf already installed'
}

# -----------------------------------------------------------------------------
# Write $PROFILE
# -----------------------------------------------------------------------------
# Resolve the pwsh 7 profile path explicitly. Two reasons:
#   * If this script is launched from Windows PowerShell 5.1, $PROFILE points
#     at Documents\WindowsPowerShell\... — the wrong shell entirely.
#   * [Environment]::GetFolderPath('MyDocuments') honors OneDrive-redirected
#     Documents folders; $HOME\Documents does not.
$documents      = [Environment]::GetFolderPath('MyDocuments')
$pwshProfile    = Join-Path $documents 'PowerShell\Microsoft.PowerShell_profile.ps1'
$pwshProfileDir = Split-Path $pwshProfile

Section "Write $pwshProfile"
$profileContent = Get-Content -Raw (Join-Path $PSScriptRoot 'profile.ps1')
if (Test-Path $pwshProfile) {
    $bak = "$pwshProfile.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
    Copy-Item $pwshProfile $bak -Force
    Info "Backed up existing profile to $bak"
}
if (-not (Test-Path $pwshProfileDir)) { New-Item -ItemType Directory $pwshProfileDir -Force | Out-Null }
Set-Content -Path $pwshProfile -Value $profileContent -Encoding utf8
Ok "Wrote $pwshProfile"

# -----------------------------------------------------------------------------
# Invalidate the completion cache so the new profile regenerates fresh.
#
# Stale cache is the #1 cause of "I redeployed the profile but `cd` still
# doesn't use zoxide" — e.g. the previous cache was generated when zoxide
# wasn't on PATH yet (so the cached zoxide.ps1 is empty), and exe-mtime
# invalidation alone won't rescue it. Delete only the files this repo owns.
# -----------------------------------------------------------------------------
Section 'Invalidate completion cache'
$cacheDir = Join-Path $env:LOCALAPPDATA 'PSCompletions'
$cacheItems = @(
    'zoxide','mise-activate','starship','mise-completion','rustup',
    'gh','docker','kubectl','uv','pnpm','atuin'
)
if (Test-Path $cacheDir) {
    foreach ($n in $cacheItems) {
        $f = Join-Path $cacheDir "$n.ps1"
        if (Test-Path $f) { Remove-Item -LiteralPath $f -Force; Info "removed $n.ps1" }
    }
    Ok "Cache will regenerate on next pwsh launch"
} else {
    Info "No cache directory yet; profile will create it on first launch"
}

# -----------------------------------------------------------------------------
# Git config — delta + best practices
# -----------------------------------------------------------------------------
Section 'Git config (delta + best practices)'
# Only set keys if not already set, so we don't trample an existing config
function Set-GitIfMissing($key, $value) {
    $cur = git config --global --get $key 2>$null
    if (-not $cur) {
        git config --global $key $value
        Info "Set $key = $value"
    } else {
        Info "$key already = $cur (leaving alone)"
    }
}

# delta integration
Set-GitIfMissing 'core.pager' 'delta'
Set-GitIfMissing 'interactive.diffFilter' 'delta --color-only'
Set-GitIfMissing 'delta.navigate' 'true'
Set-GitIfMissing 'delta.line-numbers' 'true'
Set-GitIfMissing 'delta.hyperlinks' 'true'

# Sensible defaults (opt-in: uncomment if you want these on the work PC too)
# Set-GitIfMissing 'init.defaultBranch' 'main'
# Set-GitIfMissing 'pull.rebase' 'true'
# Set-GitIfMissing 'pull.ff' 'only'
# Set-GitIfMissing 'push.autoSetupRemote' 'true'
# Set-GitIfMissing 'push.followTags' 'true'
# Set-GitIfMissing 'fetch.prune' 'true'
# Set-GitIfMissing 'fetch.pruneTags' 'true'
# Set-GitIfMissing 'fetch.fsckobjects' 'true'
# Set-GitIfMissing 'transfer.fsckobjects' 'true'
# Set-GitIfMissing 'receive.fsckobjects' 'true'
# Set-GitIfMissing 'rebase.autoStash' 'true'
# Set-GitIfMissing 'rebase.autoSquash' 'true'
# Set-GitIfMissing 'rerere.enabled' 'true'
# Set-GitIfMissing 'diff.algorithm' 'histogram'
# Set-GitIfMissing 'diff.colorMoved' 'zebra'
# Set-GitIfMissing 'diff.mnemonicPrefix' 'true'
# Set-GitIfMissing 'diff.renames' 'true'
# Set-GitIfMissing 'merge.conflictStyle' 'zdiff3'
# Set-GitIfMissing 'commit.verbose' 'true'
# Set-GitIfMissing 'help.autocorrect' 'prompt'
# Set-GitIfMissing 'branch.sort' '-committerdate'
# Set-GitIfMissing 'tag.sort' 'version:refname'

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
Section 'Done'
Write-Host @'

Next steps:
  1. CLOSE all PowerShell / Windows Terminal windows.
  2. Open a fresh pwsh window.
  3. Verify:
       starship --version
       mise ls
       git config --global core.pager
  4. Verify zoxide is overriding cd (the #1 thing that regresses on redeploy):
       Get-Alias cd      # Definition should be __zoxide_z
       cd ~              # should still work
  5. Measure your new startup time:
       Measure-ProfileLoad     # built-in helper from profile.ps1

If `cd` is NOT aliased to __zoxide_z after step 4, the profile prints a
Write-Warning at every shell start with the cache path and zoxide.exe path.
Force-rebuild with:  Rebuild-CompletionCache

Manual / optional follow-ups:
  - **Uninstall nvm-windows if present** (mise replaces it):
        winget uninstall CoreyButler.NVMforWindows
    Then in a new shell:  mise use -g node@lts pnpm@latest
  - Atuin sync is INTENTIONALLY NOT configured — leave it offline so
    personal and work shell history stay separate. Do NOT run
    `atuin register` or `atuin login`.
  - Monaspace fonts: already installed on the work PC. If a different PC
    needs them, copy the zips from `~/Downloads` or grab from
    https://monaspace.githubnext.com/. Then point Windows Terminal at
    `Monaspace Neon NF` (Settings -> Defaults -> Appearance -> Font face).
  - Configure your editor of choice separately (the profile already picks
    up zed -> code automatically based on what's on PATH).
'@ -ForegroundColor Green
