What I wanted was to standardize my entire library using a single MP4 as the audio file format. I also wanted the directory naming and structure to be exactly the same for all books with accurate metadata.
So I created a workflow that works for me. I start by manually finding and downloading the books I want, then the sort script copies them into folders to be processed as needed:

Ebooks go to the Calibre import directory
Single M4B files go to the import directory for beets
Multi-M4B and all other audio files go to auto-m4b to be converted into a single M4B
Auto-m4b output goes to the beets import directory
Beets gets everything named using the standard method I want to use
Audiobooks to ABS does the final touches and moves everything into Audiobookshelf

# Audiobook Processing Scripts

Automated audiobook processing pipeline for Unraid systems, integrating qBittorrent, Beets with Audible plugin, autom4b, and AudioBookshelf (ABS).

---

## Table of Contents

- [Workflow Overview](#workflow-overview)
- [1. qBittorrent Setup](#1-qbittorrent-setup)
- [2. Download Sort Script](#2-download-sort-script-01_download_sortsh)
- [3. Beets with Audible Plugin](#3-beets-with-audible-plugin)
- [4. Post-Processing to ABS](#4-post-processing-to-abs-02_audiobooks-to-abssh)
- [5. AudioBookshelf Integration](#5-audiobookshelf-integration)
- [Complete Workflow Example](#complete-workflow-example)
- [Troubleshooting](#troubleshooting)
- [Requirements](#requirements)
- [License](#license)

---

## Workflow Overview

```
qBittorrent → 01_Download_Sort.sh → Beets (audible plugin) → 02_Audiobooks to ABS.sh → AudioBookshelf
                                    ↓
                                 autom4b (for MP3/M4A conversion)
```

This pipeline automates the entire audiobook workflow from download to library:

1. **qBittorrent** downloads audiobooks and triggers sorting script on completion
2. **01_Download_Sort.sh** sorts files by type into appropriate processing directories
3. **Beets with Audible plugin** fetches metadata and organizes files
4. **02_Audiobooks to ABS.sh** performs final processing and moves to library
5. **AudioBookshelf** serves the organized audiobook library

---

## 1. qBittorrent Setup

### Configure Download Completion Action
1. In qBittorrent settings, go to **Downloads** → **Run external program on torrent completion**
2. Add the following command:
   ```
   /path/to/01_Download_Sort.sh "%F"
   ```
   - `%F` passes the content path (file or folder) to the script
   - The script will automatically sort downloaded files by type

### Categories (Optional)
Create a category for audiobooks to organize downloads:
- Category name: `audiobooks`
- Save path: `/mnt/user/downloads/audiobooks`

---

## 2. Download Sort Script (01_Download_Sort.sh)

### Purpose
Automatically sorts downloaded files by type into appropriate processing directories when triggered by qBittorrent.

### File Type Routing
- **MP3/M4A** → autom4b directory for M4B conversion
- **M4B** → Beets untagged directory (single files) or configurable multi-M4B destination (multiple files)
- **EPUB/MOBI/PDF** → Calibre import directory
- **Other audio formats** (FLAC, OGG, WMA, etc.) → autom4b for conversion

### Special Multi-M4B Handling
When enabled, directories containing multiple M4B files are redirected to a separate destination (typically autom4b for processing). This prevents conflicts in the Beets tagging process which often expects single audiobook files per directory.

### Configuration
Edit lines 17-35 to customize directories:
```bash
INPUT_DIR="/path/to/downloads/complete"
LOG_DIR="/path/to/downloads/complete/logs"

# File type destination mapping
FILETYPE_DIRS=(
    ["mp3"]="/path/to/autom4b/input"
    ["m4a"]="/path/to/autom4b/input"
    ["m4b"]="/path/to/beets/untagged"
    ["epub"]="/path/to/calibre/import"
    # ... additional mappings
)

# Multi-M4B handling configuration
ENABLE_MULTI_M4B_REDIRECT=true                    # Enable special handling for multiple M4B files
MULTI_M4B_DEST_DIR="/path/to/autom4b/input"       # Where to send directories with multiple M4B files
```

### Usage
```bash
# Manual run
./01_Download_Sort.sh [options] [input_path]

# Options
--force     # Force processing even if files were recently modified
--dry-run   # Test mode - show what would happen without making changes
--verbose   # Enable detailed logging
```

### Logging
- Logs stored in: `$LOG_DIR/`
- Format: `download_sort_YYYY-MM-DD.log`

---

## 3. Beets with Audible Plugin

### Installation
```bash
# Install beets and audible plugin
pip install beets
pip install beets-audible
```

### Configuration (beets-audible.config.yaml)
Key configuration sections:

```yaml
directory: /path/to/audiobooks/library
library: /path/to/beets/musiclibrary.db

import:
  move: yes
  write: yes

plugins: audible copyartifacts edit fromfilename scrub web permissions

audible:
  fetch_art: yes
  fetch_chapters: yes
  match_chapters: yes

paths:
  audiobook:series: $series/$series {$series_position} - $title/$series {$series_position} - $title
  audiobook:^series: $artist/$title/$title

copyartifacts:
  extensions: .yml .yaml .jpg .jpeg .png .pdf .txt .nfo .cue .m3u
```

### Running Beets
```bash
# Import audiobooks from untagged directory
beet -c beets-audible.config.yaml import /path/to/beets/untagged

# Interactive import with manual search
beet -c beets-audible.config.yaml import -s /path/to/beets/untagged
```

### What Beets Does
1. Fetches metadata from Audible
2. Organizes files into series/title structure
3. Embeds metadata into M4B files
4. Downloads cover art
5. Creates chapter files
6. Preserves sidecar files (metadata.yml, cover images, etc.)

---

## 4. Post-Processing to ABS (02_Audiobooks to ABS.sh)

### Purpose
Final processing after Beets tagging - renames sidecar files, fixes CUE files, and moves to AudioBookshelf library.

### Key Features
- Renames sidecar files to match audiobook filename
- Corrects CUE file references
- Synchronizes cover.jpg ↔ folder.jpg
- Moves processed files to final library location
- Cleans up empty directories

### Configuration
Edit lines 5-44 to customize:
```bash
INPUT_DIR="/path/to/beets/processed"
MOVE_TARGET="/path/to/audiobookshelf/library"
LOG_FILE="$INPUT_DIR/audiobook_processing.log"
OVERWRITE_POLICY="never"  # Options: never, always, newer, larger
```

### Usage
```bash
# Run post-processing
./02_Audiobooks\ to\ ABS.sh

# Test mode (edit script to set DRY_RUN=true)
DRY_RUN=true ./02_Audiobooks\ to\ ABS.sh
```

### Processing Steps
1. Scans for audiobook files (M4B, MP3, M4A)
2. Renames associated sidecar files to match audiobook
3. Updates CUE file internal references
4. Ensures both cover.jpg and folder.jpg exist
5. Moves entire directory to AudioBookshelf library
6. Sets proper ownership (99:100 for Unraid)

---

## 5. AudioBookshelf Integration

### Library Setup
1. In AudioBookshelf, add library pointing to: `/path/to/audiobookshelf/library`
2. Enable folder watching for automatic imports
3. Configure metadata preferences to use embedded tags

### Directory Structure
Final organized structure:
```
/path/to/audiobookshelf/library/
├── Author Name/
│   ├── Series Name/
│   │   ├── Series Name 01 - Book Title/
│   │   │   ├── Book Title - Author Name.m4b
│   │   │   ├── Book Title - Author Name.cue
│   │   │   ├── cover.jpg
│   │   │   ├── folder.jpg
│   │   │   └── metadata.yml
│   │   └── Series Name 02 - Second Book/
│   │       └── ...
│   └── Standalone Book/
│       └── Standalone Book - Author Name.m4b
└── Another Author/
    └── ...
```

---

## Complete Workflow Example

1. **Download**: qBittorrent downloads audiobook torrent
2. **Sort**: On completion, triggers `01_Download_Sort.sh`
   - MP3 files → sent to autom4b for M4B conversion
   - M4B files → sent to Beets untagged directory
3. **Tag**: Manually run Beets to tag with Audible metadata
   ```bash
   beet -c beets-audible.config.yaml import /path/to/beets/untagged
   ```
4. **Post-Process**: Run `02_Audiobooks to ABS.sh` to finalize
5. **Library**: AudioBookshelf automatically imports from watched folder

---

## Troubleshooting

### Check Logs
- Download sort: `/path/to/downloads/complete/logs/`
- Post-processing: `/path/to/beets/processed/audiobook_processing.log`
- Beets: Run with `-v` flag for verbose output

### Common Issues

**Files not moving from downloads**
- Check qBittorrent is calling script with correct path
- Verify script has execute permissions: `chmod +x 01_Download_Sort.sh`
- Run manually with `--verbose` flag to see detailed output

**Beets not finding matches**
- Use interactive mode: `beet import -s`
- Try from filename: `beet import -f`
- Check Audible plugin is installed: `pip list | grep audible`

**Sidecar files not renamed**
- Check `OVERWRITE_POLICY` setting in `02_Audiobooks to ABS.sh`
- Verify file permissions (should be 99:100 for Unraid)
- Run with `DRY_RUN=true` to test

**AudioBookshelf not importing**
- Verify library path matches `MOVE_TARGET`
- Check folder watching is enabled
- Ensure proper permissions on target directory

---

## Requirements

- Unraid or Linux system
- Bash 4.0+ (for associative arrays)
- Python 3.6+ (for Beets)
- qBittorrent
- Beets with audible plugin
- autom4b (optional, for audio conversion)
- AudioBookshelf server

---

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
