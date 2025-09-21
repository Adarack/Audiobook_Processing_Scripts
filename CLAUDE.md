# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Bash scripts for automating audiobook processing workflows on Unraid systems, particularly focused on:
- Sorting downloaded audiobook files by type
- Integration with Beets music library manager for audiobook tagging
- Post-processing operations including file renaming and organization
- Integration with qBittorrent, autom4b, and Calibre

## Core Scripts

### 01_Download_Sort.sh
Primary download sorting script that processes files from an input directory and sorts them by file type into designated output directories. Used with qBittorrent's completion actions.

Key configuration variables (lines 17-32):
- `INPUT_DIR`: Source directory for downloads
- `LOG_DIR`: Directory for storing log files
- `FILETYPE_DIRS`: Associative array mapping file extensions to target directories
  - MP3/M4A → autom4b conversion directory
  - M4B → Beets untagged directory (unless multiple M4B files found)
  - EPUB/MOBI/PDF → Calibre import directory

Special handling:
- Multiple M4B files in same directory → redirected to autom4b for processing

### 02_Audiobooks to ABS.sh (formerly 02_Audiobook_After_Beets.sh)
Post-Beets processing script that handles final organization of audiobooks after tagging. Performs sidecar file renaming, CUE file corrections, and moves processed files to final library location.

Key configuration variables (lines 5-44):
- `OVERWRITE_POLICY`: Policy for handling existing sidecar files ("never", "always", "newer", "larger")
- `INPUT_DIR`: Directory containing Beets-processed audiobooks
- `MOVE_TARGET`: Final library destination
- `AUDIO_EXTENSIONS`: Supported audiobook formats
- `EXCLUDE_FILES`: Files that should not be renamed during processing

## Common Development Tasks

### Testing Script Changes
Scripts support dry-run mode for testing without making actual changes:
```bash
# Test download sorting
./01_Download_Sort.sh --dry-run --verbose

# Test post-processing
# Edit script and set DRY_RUN=true (line 19 in 02_Audiobooks to ABS.sh)
./02_Audiobooks\ to\ ABS.sh
```

### Running Scripts
```bash
# Make scripts executable if needed
chmod +x 01_Download_Sort.sh "02_Audiobooks to ABS.sh"

# Run download sort with options
./01_Download_Sort.sh [--force] [--dry-run] [--verbose] [input_dir_or_file]

# Run post-Beets processing
./02_Audiobooks\ to\ ABS.sh
```

## Architecture Notes

### Workflow Pipeline
1. **Download Phase**: qBittorrent downloads trigger 01_Download_Sort.sh
2. **Conversion Phase**: MP3/M4A files sent to autom4b for M4B conversion
3. **Tagging Phase**: Beets processes M4B files with Audible metadata
4. **Post-Processing**: 02_Audiobooks to ABS.sh finalizes organization

### File Organization Pattern
Both scripts follow similar patterns:
- Use of associative arrays for mapping file types to directories
- Comprehensive logging with timestamped entries
- Support for dry-run testing
- Configurable ownership and permissions for Unraid compatibility
- Log files stored in input directories for easy debugging

### Integration Points
- **qBittorrent**: Calls 01_Download_Sort.sh on download completion
- **Beets**: Uses provided beets-audible.config.yaml for audiobook-specific configuration
- **autom4b**: Receives non-M4B audio files for conversion
- **Calibre**: Receives ebook files (EPUB, MOBI, PDF) for library import
- **AudioBookshelf (ABS)**: Final destination for processed audiobooks

## Important Implementation Details

- Scripts are designed specifically for Unraid environments
- Both scripts maintain detailed logs in their respective directories
- File operations use rsync for reliability and permission preservation
- Scripts handle special cases like multiple audiobooks per directory
- CUE file correction functionality to match M4B filenames
- Automatic cover.jpg ↔ folder.jpg synchronization for compatibility
- Recursive empty directory cleanup after file moves

## Beets Configuration

The `beets-audible.config.yaml` file configures Beets for audiobook processing:
- **Plugins**: audible, copyartifacts, edit, fromfilename, scrub, web, permissions
- **Path organization**: Series-based folder structure with position numbering
- **Audible integration**: Fetches metadata, cover art, and chapter information
- **Sidecar files**: Preserves metadata.yml, cover images, cue files, and other artifacts