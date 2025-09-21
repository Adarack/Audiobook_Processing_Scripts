#!/bin/bash

# === Configuration ===

# Overwrite behavior for sidecar files
# Options: "never", "always", "newer", "larger"
OVERWRITE_POLICY="never"

# Supported audiobook file extensions to search for (case-insensitive)
# These will be used to build a search filter for `find`
AUDIO_EXTENSIONS=("m4b" "M4B" "mp3" "MP3")

# Directory to scan for audiobook folders
# This is the base location where unprocessed audiobook directories live
INPUT_DIR="/path/to/beets/processed"

# Enable or disable dry-run mode
# When true, no changes will be made—commands will only be logged
DRY_RUN=false

# Whether to update the FILE line inside .cue files
FIX_CUE=true

# Whether to move successfully processed directories to another location
MOVE_FIXED=true

# Destination for moved audiobook folders (if MOVE_FIXED is true)
MOVE_TARGET="/path/to/audiobookshelf/library"

# Files that should not be renamed to match the audiobook file
# These will be excluded from the sidecar renaming loop
EXCLUDE_FILES=("cover.jpg" "folder.jpg" "reader.txt" "desc.txt" "metadata.json" "album.nfo")

# Desired ownership for all files and directories (user:group)
# Leave empty ("") to skip changing ownership
SET_OWNER="99:100"

# Desired file permission mode (e.g., 644 or 777)
# Leave empty ("") to skip chmod on files
SET_MODE="777"

# Desired directory permission mode
# Leave empty ("") to skip chmod on directories
SET_DIR_MODE="777"

# === Timestamp and log file setup ===

# Generate a timestamp for unique log file names
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Define main log file path (removes trailing slash from INPUT_DIR)
LOG_FILE="${INPUT_DIR%/}/audiobook_rename_$TIMESTAMP.log"

# Define separate log for skipped directories with multiple audio files
SKIPPED_MULTIPLE_LOG_FILE="${INPUT_DIR%/}/audiobook_rename_SKIPPED_multi_$TIMESTAMP.log"

# === Initialize counters ===

count_renamed=0           # Sidecar files successfully renamed
count_skipped=0           # Skipped due to name conflicts
count_cover_sync=0        # cover.jpg ↔ folder.jpg syncs
count_chmod=0             # chmod operations applied
count_chown=0             # chown operations applied
count_moved=0             # Files successfully rsynced
count_dirs_moved=0        # Source directories successfully removed
count_skipped_dirs=0      # Directories skipped due to multiple audio files
count_cue_fixed=0         # .cue files updated with correct FILE line

# === Logging function ===

