#!/usr/bin/env bash
#
# git-sync-all.sh - Sync all git repositories in ~/Src
#
# Usage: git-sync-all.sh [directory]
#   directory: Optional path to scan (defaults to ~/Src)
#
# Tracked local changes under .beads/ are ignored automatically. Repositories
# that cannot be pulled because of other local changes are written to
# ~/git-sync-all-local-changes.txt for hand-inspection.

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
LOCAL_CHANGES_FILE="$HOME/git-sync-all-local-changes.txt"

# Check if directory exists
if [ ! -d "$SYNC_DIR" ]; then
    echo -e "${RED}Error: Directory $SYNC_DIR does not exist${NC}"
    exit 1
fi

# Use physical, absolute paths in the hand-inspection report.
if ! SYNC_DIR=$(cd "$SYNC_DIR" 2>/dev/null && pwd -P); then
    echo -e "${RED}Error: Cannot resolve directory $SYNC_DIR${NC}"
    exit 1
fi

if ! : > "$LOCAL_CHANGES_FILE"; then
    echo -e "${RED}Error: Cannot write local-changes report to $LOCAL_CHANGES_FILE${NC}"
    exit 1
fi

# Beads keeps both versioned data and machine-local runtime data in .beads/.
# Reset only tracked changes so generated, untracked runtime files remain intact.
ignore_beads_changes() {
    if [ ! -d .beads ] && [ -z "$(git ls-files -- .beads 2>/dev/null)" ]; then
        return
    fi

    if ! git diff --quiet -- .beads 2>/dev/null ||
       ! git diff --cached --quiet -- .beads 2>/dev/null; then
        echo -e "${YELLOW}  → Ignoring tracked local changes under .beads/${NC}"
        git reset -q HEAD -- .beads 2>/dev/null || true
        git checkout -q -- .beads 2>/dev/null || true
    fi
}

has_non_beads_changes() {
    [ -n "$(git status --porcelain -- . \
        ':(exclude).beads' ':(exclude).beads/**' 2>/dev/null)" ]
}

pull_failed_due_to_local_changes() {
    printf '%s\n' "$1" | grep -Eqi \
        'local changes.*would be overwritten|untracked working tree files.*would be overwritten|cannot pull with rebase.*(unstaged changes|uncommitted changes)|index contains uncommitted changes|pulling is not possible because you have unmerged files|please commit or stash|commit your changes or stash'
}

echo -e "${BLUE}Scanning for git repositories in: $SYNC_DIR${NC}"
echo ""

# Counters
total=0
updated=0
errors=0
skipped=0
local_change_failures=0

# Find all directories with .git subdirectory
while IFS= read -r -d '' git_dir; do
    repo_dir=$(dirname "$git_dir")
    repo_name=$(basename "$repo_dir")

    ((total += 1))

    echo -e "${YELLOW}[$total] Syncing: $repo_name${NC}"

    # Change to repo directory and pull
    if cd "$repo_dir" 2>/dev/null; then
        # Beads state should never prevent routine repository updates.
        ignore_beads_changes

        # Check if there are uncommitted changes
        if has_non_beads_changes; then
            echo -e "${YELLOW}  ⚠ Uncommitted changes detected${NC}"
        fi

        # Attempt to pull
        if output=$(LC_ALL=C git pull 2>&1); then
            if echo "$output" | grep -q "Already up to date"; then
                echo -e "${GREEN}  ✓ Already up to date${NC}"
                ((skipped += 1))
            else
                echo -e "${GREEN}  ✓ Updated${NC}"
                # Show brief summary of changes
                echo "$output" | grep -E "^(Fast-forward|Updating|Merge made)" | sed 's/^/  /'
                ((updated += 1))
            fi
        else
            echo -e "${RED}  ✗ Pull failed:${NC}"
            echo "$output" | sed 's/^/    /'
            ((errors += 1))

            if pull_failed_due_to_local_changes "$output"; then
                printf '%s\n' "$repo_dir" >> "$LOCAL_CHANGES_FILE"
                ((local_change_failures += 1))
                echo -e "${YELLOW}  → Recorded for hand-inspection${NC}"
            fi
        fi
    else
        echo -e "${RED}  ✗ Cannot access directory${NC}"
        ((errors += 1))
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
echo -e "  ${YELLOW}Blocked by local changes: $local_change_failures${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Exact paths for hand-inspection: $LOCAL_CHANGES_FILE${NC}"

# Exit with error code if there were errors
[ $errors -eq 0 ]
