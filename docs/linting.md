# Linting Guide

This project uses multiple linting tools to ensure code quality. Each tool serves a specific purpose:

| Tool | Purpose | Language |
|------|---------|----------|
| **selene** | Lua linter - catches bugs, unused variables, style issues | Lua |
| **stylua** | Lua formatter - enforces consistent style | Lua |
| **ast-grep** | Structural pattern linter - catches code patterns | Lua, Python |

## Quick Start

```powershell
# Run all linters (check mode)
.\lint.ps1

# Run all linters and auto-fix formatting
.\lint.ps1 -Fix

# Run only ast-grep
.\lint.ps1 -AstGrepOnly
```

On Unix/Mac:
```bash
./lint.sh
./lint.sh --fix
./lint.sh --ast
```

## Installation

### Aftman (Recommended for Roblox tools)

```bash
# Install aftman first: https://github.com/LPGhatguy/aftman
aftman install
```

This installs `rojo`, `selene`, and `stylua` from `aftman.toml`.

### ast-grep Installation

ast-grep is not available via Aftman. Install using one of:

```bash
# npm (easiest)
npm install -g @ast-grep/cli

# pip (Python)
pip install ast-grep-cli

# cargo (Rust)
cargo install ast-grep --locked
```

Verify installation:
```bash
ast-grep --version
```

## What Each Tool Does

### Selene

Traditional Lua linter. Catches:
- Unused variables
- Undefined globals
- Style violations
- Common Lua mistakes

Configuration: `selene.toml`

```bash
selene .
```

### StyLua

Lua code formatter. Enforces:
- Consistent indentation (tabs)
- Line length limits
- Quote style
- Parentheses usage

Configuration: `stylua.toml`

```bash
stylua --check .   # Check mode
stylua .           # Fix mode
```

### ast-grep

**Structural pattern linter.** This is the key differentiator. While selene looks at individual language constructs, ast-grep matches patterns across the AST (Abstract Syntax Tree).

Configuration: `sgconfig.yml` + `rules/` directory

```bash
ast-grep scan      # Run all rules
ast-grep scan -r no-print-debug   # Run specific rule
ast-grep test      # Run rule tests
```

## ast-grep Rules

Rules are organized by language:

```
rules/
├── lua/
│   ├── no-print-debug.yml      # Catch debug prints
│   ├── no-wait-in-loop.yml     # Catch wait() in loops
│   ├── no-deprecated-wait.yml  # Suggest task.wait()
│   ├── no-spawn-deprecated.yml # Suggest task.spawn()
│   ├── terrain-operations.yml  # Project-specific patterns
│   └── ...
└── python/
    ├── no-bare-except.yml      # Catch bare except:
    ├── no-mutable-default.yml  # Catch def foo(x=[])
    └── ...
```

### Rule Severity Levels

| Level | Meaning |
|-------|---------|
| `error` | Must be fixed. Blocks CI. |
| `warning` | Should be fixed. May indicate bugs. |
| `hint` | Consider fixing. Style suggestions. |

### Writing Custom Rules

Create a YAML file in `rules/lua/` or `rules/python/`:

```yaml
id: my-custom-rule
language: lua
severity: warning
message: "Description of the issue"
note: "How to fix it"
rule:
  pattern: some_pattern($$$ARGS)
```

Pattern syntax:
- `$VAR` - matches any single AST node
- `$$$VAR` - matches zero or more nodes (variadic)
- `$_` - matches any node (anonymous)

Test your rule:
```bash
# Interactive testing
ast-grep scan --rule my-custom-rule

# Or use the playground: https://ast-grep.github.io/playground.html
```

## ast-grep vs Selene

| Feature | Selene | ast-grep |
|---------|--------|----------|
| Type | Traditional linter | Structural pattern matcher |
| Rules | Pre-defined | Custom YAML patterns |
| Patterns | No | Yes - match code structure |
| Auto-fix | No | Yes (via `fix:` field) |
| Languages | Lua only | Multi-language |

**Use both!** They complement each other:
- Selene catches standard Lua issues
- ast-grep catches project-specific patterns

## CI Integration

Linting runs automatically on push/PR via GitHub Actions (`.github/workflows/lint.yml`).

The CI will fail if:
- Any `error` severity rules are triggered
- Selene finds issues
- StyLua formatting check fails

## Disabling Rules

### ast-grep

Add to `sgconfig.yml`:
```yaml
# Exclude specific files or directories
ignores:
  - "Packages/**"
  - "*_test.lua"
```

### Selene

Add to `selene.toml`:
```toml
[lints]
some_rule = "allow"
```

Or inline:
```lua
-- selene: allow(unused_variable)
local unused = 123
```

### StyLua

Use `stylua.toml` for global settings, or:
```lua
-- stylua: ignore
local ugly_but_intentional = { 1,2,3 }
```

## Troubleshooting

### ast-grep not finding rules

Check that `sgconfig.yml` exists and `ruleDirs` points to correct location:
```yaml
ruleDirs:
  - rules
```

### Selene reporting Roblox globals as undefined

Ensure `selene.toml` has:
```toml
std = "roblox"
```

### StyLua not matching project style

Check `stylua.toml` settings, especially:
- `indent_type`
- `column_width`
- `quote_style`

