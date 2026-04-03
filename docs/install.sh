#!/bin/sh
set -e

REPO="gogostock1227-sys/backtester-skill"
SKILL_SRC="skills/backtester"
SKILL_NAME="backtester"

# --- Colors ---
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

info()  { printf "${CYAN}%s${RESET}\n" "$1"; }
ok()    { printf "${GREEN}%s${RESET}\n" "$1"; }
warn()  { printf "${YELLOW}%s${RESET}\n" "$1"; }
err()   { printf "${RED}%s${RESET}\n" "$1" >&2; }

# --- Detect installed AI CLIs ---
TARGETS=""
command -v claude   >/dev/null 2>&1 && TARGETS="$TARGETS claude-code"
command -v codex    >/dev/null 2>&1 && TARGETS="$TARGETS codex"
command -v cursor   >/dev/null 2>&1 && TARGETS="$TARGETS cursor"
command -v windsurf >/dev/null 2>&1 && TARGETS="$TARGETS windsurf"
command -v gemini   >/dev/null 2>&1 && TARGETS="$TARGETS gemini-cli"
TARGETS=$(echo "$TARGETS" | xargs)

skill_dir() {
  case "$1" in
    claude-code) echo "$HOME/.claude/skills/$SKILL_NAME" ;;
    codex)       echo "$HOME/.codex/skills/$SKILL_NAME" ;;
    cursor)      echo "$HOME/.cursor/skills/$SKILL_NAME" ;;
    windsurf)    echo "$HOME/.windsurf/skills/$SKILL_NAME" ;;
    gemini-cli)  echo "$HOME/.gemini/skills/$SKILL_NAME" ;;
  esac
}

# --- Main ---
printf "\n${BOLD}  Backtester Skill Installer${RESET}\n"
printf "  ───────────────────────────\n\n"

if [ -z "$TARGETS" ]; then
  err "No supported AI CLI found."
  echo ""
  echo "  Please install one of:"
  echo "    - Claude Code:  npm install -g @anthropic-ai/claude-code"
  echo "    - Codex CLI:    npm install -g @openai/codex"
  echo "    - Cursor:       https://www.cursor.com/"
  echo "    - Windsurf:     https://windsurf.com/"
  echo "    - Gemini CLI:   npm install -g @google/gemini-cli"
  echo ""
  exit 1
fi

info "Detected: $TARGETS"

# --- Install Python dependencies ---
install_python_deps() {
  info "Checking Python dependencies..."

  # Check pip
  if ! command -v pip >/dev/null 2>&1 && ! command -v pip3 >/dev/null 2>&1; then
    warn "pip not found. Please install Python 3.10+ first."
    return 1
  fi

  PIP="pip"
  command -v pip3 >/dev/null 2>&1 && PIP="pip3"

  # Core packages
  $PIP install vectorbt pandas numpy matplotlib openpyxl pandas_ta 2>/dev/null && \
    ok "Core packages installed." || warn "Some packages failed — install manually."

  # TA-Lib check
  if python3 -c "import talib" 2>/dev/null || python -c "import talib" 2>/dev/null; then
    ok "TA-Lib: already installed."
  else
    warn "TA-Lib not found."
    echo "  Install the C library first, then: pip install TA-Lib"
    echo "  Full guide: https://ta-lib.org/install/"
  fi
}

install_python_deps

# --- Try npx first ---
if command -v npx >/dev/null 2>&1; then
  info "Installing skill via npx for: $TARGETS"
  AGENT_FLAGS=""
  for t in $TARGETS; do
    AGENT_FLAGS="$AGENT_FLAGS -a $t"
  done
  if npx skills add "$REPO" $AGENT_FLAGS -y 2>/dev/null; then
    echo ""
    ok "Done! Backtester skill installed for: $TARGETS"
    echo ""
    echo "  Open any CLI and try: /backtester"
    echo ""
    exit 0
  fi
  warn "npx method failed, falling back to git clone..."
fi

# --- Fallback: git clone ---
if ! command -v git >/dev/null 2>&1; then
  err "git is not installed. Please install git or Node.js and try again."
  exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
info "Cloning repository..."
git clone --depth 1 "https://github.com/$REPO.git" "$TMP/backtester-skill" 2>/dev/null

for t in $TARGETS; do
  DEST=$(skill_dir "$t")
  info "Installing for $t -> $DEST"
  mkdir -p "$(dirname "$DEST")"
  rm -rf "$DEST"
  cp -r "$TMP/backtester-skill/$SKILL_SRC" "$DEST"
done

echo ""
ok "Done! Backtester skill installed for: $TARGETS"
echo ""
echo "  Open any CLI and the backtester skill is ready."
echo ""
