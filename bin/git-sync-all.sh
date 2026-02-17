#!/usr/bin/env bash
#
# git-sync-all.sh - Sync all git repositories in ~/Src
#
# Usage: git-sync-all.sh [directory]
#   directory: Optional path to scan (defaults to ~/Src)

# Exit on undefined variables, but not on command failures in loops
set -u

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default directory
SYNC_DIR="${1:-$HOME/Src}"

# Check if directory exists
if [ ! -d "$SYNC_DIR" ]; then
    echo -e "${RED}Error: Directory $SYNC_DIR does not exist${NC}"
    exit 1
fi

echo -e "${BLUE}Scanning for git repositories in: $SYNC_DIR${NC}"
echo ""

# Counters
total=0
updated=0
errors=0
skipped=0

# Find all directories with .git subdirectory
while IFS= read -r -d '' git_dir; do
    repo_dir=$(dirname "$git_dir")
    repo_name=$(basename "$repo_dir")

    ((total++))

    echo -e "${YELLOW}[$total] Syncing: $repo_name${NC}"

    # Change to repo directory and pull
    if cd "$repo_dir" 2>/dev/null; then
        # Check if there are uncommitted changes
        if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
            echo -e "${YELLOW}  ⚠ Uncommitted changes detected${NC}"
            # Check specifically for .beads/issues.jsonl
            if git status --porcelain 2>/dev/null | grep -q ".beads/issues.jsonl"; then
                echo -e "${YELLOW}  → Discarding .beads/issues.jsonl changes${NC}"
                git checkout .beads/issues.jsonl 2>/dev/null || true
            fi
        fi

        # Attempt to pull
        if output=$(git pull 2>&1); then
            if echo "$output" | grep -q "Already up to date"; then
                echo -e "${GREEN}  ✓ Already up to date${NC}"
                ((skipped++))
            else
                echo -e "${GREEN}  ✓ Updated${NC}"
                # Show brief summary of changes
                echo "$output" | grep -E "^(Fast-forward|Updating|Merge made)" | sed 's/^/  /'
                ((updated++))
            fi
        else
            # Check if failure is due to .beads/issues.jsonl
            if echo "$output" | grep -q ".beads/issues.jsonl"; then
                echo -e "${YELLOW}  → Auto-fixing beads issue and retrying${NC}"
                git checkout .beads/issues.jsonl 2>/dev/null || true
                if output2=$(git pull 2>&1); then
                    echo -e "${GREEN}  ✓ Updated (after fixing beads)${NC}"
                    echo "$output2" | grep -E "^(Fast-forward|Updating|Merge made)" | sed 's/^/  /'
                    ((updated++))
                else
                    echo -e "${RED}  ✗ Pull failed even after fixing beads:${NC}"
                    echo "$output2" | sed 's/^/    /'
                    ((errors++))
                fi
            else
                echo -e "${RED}  ✗ Pull failed:${NC}"
                echo "$output" | sed 's/^/    /'
                ((errors++))
            fi
        fi
    else
        echo -e "${RED}  ✗ Cannot access directory${NC}"
        ((errors++))
    fi

    echo ""
done < <(find "$SYNC_DIR" -maxdepth 2 -name .git -type d -print0)

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Summary:${NC}"
echo -e "  Total repositories: $total"
echo -e "  ${GREEN}Updated: $updated${NC}"
echo -e "  ${YELLOW}Already up to date: $skipped${NC}"
if [ $errors -gt 0 ]; then
    echo -e "  ${RED}Errors: $errors${NC}"
fi
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Exit with error code if there were errors
[ $errors -eq 0 ]
