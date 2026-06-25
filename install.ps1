# install.ps1 — Claude Code DevSecOps config installer for Windows
# Usage: .\install.ps1 [-Mode minimal|full|update]
# Requires: PowerShell 5.1+ or PowerShell Core 7+
# Run as: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
#         .\install.ps1 -Mode full

#Requires -Version 5.1

[CmdletBinding()]
param(
    [ValidateSet("minimal","full","update")]
    [string]$Mode = "full",

    [string]$RepoPath = "$PSScriptRoot",

    # Skip Go build (if binaries already present)
    [switch]$SkipGoBuild,

    # Skip VS Codium setup
    [switch]$SkipVSCodium
)

$ErrorActionPreference = "Continue"  # fail-open: log errors, don't abort

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-OK   { param([string]$msg) Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn { param([string]$msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err  { param([string]$msg) Write-Host "[ERR]  $msg" -ForegroundColor Red }
function Write-Info { param([string]$msg) Write-Host "[..]   $msg" -ForegroundColor Cyan }
function Write-Hdr  { param([string]$msg) Write-Host "`n==> $msg" -ForegroundColor White -BackgroundColor DarkBlue }

$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$Errors = 0

Write-Hdr "Claude Code Windows Installer (mode: $Mode)"

# ---------------------------------------------------------------------------
# 1. Prerequisites
# ---------------------------------------------------------------------------
Write-Hdr "Checking prerequisites"

function Check-Version {
    param([string]$Cmd, [int]$MinMajor, [int]$MinMinor, [string]$Label)
    $bin = Get-Command $Cmd -ErrorAction SilentlyContinue
    if (-not $bin) {
        Write-Warn "$Label not found"
        return "missing"
    }
    try {
        $verOutput = & $Cmd --version 2>&1 | Select-String -Pattern '\d+\.\d+' | Select-Object -First 1
        if ($verOutput -match '(\d+)\.(\d+)') {
            $major = [int]$Matches[1]; $minor = [int]$Matches[2]
            if ($major -gt $MinMajor -or ($major -eq $MinMajor -and $minor -ge $MinMinor)) {
                Write-OK "$Label $major.$minor"
                return "ok"
            } else {
                Write-Warn "$Label $major.$minor found, need ${MinMajor}.${MinMinor}+"
                return "old"
            }
        }
    } catch { }
    Write-OK "$Label (version unknown)"
    return "ok"
}

$GoStatus     = Check-Version "go"      1  24 "Go"
$PyStatus     = Check-Version "python"  3  10 "Python"
$NodeStatus   = Check-Version "node"    18  0 "Node.js"
$NpmStatus    = Check-Version "npm"      8  0 "npm"

$ClaudeStatus = "missing"
if (Get-Command "claude" -ErrorAction SilentlyContinue) {
    Write-OK "claude CLI found"
    $ClaudeStatus = "ok"
} else {
    Write-Warn "claude CLI not found — install: npm install -g @anthropic-ai/claude-code"
}

# ---------------------------------------------------------------------------
# 2. Directory structure
# ---------------------------------------------------------------------------
Write-Hdr "Creating directory structure"

$Dirs = @(
    "$ClaudeDir\hooks",
    "$ClaudeDir\agents",
    "$ClaudeDir\skills",
    "$ClaudeDir\rules",
    "$ClaudeDir\modules",
    "$ClaudeDir\mcp-servers",
    "$ClaudeDir\templates",
    "$ClaudeDir\workflows",
    "$ClaudeDir\evaluation",
    "$ClaudeDir\agent-memory",
    "$ClaudeDir\output-styles",
    "$ClaudeDir\prompts",
    "$ClaudeDir\projects",
    "$env:USERPROFILE\claude-workspaces\agent_work_directory",
    "$env:USERPROFILE\claude-workspaces\pentest",
    "$env:USERPROFILE\claude-workspaces\osint",
    "$env:USERPROFILE\claude-workspaces\devops",
    "$env:USERPROFILE\claude-workspaces\dfir",
    "$env:USERPROFILE\claude-workspaces\reverse",
    "$env:USERPROFILE\claude-workspaces\ml",
    "$env:USERPROFILE\claude-workspaces\compliance",
    "$env:USERPROFILE\claude-workspaces\business"
)

foreach ($d in $Dirs) {
    if (-not (Test-Path $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
        Write-OK "Created $d"
    } else {
        Write-Info "Exists  $d"
    }
}

# ---------------------------------------------------------------------------
# 3. Copy config files from repo
# ---------------------------------------------------------------------------
Write-Hdr "Copying config from repo: $RepoPath"

# Files/dirs to copy from repo to ~/.claude/
# Only copies if source exists in repo — idempotent (overwrites on --update)
$CopyMap = @{
    "hooks"        = "$ClaudeDir\hooks"
    "rules"        = "$ClaudeDir\rules"
    "modules"      = "$ClaudeDir\modules"
    "agents"       = "$ClaudeDir\agents"
    "skills"       = "$ClaudeDir\skills"
    "output-styles"= "$ClaudeDir\output-styles"
    "workflows"    = "$ClaudeDir\workflows"
    "templates"    = "$ClaudeDir\templates"
    "prompts"      = "$ClaudeDir\prompts"
    "mcp-servers"  = "$ClaudeDir\mcp-servers"
}

# Single files (not dirs)
$SingleFiles = @(
    @{ Src = "CLAUDE.md";          Dst = "$ClaudeDir\CLAUDE.md" },
    @{ Src = "CORE_INSTRUCTIONS.md"; Dst = "$ClaudeDir\CORE_INSTRUCTIONS.md" },
    @{ Src = "MEMORY.md";          Dst = "$ClaudeDir\MEMORY.md" }
)

foreach ($entry in $CopyMap.GetEnumerator()) {
    $src = Join-Path $RepoPath $entry.Key
    if (Test-Path $src) {
        # For --update: overwrite. For --full/--minimal: only copy if missing.
        if ($Mode -eq "update" -or -not (Test-Path $entry.Value)) {
            try {
                Copy-Item -Path $src -Destination $entry.Value -Recurse -Force
                Write-OK "Copied $($entry.Key) -> $($entry.Value)"
            } catch {
                Write-Warn "Could not copy $($entry.Key): $_"
            }
        } else {
            Write-Info "Skip (exists) $($entry.Value) — use -Mode update to overwrite"
        }
    } else {
        Write-Info "Not in repo: $src — skipping"
    }
}

foreach ($f in $SingleFiles) {
    $src = Join-Path $RepoPath $f.Src
    if (Test-Path $src) {
        if ($Mode -eq "update" -or -not (Test-Path $f.Dst)) {
            Copy-Item -Path $src -Destination $f.Dst -Force
            Write-OK "Copied $($f.Src)"
        } else {
            Write-Info "Skip (exists) $($f.Dst)"
        }
    }
}

# settings.json — NEVER overwrite
$SettingsPath = "$ClaudeDir\settings.json"
if (Test-Path $SettingsPath) {
    Write-Info "settings.json exists — NOT overwriting (merge manually if needed)"
} else {
    $SettingsSrc = Join-Path $RepoPath "settings.json"
    if (Test-Path $SettingsSrc) {
        Copy-Item -Path $SettingsSrc -Destination $SettingsPath
        Write-OK "Copied initial settings.json"
    } else {
        Write-Info "No settings.json in repo — you must create one manually"
    }
}

# ---------------------------------------------------------------------------
# 4. Python wrapper: claude-wrapper.ps1
# ---------------------------------------------------------------------------
Write-Hdr "Creating PowerShell claude wrapper"

$WrapperPath = "$ClaudeDir\claude-wrapper.ps1"
$WrapperContent = @'
# claude-wrapper.ps1 — Windows wrapper for claude CLI
# Injects CORE_INSTRUCTIONS.md as system prompt (equivalent to Linux bash wrapper)
# Usage: claude-wrapper.ps1 [claude-args...]
# Add to $PROFILE: function cc { & "$env:USERPROFILE\.claude\claude-wrapper.ps1" @args }

$CoreInstructions = Join-Path $env:USERPROFILE ".claude\CORE_INSTRUCTIONS.md"

if (-not (Test-Path $CoreInstructions)) {
    Write-Error "CORE_INSTRUCTIONS.md not found at $CoreInstructions"
    exit 1
}

& claude --append-system-prompt-file $CoreInstructions @args
'@

if (-not (Test-Path $WrapperPath) -or $Mode -eq "update") {
    Set-Content -Path $WrapperPath -Value $WrapperContent -Encoding UTF8
    Write-OK "Created claude-wrapper.ps1 at $WrapperPath"
} else {
    Write-Info "claude-wrapper.ps1 already exists"
}

# Offer to add alias to PowerShell profile
$ProfileSnippet = @"

# Claude Code wrapper (added by install.ps1)
function cc { & "`$env:USERPROFILE\.claude\claude-wrapper.ps1" @args }
"@

if ($Mode -ne "minimal") {
    if (Test-Path $PROFILE) {
        $profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
        if ($profileContent -notmatch "claude-wrapper") {
            Add-Content -Path $PROFILE -Value $ProfileSnippet -Encoding UTF8
            Write-OK "Added 'cc' alias to PowerShell profile: $PROFILE"
        } else {
            Write-Info "PowerShell profile already has claude-wrapper alias"
        }
    } else {
        # Create profile directory if needed
        $profileDir = Split-Path $PROFILE
        if (-not (Test-Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }
        Set-Content -Path $PROFILE -Value $ProfileSnippet -Encoding UTF8
        Write-OK "Created PowerShell profile with 'cc' alias: $PROFILE"
    }
}

# ---------------------------------------------------------------------------
# 5. Python dependencies
# ---------------------------------------------------------------------------
Write-Hdr "Installing Python dependencies"

if ($PyStatus -eq "missing") {
    Write-Warn "Python not found — skipping pip installs"
    $Errors++
} else {
    # portalocker: cross-platform file locking (required on Windows for compat.py)
    $pipResult = & python -m pip show portalocker 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Info "portalocker already installed"
    } else {
        Write-Info "Installing portalocker..."
        & python -m pip install --quiet portalocker 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-OK "Installed portalocker"
        } else {
            Write-Warn "Could not install portalocker — file locking may not work"
            $Errors++
        }
    }
}

# ---------------------------------------------------------------------------
# 6. Build Go MCP servers (native Windows .exe)
# ---------------------------------------------------------------------------
Write-Hdr "Building Go MCP servers"

if ($SkipGoBuild) {
    Write-Info "Skipping Go build (-SkipGoBuild flag set)"
} elseif ($GoStatus -eq "missing" -or $GoStatus -eq "old") {
    Write-Warn "Go not available or too old — skipping MCP server builds"
    Write-Info "Install Go 1.24+ from: https://go.dev/dl/"
    $Errors++
} else {
    $McpServers = @("backlog-mcp","doctor-mcp","gc-mcp","profile-mcp","score-mcp","tools-mcp")

    foreach ($srv in $McpServers) {
        $srvDir = "$ClaudeDir\mcp-servers\$srv"
        $binary = "$srvDir\$srv.exe"

        if (-not (Test-Path $srvDir)) {
            Write-Warn "Not found: $srvDir — skipping"
            continue
        }

        # Idempotency: check if binary is newer than all .go sources
        $needsBuild = $true
        if (Test-Path $binary) {
            $binTime = (Get-Item $binary).LastWriteTime
            $goFiles = Get-ChildItem -Path $srvDir -Filter "*.go" -ErrorAction SilentlyContinue
            $newerSrc = $goFiles | Where-Object { $_.LastWriteTime -gt $binTime }
            if ($newerSrc.Count -eq 0) {
                Write-Info "Up-to-date: $srv (binary newer than sources)"
                $needsBuild = $false
            }
        }

        if ($needsBuild) {
            Write-Info "Building $srv..."
            Push-Location $srvDir
            try {
                $buildOutput = & go build -ldflags="-s -w" -o "$srv.exe" . 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-OK "Built $srv.exe"
                } else {
                    Write-Err "Failed to build $srv`: $buildOutput"
                    $Errors++
                }
            } catch {
                Write-Err "Exception building $srv`: $_"
                $Errors++
            } finally {
                Pop-Location
            }
        }
    }
}

# ---------------------------------------------------------------------------
# 7. Configure ~/.claude.json MCP server paths (Windows absolute paths)
# ---------------------------------------------------------------------------
Write-Hdr "Configuring MCP server paths in .claude.json"

$ClaudeJsonPath = Join-Path $env:USERPROFILE ".claude.json"

function Update-ClaudeJson {
    param([string]$JsonPath, [string]$ClaudeDir)

    # Essential servers: Go binaries get .exe paths; external servers via npx
    $mcpServers = @{
        "backlog-mcp"  = @{ command = "$ClaudeDir\mcp-servers\backlog-mcp\backlog-mcp.exe"; args = @() }
        "doctor-mcp"   = @{ command = "$ClaudeDir\mcp-servers\doctor-mcp\doctor-mcp.exe";  args = @() }
        "gc-mcp"       = @{ command = "$ClaudeDir\mcp-servers\gc-mcp\gc-mcp.exe";          args = @() }
        "profile-mcp"  = @{ command = "$ClaudeDir\mcp-servers\profile-mcp\profile-mcp.exe"; args = @() }
        "score-mcp"    = @{ command = "$ClaudeDir\mcp-servers\score-mcp\score-mcp.exe";    args = @() }
        "tools-mcp"    = @{ command = "$ClaudeDir\mcp-servers\tools-mcp\tools-mcp.exe";    args = @() }
        "github"       = @{ command = "npx"; args = @("-y", "@modelcontextprotocol/server-github") }
        "filesystem"   = @{ command = "npx"; args = @("-y", "@modelcontextprotocol/server-filesystem", $env:USERPROFILE) }
        "fetch"        = @{ command = "npx"; args = @("-y", "@anthropic-ai/mcp-server-fetch") }
        "memory"       = @{ command = "npx"; args = @("-y", "@modelcontextprotocol/server-memory") }
        "git"          = @{ command = "uvx"; args = @("mcp-server-git") }
        "sequential-thinking" = @{ command = "npx"; args = @("-y", "@modelcontextprotocol/server-sequential-thinking") }
        "sqlite"       = @{ command = "uvx"; args = @("mcp-server-sqlite") }
    }

    $config = @{ projects = @{ "*" = @{ mcpServers = @{} } } }

    # Load existing config if present
    if (Test-Path $JsonPath) {
        try {
            $existing = Get-Content $JsonPath -Raw | ConvertFrom-Json
            # Merge: preserve existing, add/update Go binary paths
            if ($existing.projects -and $existing.projects."*" -and $existing.projects."*".mcpServers) {
                # Convert PSCustomObject to hashtable for merging
                $existingServers = @{}
                $existing.projects."*".mcpServers.PSObject.Properties | ForEach-Object {
                    $existingServers[$_.Name] = $_.Value
                }
                # Merge — our paths win for Go servers
                foreach ($key in $mcpServers.Keys) {
                    $existingServers[$key] = $mcpServers[$key]
                }
                $config.projects."*".mcpServers = $existingServers
            } else {
                $config.projects."*".mcpServers = $mcpServers
            }
        } catch {
            Write-Warn "Could not parse existing .claude.json — will create new"
            $config.projects."*".mcpServers = $mcpServers
        }
    } else {
        $config.projects."*".mcpServers = $mcpServers
    }

    $config | ConvertTo-Json -Depth 10 | Set-Content -Path $JsonPath -Encoding UTF8
}

if ($Mode -ne "minimal") {
    try {
        Update-ClaudeJson -JsonPath $ClaudeJsonPath -ClaudeDir $ClaudeDir
        Write-OK "Updated .claude.json with Windows MCP server paths"
    } catch {
        Write-Warn "Could not update .claude.json: $_"
        $Errors++
    }
}

# ---------------------------------------------------------------------------
# 8. GITHUB_TOKEN environment variable
# ---------------------------------------------------------------------------
Write-Hdr "GitHub token setup"

$existingToken = [System.Environment]::GetEnvironmentVariable("GITHUB_TOKEN", "User")
if ($existingToken) {
    Write-Info "GITHUB_TOKEN already set in user environment"
} else {
    Write-Warn "GITHUB_TOKEN not set in user environment"
    Write-Info "Set it with: [System.Environment]::SetEnvironmentVariable('GITHUB_TOKEN', '<token>', 'User')"
    Write-Info "Or run: `$env:GITHUB_TOKEN = '<token>'  (current session only)"
}

# Critical env vars for Claude Code — set at user level for extension compatibility
# (workaround for Issue #21926 — settings.json env block not loaded by extension)
$EnvVars = @{
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" = "1"
    "BASH_DEFAULT_TIMEOUT_MS"              = "300000"
    "API_TIMEOUT_MS"                       = "600000"
    "CLAUDE_CODE_MAX_OUTPUT_TOKENS"        = "64000"
    "SLASH_COMMAND_TOOL_CHAR_BUDGET"       = "8000"
}

if ($Mode -eq "full" -or $Mode -eq "update") {
    foreach ($kv in $EnvVars.GetEnumerator()) {
        $current = [System.Environment]::GetEnvironmentVariable($kv.Key, "User")
        if (-not $current) {
            [System.Environment]::SetEnvironmentVariable($kv.Key, $kv.Value, "User")
            Write-OK "Set env var: $($kv.Key)=$($kv.Value)"
        } else {
            Write-Info "Env var already set: $($kv.Key)=$current"
        }
    }
}

# ---------------------------------------------------------------------------
# 9. VS Codium / VS Code setup
# ---------------------------------------------------------------------------
if (-not $SkipVSCodium) {
    Write-Hdr "VS Codium / VS Code extension setup"

    # Detect editors
    $EditorBin = $null
    $EditorName = ""
    foreach ($bin in @("codium","code","code-oss")) {
        if (Get-Command $bin -ErrorAction SilentlyContinue) {
            $EditorBin = $bin
            $EditorName = $bin
            Write-OK "Editor found: $bin"
            break
        }
    }

    # VS Codium config dir on Windows
    $VsConfigCandidates = @(
        "$env:APPDATA\VSCodium\User",
        "$env:APPDATA\Code\User",
        "$env:APPDATA\Code - OSS\User"
    )
    $VsConfigDir = $null
    foreach ($candidate in $VsConfigCandidates) {
        if (Test-Path $candidate) {
            $VsConfigDir = $candidate
            Write-Info "VS Codium config dir: $candidate"
            break
        }
    }

    if (-not $VsConfigDir -and $EditorBin) {
        # First-run: config dir may not exist yet — use the first candidate that matches
        if ($EditorName -eq "codium") {
            $VsConfigDir = "$env:APPDATA\VSCodium\User"
        } else {
            $VsConfigDir = "$env:APPDATA\Code\User"
        }
        New-Item -ItemType Directory -Path $VsConfigDir -Force | Out-Null
        Write-Info "Created VS config dir: $VsConfigDir"
    }

    if ($VsConfigDir) {
        $VsSettingsPath = "$VsConfigDir\settings.json"

        # Load or init settings
        $vsSettings = @{}
        if (Test-Path $VsSettingsPath) {
            try {
                $vsSettings = Get-Content $VsSettingsPath -Raw | ConvertFrom-Json
                # Convert PSCustomObject to hashtable
                $hash = @{}
                $vsSettings.PSObject.Properties | ForEach-Object { $hash[$_.Name] = $_.Value }
                $vsSettings = $hash
            } catch {
                Write-Warn "Could not parse VS Codium settings.json — will merge carefully"
                $vsSettings = @{}
            }
        }

        # Add/update claude-code env vars (Issue #21926 workaround)
        $vsSettings["claude-code.environmentVariables"] = @{
            "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" = "1"
            "BASH_DEFAULT_TIMEOUT_MS"              = "300000"
            "API_TIMEOUT_MS"                       = "600000"
            "CLAUDE_CODE_MAX_OUTPUT_TOKENS"        = "64000"
            "SLASH_COMMAND_TOOL_CHAR_BUDGET"       = "8000"
        }

        # Set claude binary path explicitly (ensures extension finds the CLI)
        if (Get-Command "claude" -ErrorAction SilentlyContinue) {
            $claudePath = (Get-Command "claude").Source
            $vsSettings["claude-code.claudePath"] = $claudePath
            Write-Info "claude binary path: $claudePath"
        }

        try {
            $vsSettings | ConvertTo-Json -Depth 5 | Set-Content -Path $VsSettingsPath -Encoding UTF8
            Write-OK "Updated VS Codium settings.json: $VsSettingsPath"
        } catch {
            Write-Warn "Could not write VS Codium settings.json: $_"
        }

        # Install extension via CLI
        if ($EditorBin) {
            Write-Info "Installing Claude Code extension via $EditorBin..."
            & $EditorBin --install-extension anthropic.claude-code --force 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-OK "Claude Code extension installed via $EditorBin"
            } else {
                Write-Warn "Could not auto-install extension — install manually:"
                Write-Info "  $EditorBin --install-extension anthropic.claude-code"
            }
        }
    } else {
        Write-Info "No VS Codium/VS Code detected — skipping extension setup"
    }
}

# ---------------------------------------------------------------------------
# 10. Validate settings.json
# ---------------------------------------------------------------------------
Write-Hdr "Validating settings.json"

if (Test-Path $SettingsPath) {
    try {
        $null = Get-Content $SettingsPath -Raw | ConvertFrom-Json
        Write-OK "settings.json is valid JSON"
    } catch {
        Write-Err "settings.json has invalid JSON: $_"
        $Errors++
    }
} else {
    Write-Warn "settings.json not present — skipping validation"
}

# ---------------------------------------------------------------------------
# 11. Summary
# ---------------------------------------------------------------------------
Write-Hdr "Summary"

Write-Host ""
Write-Host ("  {0,-25} {1}" -f "Go:",       $GoStatus)
Write-Host ("  {0,-25} {1}" -f "Python:",    $PyStatus)
Write-Host ("  {0,-25} {1}" -f "Node/npm:",  "$NodeStatus / $NpmStatus")
Write-Host ("  {0,-25} {1}" -f "claude CLI:",$ClaudeStatus)
Write-Host ("  {0,-25} {1}" -f "Mode:",      $Mode)
Write-Host ""

if ($Errors -eq 0) {
    Write-Host "Installation complete — no errors." -ForegroundColor Green
} else {
    Write-Host "Done with $Errors warning(s) — review output above." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next steps:"
if ($ClaudeStatus -eq "missing") {
    Write-Host "  npm install -g @anthropic-ai/claude-code"
}
Write-Host "  claude mcp list                      # verify MCP servers"
Write-Host "  claude doctor                        # full health check"
Write-Host "  . `$PROFILE                           # reload profile for 'cc' alias"
Write-Host "  cc                                   # launch Claude with core instructions"
Write-Host ""
Write-Host "Windows notes:"
Write-Host "  - Hook commands in settings.json need python3 -> python (see docs/WINDOWS_PORTING_V2.md)"
Write-Host "  - fcntl hooks need compat.py (see docs/WINDOWS_PORTING_V2.md §2)"
Write-Host "  - Run .\setup-vscodium.sh via Git Bash, or use VS Codium section above"
Write-Host ""
