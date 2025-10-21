What I wanted was to standardize my entire library using a single M4B as the audio file format. I also wanted the directory naming and structure to be exactly the same for all books with accurate metadata.
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
- [Unraid Docker Setup Guide](#unraid-docker-setup-guide)
  - [Install Docker Containers](#part-1-install-required-docker-containers)
  - [Configure Beets](#part-2-configure-beets-for-audiobook-processing)
  - [Configure Scripts](#part-3-configure-processing-scripts)
  - [Verification & Testing](#part-4-verification-and-testing)
- [Standard Linux Setup](#standard-linux-setup)
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

## Unraid Docker Setup Guide

This section provides complete setup instructions for Unraid users using Docker containers. If you're running standard Linux, skip to [Standard Linux Setup](#standard-linux-setup).

### Overview

You'll install three Docker containers:
- **autom4b** - Converts audio files (MP3, M4A, FLAC) to M4B format
- **Beets** - Tags audiobooks with Audible metadata
- **qBittorrent** - Downloads audiobooks (if not already installed)

### Part 1: Install Required Docker Containers

#### 1.1 Install autom4b

1. Open **Community Applications** in Unraid
2. Search for "autom4b"
3. Install and configure:
   - **Input Directory**: `/mnt/user/Media/Processing/autom4b_input`
   - **Output Directory**: `/mnt/user/Media/Processing/beets_untagged`
4. Start the container

#### 1.2 Install Beets (with Audible Plugin)

**CRITICAL VERSION REQUIREMENT**: The Audible plugin for Beets from linuxserver.io only supports up to **version 2.3.0**.

1. Open **Community Applications** and search for "beets"
2. Select the **linuxserver/beets** template
3. **Before installing**, change the **Repository** field to:
   ```
   lscr.io/linuxserver/beets:2.3.0
   ```
4. Configure basic paths:
   - **Config Directory**: `/mnt/user/appdata/beets`
   - **Music/Audiobooks Directory**: `/mnt/user/Media/Processing/beets_tagged`
   - **Downloads**: `/mnt/user/Media/Processing/beets_untagged`
5. Click "Apply" to install the container
6. **Start the container** (creates initial config directory structure)
7. **Stop the container** (we need to modify configs before running properly)

### Part 2: Configure Beets for Audiobook Processing

#### 2.1 Replace Default Configuration

1. **Navigate** to `/mnt/user/appdata/beets` on your Unraid server
2. **Backup the default config**:
   ```bash
   mv config.yaml config.yaml.stock
   ```
3. **Copy custom configuration files** from this repository:
   - Copy `beets-audible.config.yaml` → `/mnt/user/appdata/beets/`
   - Copy `custom-cont-init.d/` directory → `/mnt/user/appdata/beets/`
4. **Rename the custom config**:
   ```bash
   mv beets-audible.config.yaml config.yaml
   ```
5. **Edit `config.yaml`** to match your directory paths:
   - Update `directory:` to your final library location
   - Verify paths match your Docker container mappings
   - Save the file

#### 2.2 Add Docker Mod for Plugin Installation

This enables automatic installation of required Beets plugins on container startup.

1. **Edit the Beets container** in Unraid's Docker UI
2. Click **"Add another Path, Port, Variable, Label or Device"**
3. Configure the new path:
   - **Config Type**: Path
   - **Name**: `custom-cont-init.d`
   - **Container Path**: `/custom-cont-init.d`
   - **Host Path**: `/mnt/user/appdata/beets/custom-cont-init.d/`
   - **Access Mode**: Read Only
4. Click "Apply" to save

#### 2.3 Start Beets and Verify

1. **Start the Beets container**
2. **Check container logs** to verify:
   - `install-deps.sh` executed successfully
   - Plugins installed: `beets-audible`, `beets-copyartifacts3`, `beets[web]`

### Part 3: Configure Processing Scripts

#### 3.1 Configure 01_Download_Sort.sh

1. Open `01_Download_Sort.sh` in a text editor
2. Update configuration variables (lines 17-35):
   ```bash
   INPUT_DIR="/mnt/user/Downloads/complete"
   LOG_DIR="/mnt/user/Downloads/complete/logs"

   FILETYPE_DIRS=(
       ["mp3"]="/mnt/user/Media/Processing/autom4b_input"
       ["m4a"]="/mnt/user/Media/Processing/autom4b_input"
       ["m4b"]="/mnt/user/Media/Processing/beets_untagged"
       ["epub"]="/mnt/user/Media/Processing/calibre_import"
   )

   ENABLE_MULTI_M4B_REDIRECT=true
   MULTI_M4B_DEST_DIR="/mnt/user/Media/Processing/autom4b_input"
   ```
3. Make executable:
   ```bash
   chmod +x 01_Download_Sort.sh
   ```

#### 3.2 Configure 02_Audiobooks to ABS.sh

1. Open `02_Audiobooks to ABS.sh` in a text editor
2. Update configuration variables (lines 5-44):
   ```bash
   INPUT_DIR="/mnt/user/Media/Processing/beets_tagged"
   MOVE_TARGET="/mnt/user/Media/Audiobooks"
   OVERWRITE_POLICY="newer"
   PUID=99
   PGID=100
   ```
3. Make executable:
   ```bash
   chmod +x "02_Audiobooks to ABS.sh"
   ```

#### 3.3 Integrate with qBittorrent

1. Open **qBittorrent settings**
2. Navigate to **Downloads** → **Run external program on torrent completion**
3. Enable and add:
   ```bash
   /mnt/user/scripts/audiobook-processing/01_Download_Sort.sh "%F"
   ```
   (Adjust path to where you stored the script)

### Part 4: Verification and Testing

#### 4.1 Test Download Sorting

```bash
# Dry run test
./01_Download_Sort.sh --dry-run --verbose /path/to/test/audiobook
```

Review output to ensure files would route correctly.

#### 4.2 Test Complete Pipeline

1. **Download a test audiobook** via qBittorrent
2. **Verify file sorting**:
   - Check logs: `$LOG_DIR/download_sort_*.log`
   - Verify files moved to autom4b input (if MP3/M4A) or beets_untagged (if M4B)
3. **Wait for autom4b** to convert (if applicable)
4. **Run Beets import**:
   ```bash
   docker exec -it beets beet import /downloads
   ```
5. **Run post-processing**:
   ```bash
   ./02_Audiobooks\ to\ ABS.sh
   ```
6. **Verify** files in final library location

#### 4.3 Directory Structure Example

Your final directory structure should look like:
```
/mnt/user/Media/
├── Downloads/              # qBittorrent download location
├── Processing/
│   ├── autom4b_input/     # 01_Download_Sort.sh sends MP3/M4A here
│   ├── beets_untagged/    # autom4b outputs + single M4B files
│   └── beets_tagged/      # Beets outputs tagged audiobooks
└── Audiobooks/            # Final library (AudioBookshelf)
```

---

## Standard Linux Setup

The following sections apply to standard Linux installations (non-Docker) or provide additional configuration details for both Unraid and Linux systems.

### 1. qBittorrent Setup

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
./02_Audiobooks_to_ABS.sh

# Test mode (edit script to set DRY_RUN=true)
DRY_RUN=true ./02_Audiobooks_to_ABS.sh
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
4. **Post-Process**: Run `02_Audiobooks_to_ABS.sh` to finalize
5. **Library**: AudioBookshelf automatically imports from watched folder

---

## Troubleshooting

### Check Logs
- Download sort: `/path/to/downloads/complete/logs/`
- Post-processing: `/path/to/beets/processed/audiobook_processing.log`
- Beets: Run with `-v` flag for verbose output
- Docker containers: Check Unraid Docker tab for container logs

### Common Issues

**Files not moving from downloads**
- Check qBittorrent is calling script with correct path
- Verify script has execute permissions: `chmod +x 01_Download_Sort.sh`
- Run manually with `--verbose` flag to see detailed output
- For Unraid: Ensure qBittorrent has access to script location

**Beets not finding matches**
- Use interactive mode: `beet import -s`
- Try from filename: `beet import -f`
- Check Audible plugin is installed: `pip list | grep audible` (Linux) or `docker exec beets pip list | grep audible` (Unraid)

**Sidecar files not renamed**
- Check `OVERWRITE_POLICY` setting in `02_Audiobooks_to_ABS.sh`
- Verify file permissions (should be 99:100 for Unraid)
- Run with `DRY_RUN=true` to test

**AudioBookshelf not importing**
- Verify library path matches `MOVE_TARGET`
- Check folder watching is enabled
- Ensure proper permissions on target directory

### Unraid Docker-Specific Issues

**Beets plugins not installing**
- **Symptoms**: Beets doesn't recognize `audible` plugin commands
- **Solutions**:
  1. Check container logs for errors during startup
  2. Verify `custom-cont-init.d` path mapping is correct
  3. Ensure `install-deps.sh` has execute permissions
  4. Manually install: `docker exec -it beets pip install beets-audible beets-copyartifacts3 beets[web]`

**Metadata not fetching from Audible**
- **Symptoms**: Beets imports audiobooks but without Audible metadata
- **Solutions**:
  1. Verify Audible plugin installed: `docker exec beets beet version`
  2. Check `config.yaml` has `audible` in plugins list
  3. Ensure audiobook files have reasonable filenames for matching
  4. Try manual fetch: `docker exec beets beet audible -f`

**Version compatibility issues**
- **Symptoms**: Audible plugin errors after Beets update
- **Solutions**:
  1. Verify container running version 2.3.0: `docker exec beets beet version`
  2. If updated accidentally, change repository back to `lscr.io/linuxserver/beets:2.3.0`
  3. Recreate the container with correct version

**Permission errors in Docker containers**
- **Symptoms**: Files created with wrong ownership, access denied errors
- **Solutions**:
  1. Verify PUID=99 and PGID=100 in Docker container settings
  2. Check host paths are accessible by user nobody (99:100)
  3. Manually fix: `chown -R 99:100 /mnt/user/Media/Processing/`

**Path mapping issues**
- **Symptoms**: Container can't find files, "No such file or directory" errors
- **Solutions**:
  1. Verify all Docker path mappings are correct in container settings
  2. Ensure host paths actually exist
  3. Check paths in `config.yaml` match container paths (not host paths)
  4. Example: If host path is `/mnt/user/Media/Processing/beets_untagged` and container path is `/downloads`, use `/downloads` in config.yaml

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
