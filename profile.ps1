# === Directory navigation (zoxide replaces `cd`) ===
Invoke-Expression (& { (zoxide init powershell --cmd cd | Out-String) })

# === Polyglot runtime manager (Node/Go/Ruby/etc; Python stays with uv) ===
Invoke-Expression (& { (mise activate pwsh) -join "`n" })

# === Tab completions for installed CLIs (each guarded so missing tools don't break the profile) ===
foreach ($t in @(
    @{ Cmd = 'mise';    Args = @('completion','powershell') },
    @{ Cmd = 'rustup';  Args = @('completions','powershell') },
    @{ Cmd = 'gh';      Args = @('completion','-s','powershell') },
    @{ Cmd = 'docker';  Args = @('completion','powershell') },
    @{ Cmd = 'kubectl'; Args = @('completion','powershell') },
    @{ Cmd = 'uv';      Args = @('generate-shell-completion','powershell') },
    @{ Cmd = 'pnpm';    Args = @('completion','pwsh') }
)) {
    if (Get-Command $t.Cmd -ErrorAction SilentlyContinue) {
        try { & $t.Cmd @($t.Args) 2>$null | Out-String | Invoke-Expression } catch { }
    }
}

# === PSReadLine: menu tab completion + inline list-view predictions ===
# Guarded — PSReadLine only initializes in interactive console hosts.
if ($Host.Name -eq 'ConsoleHost' -and (Get-Module PSReadLine)) {
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
}

# === PSFzf: Ctrl+T (file picker), Alt+C (dir picker) ===
# Ctrl+R intentionally NOT bound here — atuin owns it (loads next).
if ($Host.Name -eq 'ConsoleHost') {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider       'Ctrl+t' `
                    -PSReadlineChordSetLocation    'Alt+c'  `
                    -PSReadlineChordReverseHistory $null
}

# === fzf defaults: use fd, sensible TUI behavior, Ctrl-/ toggles preview ===
$env:FZF_DEFAULT_OPTS    = '--height 40% --layout=reverse --border --inline-info --bind=ctrl-/:toggle-preview'
$env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --follow --exclude .git'
$env:FZF_CTRL_T_COMMAND  = $env:FZF_DEFAULT_COMMAND
$env:FZF_ALT_C_COMMAND   = 'fd --type d --hidden --follow --exclude .git'

# === Shell history search (Ctrl+R) — loaded after PSFzf so atuin wins ===
Invoke-Expression (& { (atuin init powershell) -join "`n" })

# === Prompt (last so it can read state from everything above) ===
Invoke-Expression (&starship init powershell)

# === Editor / pager defaults (git keeps its own editor in ~/.gitconfig) ===
# Auto-detect editor in preference order: zed (personal) -> code (work) -> nvim
$env:EDITOR = if     (Get-Command zed  -ErrorAction SilentlyContinue) { 'zed --wait' }
              elseif (Get-Command code -ErrorAction SilentlyContinue) { 'code --wait' }
              else                                                     { 'nvim' }
$env:VISUAL = $env:EDITOR
$env:PAGER  = 'bat --paging=always --plain'

# === Drop-in replacements (interactive only; $PROFILE doesn't load in `pwsh -File` scripts) ===
# Bypass any of these with the original cmdlet (Get-ChildItem, Get-Process, Get-Content, ...)
# PowerShell resolves aliases before functions, so existing built-in aliases (ls, ps, cat)
# would otherwise shadow our replacements. Remove them first.
Remove-Item Alias:ls   -Force -ErrorAction SilentlyContinue
Remove-Item Alias:ps   -Force -ErrorAction SilentlyContinue
Remove-Item Alias:cat  -Force -ErrorAction SilentlyContinue

function ls   { eza --git --icons --group-directories-first @args }
function ll   { eza --git --icons -l --group-directories-first @args }
function la   { eza --git --icons -la --group-directories-first @args }
function lt   { eza --git --icons --tree --level 2 @args }
function ps   { procs @args }
function cat  { bat --paging=never @args }
function du   { dust @args }
function df   { duf @args }
function top  { btm @args }
function htop { btm @args }

# === Convenience launchers ===
function lg   { lazygit @args }
function lzd  { lazydocker @args }
