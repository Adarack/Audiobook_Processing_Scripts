#!/bin/bash

# === CONFIGURATION ===
# Define the input directory where files are located
INPUT_DIR="/path/to/input"

# Define a mapping of file extensions to their respective output directories
declare -A FILETYPE_DIRS=(
  ["mp3"]="/path/to/mp3_output"       # MP3 files go here
  ["m4b"]="/path/to/m4b_output"       # M4B audiobook files go here
  ["epub"]="/path/to/ebooks_output"   # EPUB eBooks go here
  ["mobi"]="/path/to/ebooks_output"   # MOBI eBooks go here
  ["pdf"]="/path/to/ebooks_output"    # PDF eBooks go here
)

# Flags to control script behavior
FORCE_RECOPY=false  # If true, ignore the copied log and reprocess all files
DRY_RUN=false       # If true, simulate actions without making changes

# === LOGGING ===
# Define log files for tracking script actions
COPIED_LOG="./.copied_dirs.log"  # Tracks directories that have already been copied
TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"  # Generate a timestamp for unique log files
ACTION_LOG="./copy_debug_$TIMESTAMP.log"  # Log file for detailed script actions

# === ARGUMENT PARSING ===
# Parse command-line arguments to enable optional features
for arg in "$@"; do
  case "$arg" in
    --force)
      FORCE_RECOPY=true  # Enable force recopy mode
      ;;
    --dry-run)
      DRY_RUN=true  # Enable dry-run mode
      ;;
    *)
      # Handle unknown arguments
      echo "Unknown argument: $arg"
      echo "Usage: $0 [--force] [--dry-run]"
      exit 1
      ;;
  esac
done

# === INITIALIZE LOGGING ===
# Function to log messages with timestamps
log() {
  local message="[$(date +'%Y-%m-%d %H:%M:%S')] $*"
  echo "$message" | tee -a "$ACTION_LOG"  # Write to both console and log file
}

# Log the start of the script and configuration details
log "=== Script Started ==="
log "Input directory: $INPUT_DIR"
[[ "$FORCE_RECOPY" == true ]] && log "Force recopy: ENABLED" || log "Using copy log: $COPIED_LOG"
[[ "$DRY_RUN" == true ]] && log "Dry-run mode: ENABLED (no actual copy)" || log "Dry-run mode: OFF"

# === LOAD COPIED RECORDS ===
# Load previously copied directories from the log file (if it exists)
declare -A COPIED
if [[ -f "$COPIED_LOG" && "$FORCE_RECOPY" == false ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && COPIED["$line"]=1  # Mark directories as already copied
  done < "$COPIED_LOG"
fi

# === MAIN PROCESSING ===
# Enable nullglob to handle empty directories gracefully
shopt -s nullglob
# Exit immediately if any command fails
set -e

# Process each file in the input directory
while IFS= read -r -d '' file; do
  # Extract the file extension and convert it to lowercase
  ext="${file##*.}"
  ext="${ext,,}"  # Convert to lowercase

  # Determine the relative path of the file
  subdir="$(dirname "$file")"
  rel_path="${subdir#$INPUT_DIR/}"

  # Check if the file extension is in the mapping
  if [[ -n "${FILETYPE_DIRS[$ext]}" ]]; then
    # Skip files that have already been copied (unless force recopy is enabled)
    if [[ "$FORCE_RECOPY" == false && -n "${COPIED[$rel_path]}" ]]; then
      log "SKIP (already copied): $rel_path"
      continue
    fi

    # Determine the destination directory for the file type
    dest_dir="${FILETYPE_DIRS[$ext]}"
    target_dir="$dest_dir/$rel_path"

    # Handle dry-run mode (simulate actions without making changes)
    if [[ "$DRY_RUN" == true ]]; then
      log "DRY-RUN COPY: $subdir --> $target_dir"
    else
      # Perform the actual copy operation
      log "COPY: $subdir --> $target_dir"
      mkdir -p "$(dirname "$target_dir")"  # Create target directory if it doesn't exist
      if cp -a "$subdir" "$target_dir"; then
        # Log the copied directory and update the copied log
        echo "$rel_path" >> "$COPIED_LOG"
        COPIED["$rel_path"]=1
      else
        log "ERROR: Failed to copy $subdir"
      fi
    fi
  fi
done < <(find "$INPUT_DIR" -type f -print0)  # Find all files in the input directory

# Log the end of the script
log "=== Script Finished ==="