#!/bin/bash

# "/path/to/01_Download_Sort.sh" "%F"
# chmod +x /path/to/01_Download_Sort.sh
#
# This script sorts downloaded audiobook or ebook files by file extension type.
# It copies the *entire directory* containing each matching file into the appropriate
# destination, using just the leaf directory name (via basename) for the destination.
# 
# It now supports passing either:
#   - an entire input directory (will scan recursively for files)
#   - a single file (will process it directly)
# 
# It also maintains a copy log to avoid redundant copying,
# unless you force it with --force.

# === CONFIGURATION ===
# Directory to scan by default if not overridden by arguments
INPUT_DIR="/path/to/downloads/complete"

# Where to store log files (defaults to current directory)
LOG_DIR="/path/to/downloads/complete/logs"  # "./" is default

# Map of file extensions to their target directories
declare -A FILETYPE_DIRS=(
  ["mp3"]="/path/to/autom4b/input"        # MP3 audiobooks
  ["m4a"]="/path/to/autom4b/input"        # M4A audiobooks
  ["m4b"]="/path/to/beets/untagged"       # M4B audiobooks
  ["epub"]="/path/to/calibre/import"      # EPUB ebooks
  ["mobi"]="/path/to/calibre/import"      # MOBI ebooks
  ["pdf"]="/path/to/calibre/import"       # PDF ebooks
)

# Multi-M4B handling configuration
ENABLE_MULTI_M4B_REDIRECT=true          # Enable special handling for multiple M4B files
MULTI_M4B_DEST_DIR="/path/to/autom4b/input"  # Where to send directories with multiple M4B files

# Behavior flags
FORCE_RECOPY=false  # If true, ignores copy log and re-copies everything
DRY_RUN=false       # If true, simulates actions without copying

# === LOGGING SETUP ===
mkdir -p "$LOG_DIR"  # Ensure log directory exists
TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"
COPIED_LOG="$LOG_DIR/copied_dirs.log"                 # Tracks directories already copied
ACTION_LOG="$LOG_DIR/copy_debug_$TIMESTAMP.log"       # Log file for all script actions

# === ARGUMENT PARSING ===
if [[ -n "$1" && ! "$1" =~ ^-- ]]; then
  INPUT_DIR="$1"
  shift
fi

for arg in "$@"; do
  case "$arg" in
    --force)
      FORCE_RECOPY=true ;;
    --dry-run)
      DRY_RUN=true ;;
    *)
      echo "Unknown argument: $arg"
      echo "Usage: $0 [input_dir_or_file] [--force] [--dry-run]"
      exit 1 ;;
  esac
done

# === FUNCTION FOR TIMESTAMPED LOGGING ===
log() {
  local message="[$(date +'%Y-%m-%d %H:%M:%S')] $*"
  echo "$message" | tee -a "$ACTION_LOG"
}

# === STARTUP LOG OUTPUT ===
log "=== Script Started ==="
log "Input: $INPUT_DIR"
[[ "$FORCE_RECOPY" == true ]] && log "Force recopy: ENABLED" || log "Using copy log: $COPIED_LOG"
[[ "$DRY_RUN" == true ]] && log "Dry-run mode: ENABLED (no actual copy)" || log "Dry-run mode: OFF"

# === LOAD PREVIOUSLY COPIED RECORDS ===
declare -A COPIED
if [[ -f "$COPIED_LOG" && "$FORCE_RECOPY" == false ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && COPIED["$line"]=1
  done < "$COPIED_LOG"
fi

# === TRACK SUMMARY COUNTS ===
copied_count=0
skipped_count=0

# === BUILD THE LIST OF FILES TO PROCESS ===
files_to_process=()

if [[ -f "$INPUT_DIR" ]]; then
  log "Input is a single file."
  files_to_process+=("$INPUT_DIR")
elif [[ -d "$INPUT_DIR" ]]; then
  log "Input is a directory. Scanning for files inside."
  while IFS= read -r -d '' file; do
    files_to_process+=("$file")
  done < <(find "$INPUT_DIR" -type f -print0)
else
  log "ERROR: Input path is neither a file nor a directory: $INPUT_DIR"
  exit 1
fi

# === MAIN PROCESSING LOOP ===
for file in "${files_to_process[@]}"; do
  # Extract file extension (lowercase)
  ext="${file##*.}"
  [[ "$file" == "$ext" ]] && ext=""
  ext="${ext,,}"

  if [[ -n "${FILETYPE_DIRS[$ext]}" ]]; then
    subdir="$(dirname "$file")"
    rel_path="$(basename "$subdir")"

    # Skip if already copied
    if [[ "$FORCE_RECOPY" == false && -n "${COPIED[$rel_path]}" ]]; then
      log "SKIP (already copied): $rel_path"
      ((skipped_count++))
      continue
    fi

    # Multi-M4B handling logic
    if [[ "$ENABLE_MULTI_M4B_REDIRECT" == true && "$ext" == "m4b" ]]; then
      num_m4b_files=$(find "$subdir" -maxdepth 1 -iname "*.m4b" | wc -l)
      if (( num_m4b_files > 1 )); then
        log "NOTE: Multiple m4b files detected in $subdir. Redirecting to multi-M4B destination."
        dest_dir="$MULTI_M4B_DEST_DIR"
      else
        dest_dir="${FILETYPE_DIRS[$ext]}"
      fi
    else
      dest_dir="${FILETYPE_DIRS[$ext]}"
    fi

    target_dir="${dest_dir%/}/$rel_path"

    if [[ "$DRY_RUN" == true ]]; then
      log "DRY-RUN COPY DIR: $subdir --> $target_dir"
    else
      log "COPY DIR: $subdir --> $target_dir"
      mkdir -p "$target_dir"
      if cp -a "$subdir/." "$target_dir/"; then
        COPIED["$rel_path"]=1
        ((copied_count++))
      else
        log "ERROR: Failed to copy $subdir"
      fi
    fi
  fi
done


# === SAVE UPDATED COPY LOG ===
if [[ "$DRY_RUN" == false ]]; then
  printf "%s\n" "${!COPIED[@]}" > "$COPIED_LOG"
fi

# === FINAL SUMMARY LOG ===
log "=== Script Finished ==="
log "Summary: $copied_count copied, $skipped_count skipped."
