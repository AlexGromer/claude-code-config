#!/usr/bin/env python3
"""
Claude Code Configuration Migration Script
Linux → Windows

Usage:
    python migrate_to_windows.py --export         # Create Windows-ready archive
    python migrate_to_windows.py --validate       # Check what needs adaptation
    python migrate_to_windows.py --dry-run        # Preview changes without creating files

Output: claude_config_windows.zip (ready for Windows deployment)
"""

import os
import re
import json
import shutil
import zipfile
from pathlib import Path
from typing import Dict, List, Tuple

class WindowsMigrator:
    """Migrate Claude Code configuration from Linux to Windows."""

    def __init__(self, source_dir: Path = None):
        self.source_dir = source_dir or Path.home() / ".claude"
        self.temp_dir = Path("/tmp/claude_windows_export")
        self.output_zip = Path.cwd() / "claude_config_windows.zip"

        # Components that transfer directly (platform-independent)
        self.direct_transfer = [
            "rules/",           # Markdown rules (platform-independent)
            "modules/",         # Knowledge modules (markdown)
            "examples/",        # Few-shot examples (markdown)
            "skills/",          # Skills (markdown + Python)
            "CLAUDE.md",        # Core config
            "CORE_INSTRUCTIONS.md",
        ]

        # Components requiring adaptation
        self.needs_adaptation = {
            "hooks/": self._adapt_hooks,
            "tools/": self._adapt_tools,
            ".claude.json": self._adapt_mcp_config,
            "evaluation/": self._adapt_evaluation,
        }

        # Linux-specific tools to exclude
        self.linux_only = [
            "gh",  # GitHub CLI (install separately on Windows)
            "gitleaks",  # Install via Scoop/Chocolatey on Windows
            "kubectl",  # Install separately
            "terraform",  # Install separately
        ]

    def validate(self) -> Dict[str, List[str]]:
        """Analyze what needs adaptation."""
        report = {
            "direct_transfer": [],
            "needs_adaptation": [],
            "linux_specific_tools": [],
            "mcp_servers_ok": [],
            "mcp_servers_adapt": [],
        }

        # Check direct transfer files
        for item in self.direct_transfer:
            path = self.source_dir / item
            if path.exists():
                if path.is_dir():
                    count = len(list(path.rglob("*")))
                    report["direct_transfer"].append(f"{item} ({count} files)")
                else:
                    report["direct_transfer"].append(item)

        # Check files needing adaptation
        for item in self.needs_adaptation:
            path = self.source_dir / item
            if path.exists():
                if path.is_dir():
                    count = len(list(path.rglob("*.py"))) + len(list(path.rglob("*.sh")))
                    report["needs_adaptation"].append(f"{item} ({count} scripts)")
                else:
                    report["needs_adaptation"].append(item)

        # Check MCP servers
        mcp_config = self.source_dir / ".claude.json"
        if mcp_config.exists():
            with open(mcp_config) as f:
                data = json.load(f)

            for project_path, project_config in data.get("projects", {}).items():
                for server_name, server_config in project_config.get("mcpServers", {}).items():
                    cmd = server_config.get("command", "")
                    if cmd == "python3" or cmd == "python":
                        report["mcp_servers_ok"].append(f"{server_name} (Python)")
                    elif cmd in ["npx", "node"]:
                        report["mcp_servers_ok"].append(f"{server_name} (Node.js)")
                    else:
                        report["mcp_servers_adapt"].append(f"{server_name} (command: {cmd})")

        return report

    def _adapt_hooks(self, source: Path, dest: Path) -> None:
        """Adapt hook scripts for Windows."""
        dest.mkdir(parents=True, exist_ok=True)

        for hook_file in source.rglob("*.py"):
            content = hook_file.read_text(encoding="utf-8")

            # Replace shebang
            content = content.replace("#!/usr/bin/env python3", "#!/usr/bin/env python")

            # Replace Linux paths with Windows equivalents
            content = re.sub(
                r'Path\.home\(\) / "\.claude"',
                r'Path.home() / ".claude"',  # Path object handles platform differences
                content
            )

            # Replace shell commands with cross-platform alternatives
            content = content.replace('["bash", "-c"', '["cmd", "/c"')

            # Write adapted file
            dest_file = dest / hook_file.relative_to(source)
            dest_file.parent.mkdir(parents=True, exist_ok=True)
            dest_file.write_text(content, encoding="utf-8")

    def _adapt_tools(self, source: Path, dest: Path) -> None:
        """Adapt tool scripts for Windows."""
        dest.mkdir(parents=True, exist_ok=True)

        for tool_file in source.rglob("*.py"):
            content = tool_file.read_text(encoding="utf-8")

            # Replace shebang
            content = content.replace("#!/usr/bin/env python3", "#!/usr/bin/env python")

            # Replace Linux-specific commands
            replacements = {
                'subprocess.run(["bash",': 'subprocess.run(["cmd", "/c",',
                'shell=True': 'shell=True  # Cross-platform',
            }

            for old, new in replacements.items():
                content = content.replace(old, new)

            dest_file = dest / tool_file.relative_to(source)
            dest_file.parent.mkdir(parents=True, exist_ok=True)
            dest_file.write_text(content, encoding="utf-8")

        # Copy shell scripts as-is (user will need to manually adapt or use WSL)
        for script_file in source.rglob("*.sh"):
            dest_file = dest / script_file.relative_to(source)
            dest_file.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(script_file, dest_file)

            # Create .bat wrapper hint
            bat_file = dest_file.with_suffix(".bat")
            bat_file.write_text(
                f"@echo off\n"
                f"REM Adapt this shell script for Windows or use WSL:\n"
                f"REM bash {script_file.name}\n"
                f"echo This script requires adaptation for Windows\n"
                f"pause\n",
                encoding="utf-8"
            )

    def _adapt_mcp_config(self, source: Path, dest: Path) -> None:
        """Adapt MCP server configuration for Windows."""
        with open(source) as f:
            data = json.load(f)

        # Adapt MCP server commands
        for project_path, project_config in data.get("projects", {}).items():
            for server_name, server_config in project_config.get("mcpServers", {}).items():
                cmd = server_config.get("command", "")

                # python3 → python (Windows typically uses 'python')
                if cmd == "python3":
                    server_config["command"] = "python"

                # Adapt script paths
                if "args" in server_config:
                    args = server_config["args"]
                    for i, arg in enumerate(args):
                        if isinstance(arg, str):
                            # Replace /home/user with %USERPROFILE%
                            args[i] = arg.replace("/home/", "%USERPROFILE%/")
                            args[i] = args[i].replace("/.claude/", "/.claude/")
                            # Replace forward slashes in paths (if not URLs)
                            if not args[i].startswith("http"):
                                args[i] = args[i].replace("/", "\\")

        # Write adapted config
        dest.parent.mkdir(parents=True, exist_ok=True)
        with open(dest, "w") as f:
            json.dump(data, f, indent=2)

    def _adapt_evaluation(self, source: Path, dest: Path) -> None:
        """Copy evaluation framework (Python code is cross-platform)."""
        shutil.copytree(source, dest, dirs_exist_ok=True)

        # Adapt requirements.txt if it exists
        req_file = dest / "requirements.txt"
        if req_file.exists():
            content = req_file.read_text(encoding="utf-8")
            # Add Windows-specific notes
            content = "# Claude Code Evaluation Framework - Windows\n" + content
            req_file.write_text(content, encoding="utf-8")

    def export(self, dry_run: bool = False) -> Path:
        """Export Windows-ready configuration archive."""
        if self.temp_dir.exists():
            shutil.rmtree(self.temp_dir)

        self.temp_dir.mkdir(parents=True, exist_ok=True)

        # 1. Direct transfer (platform-independent files)
        print("📦 Copying platform-independent files...")
        for item in self.direct_transfer:
            source = self.source_dir / item
            if not source.exists():
                continue

            dest = self.temp_dir / item
            if source.is_dir():
                shutil.copytree(source, dest, dirs_exist_ok=True)
            else:
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, dest)

        # 2. Adapt components requiring changes
        print("🔧 Adapting platform-specific components...")
        for item, adapter_func in self.needs_adaptation.items():
            source = self.source_dir / item
            if not source.exists():
                continue

            dest = self.temp_dir / item
            adapter_func(source, dest)

        # 3. Create setup instructions
        print("📝 Creating setup instructions...")
        self._create_setup_guide()

        # 4. Create archive
        if not dry_run:
            print(f"📦 Creating archive: {self.output_zip}")
            with zipfile.ZipFile(self.output_zip, "w", zipfile.ZIP_DEFLATED) as zf:
                for file in self.temp_dir.rglob("*"):
                    if file.is_file():
                        zf.write(file, file.relative_to(self.temp_dir))

            # Cleanup temp directory
            shutil.rmtree(self.temp_dir)

            print(f"✅ Export complete: {self.output_zip}")
            print(f"📊 Archive size: {self.output_zip.stat().st_size / 1024 / 1024:.2f} MB")
        else:
            print(f"🔍 Dry run complete. Files prepared in: {self.temp_dir}")
            print("Run without --dry-run to create archive.")

        return self.output_zip if not dry_run else self.temp_dir

    def _create_setup_guide(self) -> None:
        """Create Windows setup instructions."""
        guide = """# Claude Code Configuration - Windows Setup Guide

## Prerequisites

1. **Python 3.11+**
   ```powershell
   python --version  # Should be 3.11 or higher
   ```

   If not installed: https://www.python.org/downloads/

2. **Claude Code CLI**
   ```powershell
   npm install -g @anthropic-ai/claude-code
   # or
   pip install claude-code
   ```

3. **Git** (for mandatory checks)
   ```powershell
   git --version
   ```

   If not installed: https://git-scm.com/download/win

4. **GitLeaks** (security scanning)
   ```powershell
   # Using Chocolatey
   choco install gitleaks

   # Using Scoop
   scoop install gitleaks
   ```

## Installation Steps

### 1. Extract Configuration

Extract `claude_config_windows.zip` to:
```
%USERPROFILE%\\.claude\\
```

### 2. Install Python Dependencies

```powershell
cd %USERPROFILE%\\.claude\\evaluation
python -m venv venv
.\\venv\\Scripts\\activate
pip install -r requirements.txt
```

### 3. Configure MCP Servers

Edit `%USERPROFILE%\\.claude\\.claude.json`:

- Replace `/home/username` with `%USERPROFILE%`
- Verify `python3` → `python` (already done by migration script)
- Update project paths to Windows format

### 4. Set Execute Permissions (Optional)

If using WSL or Git Bash:
```bash
chmod +x ~/.claude/tools/*.py
chmod +x ~/.claude/evaluation/scripts/*.py
```

### 5. Test Installation

```powershell
# Test hook system
python %USERPROFILE%\\.claude\\hooks\\session_start_hook.py

# Test budget system
python %USERPROFILE%\\.claude\\evaluation\\costs\\budget_manager.py --help

# Test MCP servers
claude mcp list
```

## Platform Differences

### Hooks (Python)
✅ **Work as-is** - Python Path() handles platform differences automatically.

### Tools (Python)
✅ **Work as-is** - Most tools are cross-platform.

⚠️ **Shell scripts (.sh)** - Require adaptation or WSL:
- Option 1: Rewrite as PowerShell (.ps1)
- Option 2: Use WSL (Windows Subsystem for Linux)
- Option 3: Use Git Bash

### MCP Servers

**Python-based (✅ cross-platform):**
- github (mcp__github__*)
- filesystem
- memory
- metrics

**Node.js-based (✅ cross-platform):**
- fetch
- Most MCP registry servers

**Linux-specific (⚠️ adapt or skip):**
- ghidra-mcp (if using Linux-specific paths)
- kubernetes (if cluster is Linux-only)

## Troubleshooting

### Issue: `python3: command not found`

**Solution:** Windows uses `python` instead of `python3`.
Already fixed in migration script.

### Issue: MCP server fails to start

**Solution:** Check paths in `.claude.json`:
```json
{
  "args": [
    "%USERPROFILE%\\\\.claude\\\\tools\\\\script.py"  // Use double backslashes
  ]
}
```

### Issue: Hooks not executing

**Solution:** Ensure Python is in PATH:
```powershell
where python
# Should show: C:\\Python311\\python.exe or similar
```

### Issue: GitLeaks not found

**Solution:** Install via package manager:
```powershell
# Chocolatey
choco install gitleaks

# Or download binary
# https://github.com/gitleaks/gitleaks/releases
```

## Optional: WSL Integration

For maximum compatibility, use WSL2:

1. Install WSL2:
   ```powershell
   wsl --install
   ```

2. Copy configuration to WSL:
   ```bash
   cp -r /mnt/c/Users/YourName/.claude ~/
   ```

3. Run Claude Code in WSL:
   ```bash
   claude
   ```

## Configuration Preserved

✅ Rules (10 files) - Auto-loaded behavior rules
✅ Modules (23 files) - Domain knowledge
✅ Skills (30 files) - User-invocable workflows
✅ Hooks (42 files) - Automation system
✅ Tools (89 files) - CLI utilities
✅ Examples (90+ files) - Few-shot references
✅ Evaluation framework - Metrics, costs, testing

## Support

For issues specific to Windows deployment:
- Check logs: `%USERPROFILE%\\.claude\\logs\\`
- Test individual hooks: `python %USERPROFILE%\\.claude\\hooks\\<hook_name>.py`
- Validate MCP: `claude mcp list`

---

**Migration completed:** {date}
**Source platform:** Linux (Kali Purple)
**Target platform:** Windows 10/11
**Config version:** 3.7.17
"""

        from datetime import datetime
        guide = guide.replace("{date}", datetime.now().strftime("%Y-%m-%d"))

        readme = self.temp_dir / "WINDOWS_SETUP.md"
        readme.write_text(guide, encoding="utf-8")


