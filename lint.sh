#!/usr/bin/env bash
#
# Run all linting tools for the Terrain Editor project.
#
# Usage:
#   ./lint.sh           # Run all linters in check mode
#   ./lint.sh --fix     # Run linters and auto-fix stylua issues
#   ./lint.sh --ast     # Only run ast-grep
#   ./lint.sh --selene  # Only run selene
#   ./lint.sh --stylua  # Only run stylua
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

FIX_MODE=false
AST_ONLY=false
SELENE_ONLY=false
STYLUA_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --fix|-f)
            FIX_MODE=true
            shift
            ;;
        --ast|--ast-grep)
            AST_ONLY=true
            shift
            ;;
        --selene)
            SELENE_ONLY=true
            shift
            ;;
        --stylua)
            STYLUA_ONLY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN} $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

EXIT_CODE=0

# Check for ast-grep (can be 'ast-grep' or 'sg')
if command -v ast-grep &> /dev/null; then
    AST_GREP_CMD="ast-grep"
elif command -v sg &> /dev/null; then
    AST_GREP_CMD="sg"
else
    AST_GREP_CMD=""
fi

# ─────────────────────────────────────────────────────────────────────────────
# SELENE - Lua Linter
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$AST_ONLY" != "true" && "$STYLUA_ONLY" != "true" ]]; then
    print_header "Running Selene (Lua Linter)"
    
    if ! command -v selene &> /dev/null; then
        echo -e "  ${YELLOW}⚠ selene not installed, skipping${NC}"
    else
        if selene .; then
            echo -e "  ${GREEN}✓ Selene passed${NC}"
        else
            echo -e "  ${RED}✗ Selene found issues${NC}"
            EXIT_CODE=1
        fi
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# STYLUA - Lua Formatter
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$AST_ONLY" != "true" && "$SELENE_ONLY" != "true" ]]; then
    print_header "Running StyLua (Lua Formatter)"
    
    if ! command -v stylua &> /dev/null; then
        echo -e "  ${YELLOW}⚠ stylua not installed, skipping${NC}"
    else
        if [[ "$FIX_MODE" == "true" ]]; then
            echo -e "  Mode: ${YELLOW}Fix${NC}"
            if stylua .; then
                echo -e "  ${GREEN}✓ StyLua formatting applied${NC}"
            else
                echo -e "  ${RED}✗ StyLua encountered errors${NC}"
                EXIT_CODE=1
            fi
        else
            echo -e "  Mode: Check"
            if stylua --check .; then
                echo -e "  ${GREEN}✓ StyLua passed${NC}"
            else
                echo -e "  ${RED}✗ StyLua found formatting issues (run with --fix to auto-fix)${NC}"
                EXIT_CODE=1
            fi
        fi
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# AST-GREP - Structural Pattern Linter
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$SELENE_ONLY" != "true" && "$STYLUA_ONLY" != "true" ]]; then
    print_header "Running ast-grep (Structural Pattern Linter)"
    
    if [[ -z "$AST_GREP_CMD" ]]; then
        echo -e "  ${YELLOW}⚠ ast-grep not installed, skipping${NC}"
        echo -e "  ${YELLOW}  Install: npm install -g @ast-grep/cli${NC}"
    elif [[ ! -f "sgconfig.yml" ]]; then
        echo -e "  ${YELLOW}⚠ sgconfig.yml not found, skipping ast-grep${NC}"
    else
        if $AST_GREP_CMD scan; then
            echo -e "  ${GREEN}✓ ast-grep passed${NC}"
        else
            echo -e "  ${RED}✗ ast-grep found structural issues${NC}"
            EXIT_CODE=1
        fi
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
if [[ $EXIT_CODE -eq 0 ]]; then
    echo -e "${GREEN} All linters passed! ✓${NC}"
else
    echo -e "${RED} Some linters failed. Fix the issues above. ✗${NC}"
fi
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

exit $EXIT_CODE

