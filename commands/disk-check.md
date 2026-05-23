Analyze disk usage under the directory specified by the user and provide actionable cleanup recommendations.

The target directory is: $ARGUMENTS

If no argument is provided, default to `/data`.

Assign the target directory to a variable (e.g., TARGET="$ARGUMENTS" or TARGET="/data" if empty), then run the following commands to gather disk information:

- `df -h <TARGET>` — overall usage of the target mount point
- `du -sh <TARGET>/* 2>/dev/null | sort -rh | head -20` — top 20 largest entries under TARGET
- `du -sh <TARGET>/**/* 2>/dev/null | sort -rh | head -20` — top 20 largest second-level entries
- `find <TARGET> -name "*.log" -size +100M 2>/dev/null | xargs ls -lh 2>/dev/null` — log files larger than 100MB
- `find <TARGET> \( -name "*.tmp" -o -name "*.bak" -o -name "*.old" \) 2>/dev/null | head -30` — temporary and backup files
- `find <TARGET> -mtime +90 -type f 2>/dev/null | wc -l` — count of files not modified in over 90 days

Then produce a report in this structure:

## Disk Usage Report — <TARGET>

### Overview
Total capacity, used, available, and usage percentage.

### Top 10 Space Consumers
Sorted list with size and path.


