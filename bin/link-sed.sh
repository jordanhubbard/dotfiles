#!/usr/bin/env bash

#
# link-sed.sh - Change symlink targets using string substitution
#
# This script modifies existing symlinks by replacing a substring in their
# target path. Useful for bulk updating symlinks after moving directories.
#
# Usage: link-sed.sh [-d] [-v] from-str to-str file [file ...]
#   -d    Dry run (show what would be changed without making changes)
#   -v    Verbose mode
#   -h    Show this help message
#
# Example:
#   link-sed.sh /usr/local /opt/local /mnt/app-links/*
#   link-sed.sh -d /home/user /home/newuser ~/.local/bin/*
#

set -euo pipefail

# Default options
DRY_RUN=0
VERBOSE=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() {
    [[ $VERBOSE -eq 1 ]] && echo -e "${BLUE}[INFO]${NC} $*" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

success() {
    [[ $VERBOSE -eq 1 ]] && echo -e "${GREEN}[OK]${NC} $*" >&2
}

usage() {
    cat << EOF
Usage: $(basename "$0") [-d] [-v] [-h] from-str to-str file [file ...]

Change symlink targets using string substitution.

Options:
  -d    Dry run (show what would be changed without making changes)
  -v    Verbose mode
  -h    Show this help message

Arguments:
  from-str    String to search for in symlink targets
  to-str      String to replace it with
  file        One or more files to process (can use wildcards)

Examples:
  $(basename "$0") /usr/local /opt/local /mnt/app-links/*
  $(basename "$0") -d /home/user /home/newuser ~/.local/bin/*
  $(basename "$0") -v old-path new-path link1 link2 link3

EOF
    exit "${1:-0}"
}

# Parse options
while getopts "dvh" opt; do
    case "$opt" in
        d)
            DRY_RUN=1
            info "Dry run mode enabled"
            ;;
        v)
            VERBOSE=1
            ;;
        h)
            usage 0
            ;;
        *)
            usage 1
            ;;
    esac
done
shift $((OPTIND - 1))

# Validate arguments
if [[ $# -lt 3 ]]; then
    error "Insufficient arguments"
    usage 1
fi

from="$1"
to="$2"
shift 2

# Validate from/to strings
if [[ -z "$from" ]]; then
    error "from-str cannot be empty"
    exit 1
fi

if [[ -z "$to" ]]; then
    error "to-str cannot be empty"
    exit 1
fi

# Statistics
total=0
changed=0
skipped=0
errors=0

info "Replacing '$from' with '$to' in symlink targets"
[[ $DRY_RUN -eq 1 ]] && echo -e "${YELLOW}DRY RUN MODE - No changes will be made${NC}"

# Process each file
for file in "$@"; do
    ((total++))
    
    # Check if file exists
    if [[ ! -e "$file" && ! -L "$file" ]]; then
        warn "File does not exist: $file"
        ((skipped++))
        continue
    fi
    
    # Check if it's a symlink
    if [[ ! -L "$file" ]]; then
        info "Not a symlink, skipping: $file"
        ((skipped++))
        continue
    fi
    
    # Read the current target
    if ! current_target=$(readlink "$file"); then
        error "Failed to read symlink: $file"
        ((errors++))
        continue
    fi
    
    # Check if target contains the search string
    if [[ "$current_target" != *"$from"* ]]; then
        info "Target doesn't contain '$from', skipping: $file"
        ((skipped++))
        continue
    fi
    
    # Create new target by replacing the string
    new_target="${current_target//"$from"/"$to"}"
    
    # Show what we're doing
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "$file"
        echo "  Current: $current_target"
        echo "  New:     $new_target"
    else
        info "Updating: $file"
        info "  $current_target → $new_target"
        
        # Remove old symlink and create new one
        if rm -f "$file" && ln -s "$new_target" "$file"; then
            success "Updated: $file"
            ((changed++))
        else
            error "Failed to update: $file"
            ((errors++))
        fi
    fi
done

# Print summary
echo ""
echo "Summary:"
echo "  Total files processed: $total"
[[ $DRY_RUN -eq 1 ]] && echo "  Would change: $changed" || echo "  Changed: $changed"
echo "  Skipped: $skipped"
[[ $errors -gt 0 ]] && echo "  Errors: $errors"

# Exit with appropriate code
[[ $errors -gt 0 ]] && exit 1
exit 0
