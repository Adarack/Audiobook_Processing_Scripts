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
  - [File Permissions](#important-file-permissions-on-unraid)
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
- [Daily Usage Guide](#daily-usage-guide)
  - [Managing autom4b](#managing-autom4b)
  - [Using Beets for Tagging](#using-beets-for-audiobook-tagging)
  - [Running Post-Processing](#running-post-processing)
  - [Detailed Step-by-Step Workflow](#detailed-step-by-step-workflow)
  - [Additional Tips](#additional-tips)
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

### Important: File Permissions on Unraid

**CRITICAL**: All Docker containers must use the same user/group permissions to access shared files.

On Unraid, the standard user:group is **nobody:users**, which corresponds to:
- **PUID** = 99
- **PGID** = 100
- **UMASK** = 002

**You must configure these environment variables for:**
- autom4b container
- Beets container
- qBittorrent container

**How to add/verify these variables:**

1. **Edit the container** in Unraid's Docker UI
2. Click **"Add another Path, Port, Variable, Label or Device"**
3. Select **"Variable"** as Config Type
4. Add each variable if it doesn't exist:

   **Variable 1:**
   - **Name**: `PUID`
   - **Key**: `PUID`
   - **Value**: `99`

   **Variable 2:**
   - **Name**: `PGID`
   - **Key**: `PGID`
   - **Value**: `100`

   **Variable 3:**
   - **Name**: `UMASK`
   - **Key**: `UMASK`
   - **Value**: `002`

5. Click **"Apply"** to save changes
6. **Restart the container** for changes to take effect

> **Why this matters**: Without matching permissions, containers won't be able to read/write files created by other containers, causing the pipeline to fail.

---

### Part 1: Install Required Docker Containers

#### 1.1 Install autom4b

1. Open **Community Applications** in Unraid
2. Search for "autom4b"
3. Install and configure:
   - **Input Directory**: `/mnt/user/Media/Processing/autom4b_input`
   - **Output Directory**: `/mnt/user/Media/Processing/beets_untagged`
4. **Set permissions** (CRITICAL):
   - Add/verify environment variables: `PUID=99`, `PGID=100`, `UMASK=002`
   - See [File Permissions](#important-file-permissions-on-unraid) section above for detailed instructions
5. Start the container (creates initial directory structure)
6. **Stop the container** (keep it stopped until manually needed)
   - This prevents autom4b from processing files before they're fully copied
   - You'll manually start it when ready to convert files (see [Daily Usage Guide](#managing-autom4b))

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
5. **Set permissions** (CRITICAL):
   - Add/verify environment variables: `PUID=99`, `PGID=100`, `UMASK=002`
   - See [File Permissions](#important-file-permissions-on-unraid) section above for detailed instructions
6. Click "Apply" to install the container
7. **Start the container** (creates initial config directory structure)
8. **Stop the container** (we need to modify configs before running properly)

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
     - This directory contains `install-deps.sh` which automatically installs required Beets plugins on container startup
4. **Rename the custom config**:
   ```bash
   mv beets-audible.config.yaml config.yaml
   ```
5. **Edit `config.yaml`** to match your directory paths:
   - Update `directory:` to your Beets output directory (this becomes the input for `02_Audiobooks_to_ABS.sh`)
   - Example: `/mnt/user/Media/Processing/beets_tagged`
   - Verify paths match your Docker container mappings
   - Save the file
6. **Add Docker path mapping for `custom-cont-init.d`**:
   - **Edit the Beets container** in Unraid's Docker UI
   - Click **"Add another Path, Port, Variable, Label or Device"**
   - Configure the new path:
     - **Config Type**: Path
     - **Name**: `custom-cont-init.d`
     - **Container Path**: `/custom-cont-init.d`
     - **Host Path**: `/mnt/user/appdata/beets/custom-cont-init.d/`
     - **Access Mode**: Read Only
   - Click "Apply" to save

#### 2.2 Start Beets and Verify

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

> **Note**: If you haven't already, ensure your qBittorrent container has the correct permissions set: `PUID=99`, `PGID=100`, `UMASK=002`. See [File Permissions](#important-file-permissions-on-unraid) for instructions.

**Method 1: Via qBittorrent UI**

1. Open **qBittorrent settings**
2. Navigate to **Downloads** → **Run external program on torrent completion**
3. Enable and add (use the Docker container's internal path):
   ```
   "/config/config/01_Download_Sort.sh" "%F"
   ```
   > **Important**: Use the path as seen from **inside** the qBittorrent container, not the host path.
   > Example: If your script is at `/mnt/user/appdata/qbittorrent/config/01_Download_Sort.sh` on the host, use `/config/config/01_Download_Sort.sh` in qBittorrent.
4. Click **Apply** to save

**Method 2: Manual Configuration (if UI doesn't save)**

If qBittorrent doesn't allow you to enable the script via the UI, or the settings aren't saving:

1. **Stop the qBittorrent container**
2. **Navigate to qBittorrent's appdata directory**:
   ```bash
   cd /mnt/user/appdata/qbittorrent
   ```
   > **Note**: You may need to use Unraid CLI (`ls` and `cd` commands) to find the exact path on your system.

3. **Edit `qBittorrent.conf`**:
   ```bash
   nano qBittorrent.conf
   ```

4. **Find or add the `[AutoRun]` section**:
   ```ini
   [AutoRun]
   enabled=true
   program="/config/config/01_Download_Sort.sh" "%F"
   ```

5. **Save and exit** (Ctrl+O, Enter, Ctrl+X in nano)
6. **Restart the qBittorrent container**

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
   docker exec -it beets-audible beet import /downloads
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

#### Configure Download Completion Action
1. In qBittorrent settings, go to **Downloads** → **Run external program on torrent completion**
2. Add the following command:
   ```
   /path/to/01_Download_Sort.sh "%F"
   ```
   - `%F` passes the content path (file or folder) to the script
   - The script will automatically sort downloaded files by type

#### Categories (Optional)
Create a category for audiobooks to organize downloads:
- Category name: `audiobooks`
- Save path: `/mnt/user/downloads/audiobooks`

---

### 2. Download Sort Script (01_Download_Sort.sh)

#### Purpose
Automatically sorts downloaded files by type into appropriate processing directories when triggered by qBittorrent.

#### File Type Routing
- **MP3/M4A** → autom4b directory for M4B conversion
- **M4B** → Beets untagged directory (single files) or configurable multi-M4B destination (multiple files)
- **EPUB/MOBI/PDF** → Calibre import directory
- **Other audio formats** (FLAC, OGG, WMA, etc.) → autom4b for conversion

#### Special Multi-M4B Handling
When enabled, directories containing multiple M4B files are redirected to a separate destination (typically autom4b for processing). This prevents conflicts in the Beets tagging process which often expects single audiobook files per directory.

#### Configuration
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

#### Usage
```bash
# Manual run
./01_Download_Sort.sh [options] [input_path]

# Options
--force     # Force processing even if files were recently modified
--dry-run   # Test mode - show what would happen without making changes
--verbose   # Enable detailed logging
```

#### Logging
- Logs stored in: `$LOG_DIR/`
- Format: `download_sort_YYYY-MM-DD.log`

---

### 3. Beets with Audible Plugin

#### Installation
```bash
# Install beets and audible plugin
pip install beets
pip install beets-audible
```

#### Configuration (beets-audible.config.yaml)
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

#### Running Beets
```bash
# Import audiobooks from untagged directory
beet -c beets-audible.config.yaml import /path/to/beets/untagged

# Interactive import with manual search
beet -c beets-audible.config.yaml import -s /path/to/beets/untagged
```

#### What Beets Does
1. Fetches metadata from Audible
2. Organizes files into series/title structure
3. Embeds metadata into M4B files
4. Downloads cover art
5. Creates chapter files
6. Preserves sidecar files (metadata.yml, cover images, etc.)

---

### 4. Post-Processing to ABS (02_Audiobooks to ABS.sh)

#### Purpose
Final processing after Beets tagging - renames sidecar files, fixes CUE files, and moves to AudioBookshelf library.

#### Key Features
- Renames sidecar files to match audiobook filename
- Corrects CUE file references
- Synchronizes cover.jpg ↔ folder.jpg
- Moves processed files to final library location
- Cleans up empty directories

#### Configuration
Edit lines 5-44 to customize:
```bash
INPUT_DIR="/path/to/beets/processed"
MOVE_TARGET="/path/to/audiobookshelf/library"
LOG_FILE="$INPUT_DIR/audiobook_processing.log"
OVERWRITE_POLICY="never"  # Options: never, always, newer, larger
```

#### Usage
```bash
# Run post-processing
./02_Audiobooks_to_ABS.sh

# Test mode (edit script to set DRY_RUN=true)
DRY_RUN=true ./02_Audiobooks_to_ABS.sh
```

#### Processing Steps
1. Scans for audiobook files (M4B, MP3, M4A)
2. Renames associated sidecar files to match audiobook
3. Updates CUE file internal references
4. Ensures both cover.jpg and folder.jpg exist
5. Moves entire directory to AudioBookshelf library
6. Sets proper ownership (99:100 for Unraid)

---

### 5. AudioBookshelf Integration

#### Library Setup
1. In AudioBookshelf, add library pointing to: `/path/to/audiobookshelf/library`
2. Enable folder watching for automatic imports
3. Configure metadata preferences to use embedded tags

#### Directory Structure
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

## Daily Usage Guide

This section covers day-to-day operation of the audiobook processing pipeline after initial setup.

### Managing autom4b

#### Recommended Workflow: Manual Start

**Important**: It's recommended to keep autom4b **stopped** until you're ready to process files.

**Why?**
- autom4b may start processing files before `01_Download_Sort.sh` finishes copying all files
- This can cause incomplete conversions or errors
- Manual control ensures all files are ready before conversion begins

#### When to Start autom4b

Start autom4b after:
1. `01_Download_Sort.sh` has finished sorting files
2. All expected files are present in the autom4b input directory
3. You've verified the files via `ls` or the Unraid file browser

#### How to Start autom4b (Unraid)

1. **Navigate to the Docker tab** in Unraid
2. **Find the autom4b container**
3. **Click "Start"**
4. **Monitor progress** via Docker logs (see below)
5. **Stop the container** after processing completes (optional)

#### Monitoring autom4b Progress

**View real-time logs**:
```bash
docker logs -f autom4b
```
Press `Ctrl+C` to exit log viewing.

**Check for completion**:
- Look for "Conversion complete" messages in logs
- Check the output directory: `/mnt/user/Media/Processing/beets_untagged`
- Verify M4B files were created with expected file sizes

#### Troubleshooting autom4b

**Container starts automatically**:
- Set the container to **not auto-start** in Docker settings
- Unraid: Toggle off the "Autostart" switch in the Docker tab (next to the container)

**Files processing too early**:
- Stop autom4b immediately if it starts during file copy
- Wait for `01_Download_Sort.sh` to complete
- Restart autom4b after all files are copied

**Conversion fails or produces errors**:
- Check input files are complete (not truncated)
- Ensure enough disk space in output directory
- Review autom4b logs for specific error messages

---

### Using Beets for Audiobook Tagging

Beets is the core tagging tool in this pipeline, but it's **not fully automated**—it requires manual intervention for many audiobooks.

#### Accessing the Beets Container

**For Unraid Docker Setup**

SSH into your Unraid server, then enter the Beets container shell:

```bash
docker exec -it beets-audible bash
```

**Command breakdown**:
- `docker exec` - Execute a command in a running container
- `-it` - Interactive terminal (combination of `-i` and `-t`)
- `beets-audible` - Name of the container
- `bash` - Command to run (starts a bash shell)

Alternatively, use the **Unraid web terminal**:
1. Go to the Unraid web interface
2. Click the **Terminal** icon in the top-right
3. Run the same `docker exec` command

---

#### Docker Exec Flags and Options

Here are the most useful flags for working with Docker containers:

**Interactive and Terminal Options**:

| Flag | Description | When to Use |
|------|-------------|-------------|
| `-i` / `--interactive` | Keep STDIN open even if not attached | Run interactive commands |
| `-t` / `--tty` | Allocate a pseudo-TTY (terminal) | Get a proper terminal interface |
| `-it` | Combined: interactive terminal | **Most common** - access container shell |
| `-d` / `--detach` | Run command in background | Long-running commands |

**User and Environment Options**:

| Flag | Description | When to Use |
|------|-------------|-------------|
| `-u` / `--user <user>` | Run as specific user (e.g., `-u 99:100`) | Override container's default user |
| `-e` / `--env <VAR=value>` | Set environment variables | Pass config to commands |
| `--env-file <file>` | Read environment variables from file | Multiple environment variables |
| `-w` / `--workdir <path>` | Set working directory inside container | Run commands in specific directory |

**Privilege and Capability Options**:

| Flag | Description | When to Use |
|------|-------------|-------------|
| `--privileged` | Give extended privileges to command | Advanced system operations (use carefully) |
| `--user root` | Run as root user | Need admin permissions in container |

---

#### Common Docker Exec Command Examples

**Enter container shell** (most common):
```bash
docker exec -it beets-audible bash
```

**Run single command** (without entering shell):
```bash
docker exec beets-audible beet version
```

**Run command as specific user**:
```bash
docker exec -u 99:100 beets-audible beet import /input
```

**Run command in background**:
```bash
docker exec -d beets-audible beet import -q /input
```

**Run command with environment variable**:
```bash
docker exec -e BEETSDIR=/config beets-audible beet config
```

**Run command in specific directory**:
```bash
docker exec -w /downloads beets-audible ls -la
```

**Check container logs** (not exec, but related):
```bash
docker logs -f beets-audible
```

**List running containers**:
```bash
docker ps
```

**List all containers** (including stopped):
```bash
docker ps -a
```

---

#### Common Container Operations

**For autom4b**:
```bash
# Enter shell
docker exec -it autom4b bash

# Check logs
docker logs -f autom4b

# Run command
docker exec autom4b ls /config
```

**For qBittorrent**:
```bash
# Enter shell
docker exec -it qbittorrent bash

# Check config
docker exec qbittorrent cat /config/qBittorrent/qBittorrent.conf
```

**For Beets**:
```bash
# Enter shell
docker exec -it beets-audible bash

# Check Beets version
docker exec beets-audible beet version

# Import audiobooks (non-interactive)
docker exec beets-audible beet import -q /input

# List Beets library
docker exec beets-audible beet ls
```

---

**For Standard Linux Setup**

If running Beets natively (non-Docker):

```bash
# Navigate to your Beets config directory
cd /path/to/beets
```

#### Running the Import Command

Once inside the Beets shell (or working directory):

**Basic import command**:
```bash
beet import -m --from-scratch /input
```

**Command breakdown**:
- `beet import` - Import new audiobooks
- `-m` - Use manual search (interactive mode)
- `--from-scratch` - Ignore previous import history and re-scan from scratch
- `/input` - Path to the untagged audiobooks directory (adjust based on your Docker mapping)

> **Docker path note**: Use the container's internal path (e.g., `/input`), not the host path (e.g., `/mnt/user/Media/Processing/beets_untagged`).

---

#### Common Import Flags and Options

Here are the most useful flags for importing audiobooks:

**Interactive and Search Options**:

| Flag | Description | When to Use |
|------|-------------|-------------|
| `-m` / `--search-id` | Manual search mode - prompts for ASIN or search terms | When auto-matching fails or you want control |
| `-s` / `--singleton` | Import individual tracks instead of full albums | For single audiobook files without album structure |
| `-t` / `--timid` | Always ask for confirmation before making changes | When you want to review every decision |
| `-p` / `--pretend` | Dry-run mode - show what would happen without importing | Testing before real import |
| `-q` / `--quiet` | Suppress output except for errors | For automated scripts |

**Duplicate and Re-import Options**:

| Flag | Description | When to Use |
|------|-------------|-------------|
| `--from-scratch` | Re-scan directory ignoring previous import history | Re-importing after fixing files |
| `-I` / `--incremental` | Skip directories that have been imported before | Only import new audiobooks |
| `--flat` | Import all files in directory tree as single albums | For non-standard directory structures |

**Metadata and Tagging Options**:

| Flag | Description | When to Use |
|------|-------------|-------------|
| `-A` / `--noautotag` | Don't auto-tag, import as-is | When metadata already exists and is correct |
| `-W` / `--write` | Write tags to files immediately | Ensure tags are saved during import |
| `-C` / `--nocopy` | Don't copy files (link or move instead) | Save disk space if possible |
| `--move` | Move files instead of copying | When you don't need to keep originals |

**Path and Location Options**:

| Flag | Description | When to Use |
|------|-------------|-------------|
| `-g` / `--group-albums` | Group multiple directories as single album | For multi-disc audiobooks |
| `-l` / `--log <file>` | Log import decisions to a file | Keeping records of imports |

---

#### Common Import Command Examples

**Recommended for most imports** (interactive with manual search):
```bash
beet import -m --from-scratch /input
```

**Re-import after making changes** (force re-scan):
```bash
beet import -m --from-scratch /input/Audiobook_Name
```

**Import without auto-tagging** (keep existing metadata):
```bash
beet import -A /input/Audiobook_Name
```

**Quiet import for automation** (minimal output):
```bash
beet import -q /input
```

**Dry-run to test** (see what would happen):
```bash
beet import -p -m /input/Audiobook_Name
```

**Import single file** (not an album):
```bash
beet import -s /input/single_audiobook.m4b
```

**Incremental import** (skip already imported):
```bash
beet import -m -I /input
```

---

#### Recommended Workflow

For best results with audiobook imports:

1. **Start with manual search mode**:
   ```bash
   beet import -m --from-scratch /input
   ```

2. **Review each match** - Beets will show confidence scores
3. **Enter ASIN manually** when auto-match fails (see [Finding ASIN Numbers](#finding-asin-numbers-for-manual-matching))
4. **Skip problem audiobooks** - You can re-import them individually later
5. **Check the output** in `beets_tagged` directory after import completes

> **Docker path note**: Use the container's internal path (e.g., `/input`), not the host path (e.g., `/mnt/user/Media/Processing/beets_untagged`).

#### Finding ASIN Numbers for Manual Matching

Beets often can't automatically match audiobooks, especially for:
- Audiobooks with poor filename metadata
- Newer releases
- Regional variations
- Obscure titles

**How to find the correct ASIN**:

1. **Go to Audible** and search for the audiobook
2. **Open the audiobook's product page**
3. **Look at the URL**—the ASIN is the part after the book title (between the last `/` and either the end of the URL or `?`):

   Example URLs:
   ```
   https://www.audible.com/pd/Storm-Front-Audiobook/B002V8KYMI
   https://www.audible.com/pd/Storm-Front-Audiobook/B002V8KYMI?ref=...
   ```

   ASIN: `B002V8KYMI` (the part after `/Storm-Front-Audiobook/`)

   > **Tip**: Ignore everything after the `?` (query parameters) - just look for the code between the last `/` and the `?`

4. **Enter the ASIN** when Beets prompts for manual input during import

#### Interactive Import Workflow

During the import process, Beets will:

1. **Scan each audiobook directory** in `/input`
2. **Attempt automatic matching** against Audible's database
3. **Prompt you to confirm, skip, or manually search** if the match isn't confident

**Common prompts**:
- `[A]pply` - Accept the match
- `[S]kip` - Skip this audiobook for now
- `[E]nter search` - Manually enter a search query or ASIN
- `[U]se as-is` - Import without metadata (not recommended)

**Example manual search**:
```
Enter search, or aSin, or Skip, Edit, edit Candidates, plaY?
```
Type the ASIN (e.g., `B002V8KYMI`) and press Enter.

#### After Beets Import

Once Beets finishes processing:

1. **Tagged audiobooks** will be moved to the output directory configured in `beets-audible.config.yaml`
   - Default: `/mnt/user/Media/Processing/beets_tagged`

2. **Metadata and cover art** will be embedded in the M4B files

3. **Sidecar files** (e.g., `metadata.yml`, cover images, cue files) will be copied alongside the audiobook

---

### Running Post-Processing

After Beets has tagged your audiobooks, run the **post-processing script** to finalize organization.

#### When to Run

Run `02_Audiobooks_to_ABS.sh` after:
- Completing a Beets import session
- Noticing new audiobooks in the `beets_tagged` directory
- Before adding audiobooks to AudioBookshelf

#### How to Run

**Unraid via CLI**:

```bash
cd /mnt/user/appdata/scripts/
./02_Audiobooks_to_ABS.sh
```

**Standard Linux**:

```bash
cd /path/to/scripts/
./02_Audiobooks_to_ABS.sh
```

#### What It Does

The script will:
1. **Rename sidecar files** to match the audiobook filename
2. **Fix CUE file references** to point to the correct M4B file
3. **Synchronize cover images** (ensure both `cover.jpg` and `folder.jpg` exist)
4. **Move processed audiobooks** to the AudioBookshelf library directory
5. **Set correct permissions** (99:100 for Unraid compatibility)
6. **Clean up empty directories** after moving files

#### Dry Run Testing

Before running the script on real data, test with dry-run mode:

1. **Edit the script** and set `DRY_RUN=true` (line 19):
   ```bash
   nano 02_Audiobooks_to_ABS.sh
   ```

2. **Change this line**:
   ```bash
   DRY_RUN=true
   ```

3. **Run the script**:
   ```bash
   ./02_Audiobooks_to_ABS.sh
   ```

4. **Review the log output** to ensure everything looks correct

5. **Disable dry-run mode** (`DRY_RUN=false`) before running for real

---

### Detailed Step-by-Step Workflow

Here's the complete workflow from download to library with all commands:

#### 1. Download via qBittorrent

- Add audiobook torrent to qBittorrent
- Wait for download to complete
- qBittorrent automatically triggers `01_Download_Sort.sh`

#### 2. Automatic Sorting

`01_Download_Sort.sh` runs and sorts files:

- **MP3/M4A files** → sent to `autom4b` for conversion to M4B
- **Single M4B files** → sent to `beets_untagged`
- **Multiple M4B files** → sent to `autom4b` for processing
- **EPUB/MOBI/PDF files** → sent to Calibre import

**Check the logs**:
```bash
cat /mnt/user/Downloads/complete/logs/download_sort_*.log
```

#### 3. autom4b Conversion (if applicable)

If the download was in MP3 or M4A format:

**Verify files are ready**:
```bash
ls -lh /mnt/user/Media/Processing/autom4b_input/
```

**Start autom4b** (Unraid Docker):
- Go to Docker tab → Start autom4b container

**Monitor conversion progress**:
```bash
docker logs -f autom4b
```

**Wait for conversion to complete**:
- Check logs for "Conversion complete" messages
- Verify M4B files appear in `/mnt/user/Media/Processing/beets_untagged`
- **Stop autom4b** after processing (optional)

**Then proceed to Beets import**

#### 4. Tag with Beets

**SSH into Unraid** and enter the Beets container:

```bash
docker exec -it beets-audible bash
```

**Run the import**:

```bash
beet import -m --from-scratch /input
```

**Follow the prompts**:
- Review suggested matches
- Enter ASINs manually when needed (find them on Audible's website)
- Confirm or skip each audiobook

**Exit the container**:

```bash
exit
```

#### 5. Post-Process to AudioBookshelf

**Run the final processing script**:

```bash
cd /mnt/user/appdata/scripts/
./02_Audiobooks_to_ABS.sh
```

**Check the log**:

```bash
cat /mnt/user/Media/Processing/beets_tagged/audiobook_rename_*.log
```

#### 6. Verify in AudioBookshelf

- Open **AudioBookshelf** in your browser
- Navigate to your audiobook library
- **Scan for new items** (if auto-scan isn't enabled)
- Verify metadata, cover art, and chapters are correct

---

### Additional Tips

#### Batch Processing Multiple Audiobooks

If you have many audiobooks to process at once:

1. **Let qBittorrent download all audiobooks** (they'll auto-sort)
2. **Wait for autom4b conversions to complete** (if applicable)
3. **Run Beets once** to tag all pending audiobooks:
   ```bash
   docker exec -it beets-audible beet import -m --from-scratch /input
   ```
4. **Run post-processing once** after tagging is complete

#### Keeping autom4b Stopped by Default

To prevent autom4b from auto-starting on system boot:

1. **Go to the Docker tab** in Unraid
2. **Find the autom4b container**
3. **Toggle off the "Autostart" switch** (located next to the container name)

This ensures autom4b only runs when you manually start it.

#### Re-processing Failed Imports

If Beets skipped or failed to tag an audiobook:

1. **Find the untagged audiobook** in `beets_untagged`
2. **Re-run Beets** targeting just that directory:
   ```bash
   docker exec -it beets-audible beet import -m /input/Audiobook_Name
   ```

#### Cleaning Up Old Logs

Log files can accumulate over time. Periodically clean them up:

```bash
# Remove logs older than 30 days
find /mnt/user/Downloads/complete/logs/ -name "*.log" -mtime +30 -delete
find /mnt/user/Media/Processing/beets_tagged/ -name "*.log" -mtime +30 -delete
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
- Check Audible plugin is installed: `pip list | grep audible` (Linux) or `docker exec beets-audible pip list | grep audible` (Unraid)

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
  4. Manually install: `docker exec -it beets-audible pip install beets-audible beets-copyartifacts3 beets[web]`

**Metadata not fetching from Audible**
- **Symptoms**: Beets imports audiobooks but without Audible metadata
- **Solutions**:
  1. Verify Audible plugin installed: `docker exec beets-audible beet version`
  2. Check `config.yaml` has `audible` in plugins list
  3. Ensure audiobook files have reasonable filenames for matching
  4. Try manual fetch: `docker exec beets-audible beet audible -f`

**Version compatibility issues**
- **Symptoms**: Audible plugin errors after Beets update
- **Solutions**:
  1. Verify container running version 2.3.0: `docker exec beets-audible beet version`
  2. If updated accidentally, change repository back to `lscr.io/linuxserver/beets:2.3.0`
  3. Recreate the container with correct version

**Permission errors in Docker containers**
- **Symptoms**:
  - Files created with wrong ownership
  - "Permission denied" or "Access denied" errors
  - Containers can't read/write files created by other containers
  - Scripts fail with permission errors
- **Solutions**:
  1. **Verify all containers have matching permissions** - See [File Permissions](#important-file-permissions-on-unraid) section
  2. Ensure each container has: `PUID=99`, `PGID=100`, `UMASK=002`
  3. Check containers that need these settings:
     - autom4b
     - Beets
     - qBittorrent
  4. Restart containers after changing environment variables
  5. Manually fix existing file permissions:
     ```bash
     chown -R 99:100 /mnt/user/Media/Processing/
     chown -R 99:100 /mnt/user/Downloads/
     ```
  6. Verify file ownership:
     ```bash
     ls -la /mnt/user/Media/Processing/
     ```
     Files should show `nobody users` as owner

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
