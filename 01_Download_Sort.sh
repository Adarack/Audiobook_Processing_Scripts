#!/bin/bash

# === CONFIGURATION ===

INPUT_DIR="/path/to/input"
MANUAL_LABEL="Brandon Sanderson"
ALWAYS_OVERWRITE=false            # Delete target before copy
FORCE_RECOPY=true
DRY_RUN=false
VERBOSE=true

# Optional post-copy ownership/permissions
SET_OWNER="nobody:nobody"        # e.g. nobody:users
SET_MODE="777"                   # File permission
SET_DIR_MODE="777"               # Directory permission

declare -A FILETYPE_DIRS=(
  ["mp3"]="/path/to/mp3_output"
  ["m4b"]="/path/to/m4b_output"
  ["epub"]="/path/to/ebooks_output"
  ["mobi"]="/path/to/ebooks_output"
  ["pdf"]="/path/to/ebooks_output"
)

TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"
COPIED_LOG="${INPUT_DIR%/}/.copied_dirs.log"
ACTION_LOG="${INPUT_DIR%/}/copy_debug_$TIMESTAMP.log"
mkdir -p "$(dirname "$ACTION_LOG" 2>/dev/null || echo .)"

# === ARGUMENT PARSING ===
for arg in "$@"; do
  [[ -z "$arg" || "$arg" == "$0" ]] && continue
  case "$arg" in
    --force) FORCE_RECOPY=true ;;
    --dry-run) DRY_RUN=true ;;
    --verbose) VERBOSE=true ;;
    *)
      echo "Unknown argument: '$arg'"
      echo "Usage: $0 [--force] [--dry-run] [--verbose]"
      exit 1
      ;;
  esac
done

# === LOGGING ===
log() {
  local message="[$(date +'%Y-%m-%d %H:%M:%S')] $*"
  echo "$message" | tee -a "$ACTION_LOG"
}

# === STARTUP ===
log "=== Script Started ==="
log "Input directory: $INPUT_DIR"
[[ "$FORCE_RECOPY" == true ]] && log "Force recopy: ENABLED"
[[ "$ALWAYS_OVERWRITE" == true ]] && log "Always overwrite: ENABLED"
[[ "$DRY_RUN" == true ]] && log "Dry-run mode: ENABLED"
[[ "$VERBOSE" == true ]] && log "Verbose mode: ENABLED"
[[ -n "$MANUAL_LABEL" ]] && log "Manual label: $MANUAL_LABEL"

count_chown=0
count_chmod=0

declare -A COPIED
cleaned_log=()

# === CLEAN COPIED LOG ===
if [[ -f "$COPIED_LOG" && "$FORCE_RECOPY" == false && "$ALWAYS_OVERWRITE" == false ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    full_path="$INPUT_DIR${line// - //}"
    if [[ -d "$full_path" ]]; then
      COPIED["$line"]=""
      cleaned_log+=("$line")
    else
      log "CLEANUP: Removed stale log entry: $line"
    fi
  done < "$COPIED_LOG"
  printf "%s\n" "${cleaned_log[@]}" > "$COPIED_LOG"
fi

# === MAIN LOGIC ===
shopt -s nullglob

while IFS= read -r -d '' file; do
  ext="${file##*.}"
  ext="${ext,,}"
  subdir="$(dirname "$file")"
  rel_path="${subdir#$INPUT_DIR}"
  flattened_path="${rel_path//\// - }"
  flattened_path="${flattened_path## }"
  [[ -n "$MANUAL_LABEL" ]] && flattened_path="$MANUAL_LABEL - ${flattened_path}"

  [[ "$VERBOSE" == true ]] && log "FOUND FILE: $file (ext: $ext)"

  if [[ -n "${FILETYPE_DIRS[$ext]}" ]]; then
    dest_dir="${FILETYPE_DIRS[$ext]}"
    target_dir="${dest_dir}${flattened_path}"

    if [[ "$ALWAYS_OVERWRITE" == false && "$FORCE_RECOPY" == false && -n "${COPIED[$flattened_path]}" ]]; then
      log "SKIP (already copied): $flattened_path"
      continue
    fi

    if [[ "$DRY_RUN" == true ]]; then
      log "DRY-RUN RSYNC: $subdir → $target_dir"
    else
      if [[ "$ALWAYS_OVERWRITE" == true && -d "$target_dir" ]]; then
        log "OVERWRITE: Removing $target_dir"
        rm -rf "$target_dir"
      fi
    fi

    mkdir -p "$target_dir"
    rsync_opts="-a --progress"
    [[ "$DRY_RUN" == true ]] && rsync_opts+=" --dry-run"
    [[ "$VERBOSE" == true ]] && rsync_opts+=" --itemize-changes"

    if rsync $rsync_opts "$subdir/" "$target_dir/"; then
      echo "$flattened_path" >> "$COPIED_LOG"
      COPIED["$flattened_path"]="$target_dir"
    else
      log "❌ ERROR: rsync failed from $subdir to $target_dir"
    fi
  else
    [[ "$VERBOSE" == true ]] && log "IGNORED: $file (unmatched extension)"
  fi

  
done < <(find "$INPUT_DIR" -type f -print0)

# === FINAL PERMISSION PASS ===
if [[ "$DRY_RUN" == false && ( -n "$SET_OWNER" || -n "$SET_MODE" || -n "$SET_DIR_MODE" ) ]]; then
  log "Applying ownership and permissions to all copied targets..."
  set +e
  for flattened_path in "${!COPIED[@]}"; do
    target_dir="${COPIED[$flattened_path]}"
    [[ -z "$target_dir" ]] && continue

    while IFS= read -r -d '' item; do
      if [[ -n "$SET_OWNER" ]]; then
        current_owner=$(stat -c "%U:%G" "$item" 2>/dev/null)
        if [[ "$current_owner" != "$SET_OWNER" ]]; then
          chown "$SET_OWNER" "$item" && log "chown $SET_OWNER \"$item\"" || log "❌ chown failed: $item"
          ((count_chown++))
        fi
      fi
      if [[ -n "$SET_MODE" && -f "$item" ]]; then
        current_mode=$(stat -c "%a" "$item" 2>/dev/null)
        if [[ "$current_mode" != "$SET_MODE" ]]; then
          chmod "$SET_MODE" "$item" && log "chmod $SET_MODE \"$item\"" || log "❌ chmod failed: $item"
          ((count_chmod++))
        fi
      fi
      if [[ -n "$SET_DIR_MODE" && -d "$item" ]]; then
        current_mode=$(stat -c "%a" "$item" 2>/dev/null)
        if [[ "$current_mode" != "$SET_DIR_MODE" ]]; then
          chmod "$SET_DIR_MODE" "$item" && log "chmod $SET_DIR_MODE \"$item\"" || log "❌ chmod failed: $item"
          ((count_chmod++))
        fi
      fi
    done < <(find "$target_dir" -print0)
  done
  set -e
fi

trap '' SIGPIPE
log "chown actions: $count_chown"
log "chmod actions: $count_chmod"
log "=== Script Finished ==="