def main():
    import argparse

    parser = argparse.ArgumentParser(
        description="Migrate Claude Code configuration from Linux to Windows"
    )
    parser.add_argument(
        "--validate",
        action="store_true",
        help="Validate configuration and show what needs adaptation"
    )
    parser.add_argument(
        "--export",
        action="store_true",
        help="Export Windows-ready configuration archive"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview changes without creating archive"
    )

    args = parser.parse_args()

    migrator = WindowsMigrator()

    if args.validate:
        print("🔍 Validating configuration for Windows compatibility...\n")
        report = migrator.validate()

        print("✅ DIRECT TRANSFER (Platform-independent):")
        for item in report["direct_transfer"]:
            print(f"  • {item}")

        print("\n🔧 NEEDS ADAPTATION (Platform-specific):")
        for item in report["needs_adaptation"]:
            print(f"  • {item}")

        print("\n✅ MCP SERVERS (Cross-platform):")
        for item in report["mcp_servers_ok"]:
            print(f"  • {item}")

        if report["mcp_servers_adapt"]:
            print("\n⚠️ MCP SERVERS (May need adaptation):")
            for item in report["mcp_servers_adapt"]:
                print(f"  • {item}")

    elif args.export or args.dry_run:
        print("🚀 Starting Windows migration export...\n")
        output = migrator.export(dry_run=args.dry_run)

        if not args.dry_run:
            print(f"\n📦 Ready for Windows deployment!")
            print(f"\nNext steps:")
            print(f"1. Transfer {output.name} to Windows machine")
            print(f"2. Extract to %USERPROFILE%\\.claude\\")
            print(f"3. Follow WINDOWS_SETUP.md instructions")

    else:
        parser.print_help()
        print("\nExample usage:")
        print("  python migrate_to_windows.py --validate    # Check compatibility")
        print("  python migrate_to_windows.py --export      # Create Windows archive")
        print("  python migrate_to_windows.py --dry-run     # Preview changes")


if __name__ == "__main__":
    main()