log() {
    # Prefix message with timestamp and write to both terminal and log file
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# === Validation checks ===

# === Validate Overwrite Policy ===
VALID_POLICIES=("never" "always" "newer" "larger")
if [[ ! " ${VALID_POLICIES[*]} " =~ " ${OVERWRITE_POLICY} " ]]; then
    echo "Error: Invalid OVERWRITE_POLICY '$OVERWRITE_POLICY'. Must be one of: ${VALID_POLICIES[*]}" >&2
    exit 1
fi

# Ensure the target directory exists
[[ ! -d "$INPUT_DIR" ]] && echo "Error: Target dir missing: $INPUT_DIR" && exit 1

# Ensure we can write to the log file
! touch "$LOG_FILE" 2>/dev/null && echo "Error: Cannot write log: $LOG_FILE" && exit 1

# Create MOVE_TARGET if it doesn't exist (only if MOVE_FIXED is enabled)
[[ "$MOVE_FIXED" == true && ! -d "$MOVE_TARGET" ]] && mkdir -p "$MOVE_TARGET"

# === Script start logging ===

log "=== Audiobook Sidecar Renamer ==="
log "Overwrite Policy     : $OVERWRITE_POLICY"
log "Audio Extensions     : ${AUDIO_EXTENSIONS[*]}"
log "Target: $INPUT_DIR"
log "Move Fixed: $MOVE_FIXED → $MOVE_TARGET"
log "Dry Run: $DRY_RUN"
log "Fix .cue FILE line : $FIX_CUE"
log "Owner/Group: $SET_OWNER"
log "File Mode: $SET_MODE"
log "Dir Mode: $SET_DIR_MODE"
log "--------------------------------"

# === Build find command arguments for audiobook file extensions ===

iname_args=()
for ext in "${AUDIO_EXTENSIONS[@]}"; do
  # Append -iname "*.ext" -o for each extension
  iname_args+=(-iname "*.${ext}" -o)
done
unset 'iname_args[-1]'  # Remove final dangling -o

# === Find unique directories containing audiobook files ===

mapfile -t unique_dirs < <(
    find "$INPUT_DIR" -type f \( "${iname_args[@]}" \) -exec dirname {} \; | sort -u
)
log "DEBUG: Found ${#unique_dirs[@]} audiobook directories"

# === Begin processing each directory ===

for base_dir in "${unique_dirs[@]}"; do
    log "DEBUG: Files in $base_dir:"
    find "$base_dir" -maxdepth 1 -type f | while read -r f; do
        log "    ├─ $(basename "$f")"
    done

    # Find all matching audiobook files in the current directory
    mapfile -t audiobooks < <(find "$base_dir" -maxdepth 1 -type f \( "${iname_args[@]}" \))

    log "DEBUG: Inspecting $base_dir — found ${#audiobooks[@]} audio file(s)"

    # === Skip conditions ===

    if [[ ${#audiobooks[@]} -eq 0 ]]; then
        # Skip directory if no matching audiobook files found
        continue
    elif [[ ${#audiobooks[@]} -gt 1 ]]; then
        # Skip directory if multiple audiobook files found — ambiguity
        log "⚠ Skipping $base_dir — multiple audiobook files found (${#audiobooks[@]})"
        echo "$base_dir" >> "$SKIPPED_MULTIPLE_LOG_FILE"
        ((count_skipped_dirs++))
        continue
    fi

        # === Select and prepare audiobook filename base ===

        # Get the first (and only) audiobook file in the directory
        audiobook="${audiobooks[0]}"

        # Extract the full filename (e.g., "Book Title.m4b")
        base_name=$(basename "$audiobook")

        # Strip the extension (e.g., "Book Title")
        base_name_no_ext="${base_name%.*}"

        # Log which audiobook file is being processed
        log "Processing: $base_dir → $base_name"

        # === Cover image sync (cp cover.jpg ↔ folder.jpg) ===

        # If only cover.jpg exists, and folder.jpg doesn't
        if [[ -f "$base_dir/cover.jpg" && ! -f "$base_dir/folder.jpg" ]]; then
            if $DRY_RUN; then
                log "[DRY RUN] cp \"$base_dir/cover.jpg\" \"$base_dir/folder.jpg\""
            else
                cp "$base_dir/cover.jpg" "$base_dir/folder.jpg" && log "cp \"$base_dir/cover.jpg\" \"$base_dir/folder.jpg\""
                ((count_cover_sync++))
            fi
        fi

        # If only folder.jpg exists, and cover.jpg doesn't
        if [[ -f "$base_dir/folder.jpg" && ! -f "$base_dir/cover.jpg" ]]; then
            if $DRY_RUN; then
                log "[DRY RUN] cp \"$base_dir/folder.jpg\" \"$base_dir/cover.jpg\""
            else
                cp "$base_dir/folder.jpg" "$base_dir/cover.jpg" && log "cp \"$base_dir/folder.jpg\" \"$base_dir/cover.jpg\""
                ((count_cover_sync++))
            fi
        fi

        # === Rename all sidecar files to match audiobook base name ===
        find "$base_dir" -maxdepth 1 -type f | while read -r file; do
            filename=$(basename "$file")

            # Skip the main audiobook file itself
            [[ "$file" == "$audiobook" ]] && continue

            # Skip excluded sidecar files (cover.jpg, folder.jpg, etc.)
            for exclude in "${EXCLUDE_FILES[@]}"; do
                [[ "$filename" == "$exclude" ]] && continue 2
            done

            # Determine file extension (special handling for *.metadata.json)
            [[ "$filename" == *.metadata.json ]] && ext="metadata.json" || ext="${filename##*.}"

            # Build the new filename with audiobook base (e.g., "Book Title.nfo")
            new_path="$base_dir/${base_name_no_ext}.$ext"

            # If filename is already correct, skip; otherwise rename it
            if [[ -e "$new_path" ]]; then
                overwrite_decision="skip"

                case "$OVERWRITE_POLICY" in
                    always)
                        overwrite_decision="overwrite"
                        ;;
                    newer)
                        if [[ "$file" -nt "$new_path" ]]; then
                            overwrite_decision="overwrite"
                        fi
                        ;;
                    larger)
                        src_size=$(stat -c%s "$file")
                        dst_size=$(stat -c%s "$new_path")
                        if (( src_size > dst_size )); then
                            overwrite_decision="overwrite"
                        fi
                        ;;
                    *)
                        overwrite_decision="skip"
                        ;;
                esac

                if [[ "$overwrite_decision" == "overwrite" ]]; then
                    if $DRY_RUN; then
                        log "[DRY RUN] mv -f \"$file\" \"$new_path\""
                    else
                        mv -f "$file" "$new_path" && log "Overwrote: $new_path" || log "❌ Failed to overwrite: $new_path"
                        ((count_renamed++))
                    fi
                else
                    log "Skipping (exists): $new_path"
                    ((count_skipped++))
                fi

                else
                    if $DRY_RUN; then
                        log "[DRY RUN] mv \"$file\" \"$new_path\""
                    else
                        mv "$file" "$new_path" && log "mv \"$file\" \"$new_path\""
                        ((count_renamed++))
                    fi
                fi

            # === Update cue file to match the new audiobook filename ===
            if [[ "$FIX_CUE" == true && "$ext" == "cue" ]]; then
                cue_rel_audio=$(basename "$audiobook")
                safe_audio_name="${cue_rel_audio//\"/\\\"}"

                if $DRY_RUN; then
                    log "[DRY RUN] sed -i \"s/^FILE \\\".*\\\"/FILE \\\"$safe_audio_name\\\"/\" \"$new_path\""
                else
                    original_file_line=$(grep -m1 '^FILE "' "$new_path")

                    if [[ -z "$original_file_line" ]]; then
                        log "⚠ No FILE line found in $new_path — inserting one at top"
                        # Insert FILE line at the top of the .cue file
                        tmp_file="${new_path}.tmp"
                        {
                            echo "FILE \"$safe_audio_name\" MP3"
                            cat "$new_path"
                        } > "$tmp_file" && mv "$tmp_file" "$new_path"
                        if [[ $? -eq 0 ]]; then
                            log "Inserted FILE line: FILE \"$cue_rel_audio\" MP3"
                            ((count_cue_fixed++))
                        else
                            log "❌ Failed to insert FILE line in $new_path"
                        fi
                    else
                        # Replace existing FILE line
                        sed -i "s/^FILE \".*\"/FILE \"$safe_audio_name\"/" "$new_path"
                        if [[ $? -eq 0 ]]; then
                            log "Updated cue FILE line: ${original_file_line} → FILE \"$cue_rel_audio\""
                            ((count_cue_fixed++))
                        else
                            log "❌ Failed to update cue FILE line in $new_path"
                        fi
                    fi
                fi
            fi

        done

# === Ownership and Permissions ===

# Apply ownership (user:group) if SET_OWNER is defined
if [[ -n "$SET_OWNER" || -n "$SET_MODE" || -n "$SET_DIR_MODE" ]]; then
    find "$base_dir" -print0 | while IFS= read -r -d '' item; do

        # Apply ownership (user:group)
        if [[ -n "$SET_OWNER" ]]; then
            current_owner=$(stat -c "%U:%G" "$item" 2>/dev/null)
            if [[ "$current_owner" != "$SET_OWNER" ]]; then
                if $DRY_RUN; then
                    log "[DRY RUN] chown $SET_OWNER \"$item\""
                else
                    chown "$SET_OWNER" "$item" && log "chown $SET_OWNER \"$item\"" || log "❌ chown failed on: $item"
                    ((count_chown++))
                fi
            fi
        fi

        # Apply file permissions
        if [[ -n "$SET_MODE" && -f "$item" ]]; then
            current_mode=$(stat -c "%a" "$item" 2>/dev/null)
            if [[ "$current_mode" != "$SET_MODE" ]]; then
                if $DRY_RUN; then
                    log "[DRY RUN] chmod $SET_MODE \"$item\""
                else
                    chmod "$SET_MODE" "$item" && log "chmod $SET_MODE \"$item\"" || log "❌ chmod failed on: $item"
                    ((count_chmod++))
                fi
            fi
        fi

        # Apply directory permissions
        if [[ -n "$SET_DIR_MODE" && -d "$item" ]]; then
            current_mode=$(stat -c "%a" "$item" 2>/dev/null)
            if [[ "$current_mode" != "$SET_DIR_MODE" ]]; then
                if $DRY_RUN; then
                    log "[DRY RUN] chmod $SET_DIR_MODE \"$item\""
                else
                    chmod "$SET_DIR_MODE" "$item" && log "chmod $SET_DIR_MODE \"$item\"" || log "❌ chmod failed on: $item"
                    ((count_chmod++))
                fi
            fi
        fi

    done
fi

# === Move processed directory to final location ===
if [[ "$MOVE_FIXED" == true ]]; then

    # Compute relative path from INPUT_DIR to preserve directory structure
    rel_path="${base_dir#$INPUT_DIR}"
    dest="$MOVE_TARGET/$rel_path"

    # Ensure destination directory exists (even if nested)
    mkdir -p "$dest"

    if $DRY_RUN; then
        # If in dry run mode, just print the rsync command to be executed
        echo "[DRY RUN] rsync -a --remove-source-files --progress \"$base_dir/\" \"$dest/\""
    else
        # Add spacing before rsync progress output
        echo ""
        echo "Running rsync with progress: $base_dir → $dest"

        # Run rsync with progress shown in terminal; don't log progress output
        rsync -a --remove-source-files --progress "$base_dir/" "$dest/"

        # Add spacing after rsync progress
        echo ""

        # Capture rsync's exit code
        rsync_exit=$?

          if [[ $rsync_exit -eq 0 ]]; then
              # Log success if rsync completed successfully
             log "Moved files: $base_dir → $dest"
             ((count_moved++))

            # === Clean up junk files before checking if directory tree is empty ===
            find "$base_dir" \( \
            -name ".AppleDouble" -o \
            -name ".DS_Store" -o \
            -name "Thumbs.db" -o \
            -name "desktop.ini" -o \
            -name "._*" \
             \) -type f -delete

            # === Recursively remove empty directories up to $INPUT_DIR ===
            dir="$base_dir"
            while [[ "$dir" != "$INPUT_DIR" && "$dir" != "/" ]]; do
                if [ -d "$dir" ] && [ -z "$(find "$dir" -mindepth 1 -type f)" ]; then
                    rmdir "$dir" && log "Removed empty dir: $dir"
                    ((count_dirs_moved++))
                else
                break
                fi
                    dir=$(dirname "$dir")
                done
            else
                # Log failure with exit code if rsync failed
                log "❌ rsync failed for: $base_dir → $dest (exit code $rsync_exit)"
            fi
        fi
    fi

        # === Apply permissions and ownership to moved files ===
    if [[ -n "$SET_OWNER" || -n "$SET_MODE" || -n "$SET_DIR_MODE" ]]; then
        find "$dest" -print0 | while IFS= read -r -d '' item; do

            # Apply ownership (user:group)
            if [[ -n "$SET_OWNER" ]]; then
                current_owner=$(stat -c "%U:%G" "$item" 2>/dev/null)
                if [[ "$current_owner" != "$SET_OWNER" ]]; then
                    if $DRY_RUN; then
                        log "[DRY RUN] chown $SET_OWNER \"$item\""
                    else
                        chown "$SET_OWNER" "$item" && log "chown $SET_OWNER \"$item\"" || log "❌ chown failed on: $item"
                        ((count_chown++))
                    fi
                fi
            fi

            # Apply file permissions
            if [[ -n "$SET_MODE" && -f "$item" ]]; then
                current_mode=$(stat -c "%a" "$item" 2>/dev/null)
                if [[ "$current_mode" != "$SET_MODE" ]]; then
                    if $DRY_RUN; then
                        log "[DRY RUN] chmod $SET_MODE \"$item\""
                    else
                        chmod "$SET_MODE" "$item" && log "chmod $SET_MODE \"$item\"" || log "❌ chmod failed on: $item"
                        ((count_chmod++))
                    fi
                fi
            fi

            # Apply directory permissions
            if [[ -n "$SET_DIR_MODE" && -d "$item" ]]; then
                current_mode=$(stat -c "%a" "$item" 2>/dev/null)
                if [[ "$current_mode" != "$SET_DIR_MODE" ]]; then
                    if $DRY_RUN; then
                        log "[DRY RUN] chmod $SET_DIR_MODE \"$item\""
                    else
                        chmod "$SET_DIR_MODE" "$item" && log "chmod $SET_DIR_MODE \"$item\"" || log "❌ chmod failed on: $item"
                        ((count_chmod++))
                    fi
                fi
            fi

        done
    fi

done



# === Final Summary ===

# Log final summary to the log file
log "=== Done ==="
log "--------------------------------"
log "SUMMARY:"
log "Mode                : $([[ $DRY_RUN == true ]] && echo "DRY RUN" || echo "LIVE")"
log "Renamed             : $count_renamed file(s)"                  # Number of files renamed
log "Skipped (exists)    : $count_skipped file(s) (target already exists)"  # Conflicts skipped
log "Cover syncs         : $count_cover_sync operation(s)"         # Copies between cover.jpg & folder.jpg
log "Cue fixed           : $count_cue_fixed Fixed filenames in cue files"  # .cue files updated
log "Permissions         : Files = ${SET_MODE:-(unchanged)}, Dirs = ${SET_DIR_MODE:-(unchanged)}"  # Modes
log "Owner/Group         : ${SET_OWNER:-(unchanged)}"              # chown target
log "Permissions Applied : $count_chmod item(s)"                   # chmod ops applied
log "Owner/Group Applied : $count_chown item(s)"                   # chown ops applied
log "Dirs Moved          : $count_dirs_moved"                      # Directories deleted after rsync
log "Files Moved         : $count_moved"                           # rsync operations done
log "Skipped Directories : $count_skipped_dirs (multiple audio files)"  # Conflicted folders
log "--------------------------------"

# Print same summary to terminal (user-friendly version)
echo "======== Summary ========"
echo "Mode                : $([[ $DRY_RUN == true ]] && echo "DRY RUN" || echo "LIVE")"
echo "Renamed             : $count_renamed"
echo "Skipped             : $count_skipped"
echo "Cover syncs         : $count_cover_sync"
echo "Cue fixed           : $count_cue_fixed Fixed filenames in cue files"
echo "Permissions         : Files = ${SET_MODE:-(unchanged)}, Dirs = ${SET_DIR_MODE:-(unchanged)}"
echo "Owner/Group         : ${SET_OWNER:-(unchanged)}"
echo "Permissions Applied : $count_chmod"
echo "Owner/Group Applied : $count_chown"
echo "Dirs Moved          : $count_dirs_moved"
echo "Files Moved         : $count_moved"
echo "Skipped Directories : $count_skipped_dirs (multiple audio files)"
echo "========================="
