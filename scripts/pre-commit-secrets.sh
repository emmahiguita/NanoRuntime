#!/bin/bash
# ============================================================
# NanoAI pre-commit hook — detect secrets before commit
# Install: cp scripts/pre-commit-secrets.sh .git/hooks/pre-commit
# ============================================================
set -euo pipefail

# Patterns that indicate potential secrets
PATTERNS=(
    'sk-ant-[a-zA-Z0-9_-]{20,}'           # Anthropic API keys
    'sk-[a-zA-Z0-9_-]{20,}'               # Generic OpenAI-style keys
    'AIza[0-9A-Za-z_-]{20,}'              # Google API keys
    'xox[baprs]-[a-zA-Z0-9-]{10,}'        # Slack tokens
    'gh[pousr]_[A-Za-z0-9_]{20,}'         # GitHub tokens
    '[a-z0-9]{32}-[a-z0-9]{8}-[a-z0-9]{8}-[a-z0-9]{8}-[a-z0-9]{12}'  # UUID-style (Gmail API tokens)
)

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Get staged files (excluding deleted files)
STAGED=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$STAGED" ]; then
    exit 0
fi

FOUND=0

for pattern in "${PATTERNS[@]}"; do
    for file in $STAGED; do
        # Skip binary files and the hook itself
        if [[ "$file" == *".so" ]] || [[ "$file" == *".bin" ]] || [[ "$file" == *".gguf" ]] \
            || [[ "$file" == *".apk" ]] || [[ "$file" == *".aab" ]] \
            || [[ "$file" == ".env.example" ]] || [[ "$file" == *"pre-commit"* ]]; then
            continue
        fi

        if [ -f "$file" ]; then
            if grep -qE "$pattern" "$file" 2>/dev/null; then
                echo -e "${RED}[SECRETS] Potential secret detected in: $file${NC}"
                echo "  Pattern matched: $pattern"
                echo "  Run: git diff --cached $file  to inspect"
                FOUND=1
            fi
        fi
    done
done

if [ $FOUND -eq 1 ]; then
    echo ""
    echo -e "${RED}Commit blocked: potential secrets detected.${NC}"
    echo "If this is a false positive, use: git commit --no-verify"
    echo "Otherwise, remove the secrets and use .env for real values."
    exit 1
fi

echo -e "${GREEN}[SECRETS] No secrets detected in staged files.${GREEN}"
exit 0
