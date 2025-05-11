# Audiobook Processing Scripts

This repository contains a collection of scripts and configuration files designed to streamline the processing, organization, and management of audiobooks. These tools are tailored for use with [Beets](https://beets.io/), a powerful music library manager, and include custom scripts for downloading, sorting, and post-processing audiobooks.

---

## Table of Contents

- [Workflow Overview](#workflow-overview)
- [Features](#features)
- [Requirements](#requirements)
- [Setup](#setup)
- [Scripts](#scripts)
  - [01_Download_Sort.sh](#01_download_sortsh)
  - [02_Audiobook_After_Beets.sh](#02_audiobook_after_beetssh)
- [Configuration](#configuration)
  - [beets.io.config.yaml](#beetsioconfigyaml)
  - [Configuration Options](#configuration-options)
- [Usage](#usage)
- [License](#license)

---

## Workflow Overview

This is the general workflow for processing audiobooks using the scripts in this repository:

1. **Download Audiobooks**:
   - Use a separate [qBittorrent](https://www.qbittorrent.org/) instance for downloading books.
   - Use [Libation](https://github.com/rmcrackan/Libation) for managing Audible books.

2. **Sort Downloads**:
   - Configure qBittorrent to run `01_Download_Sort.sh` after a download completes.
   - The script sorts files into directories based on their type:
     - `.m4b` files go directly to the Beets input directory.
     - `.mp3`, `.m4a`, etc., are sent to the [autom4b](https://github.com/lukechilds/autom4b) directory for conversion.
     - eBook files are sent to the Calibre import directory.

3. **Convert and Tag**:
   - After autom4b processes files, they are moved to the Beets input directory.
   - Run Beets to rename and tag the files.

4. **Post-Processing**:
   - Run `02_Audiobook_After_Beets.sh` to:
     - Rename additional files.
     - Correct existing `.cue` files.
     - Move processed files to the final library location.

---

## Features

- **Automated File Sorting**: Organize audiobook files by metadata such as author, series, and title.
- **Beets Integration**: Use Beets plugins to fetch metadata, clean tags, and organize files.
- **Customizable Configuration**: Easily adjust file paths, permissions, and metadata rules.
- **Web UI**: Optional Beets Web UI for managing your audiobook library.
- **Support for Sidecar Files**: Preserve additional files like `metadata.yml`, cover images, and more.

---

## Requirements

- **Linux Environment**: These scripts are designed for Linux systems.
- **Beets**: Install Beets with the required plugins.
- **Bash**: Ensure Bash is available for running the scripts.

---

## Setup

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/Adarack/Audiobook_Processing_Scripts.git
   cd Audiobook_Processing_Scripts
   ```

2. **Install Beets and Plugins**:
   ```bash
   pip install beets
   pip install beets[audible,web]
   ```

3. **Configure Beets**:
   Copy the provided `beets.io.config.yaml` file to your Beets configuration directory:
   ```bash
   cp beets.io.config.yaml ~/.config/beets/config.yaml
   ```

4. **Make Scripts Executable**:
   ```bash
   chmod +x 01_Download_Sort.sh 02_Audiobook_After_Beets.sh
   ```

5. **Edit the Configuration Section of each script.**:
   You need to set all the directories and file types options in each script for your enviroment.
   '''bash
   nano 01_Download_Sort.sh

   nano 02_Audiobook_After_Beets.sh
   '''

---

## Scripts

### 01_Download_Sort.sh

This script processes files in a specified input directory, sorts them by file type (e.g., MP3, M4B, EPUB), and moves them to designated output directories.

- **Key Features**:
  - Supports dry-run mode to simulate actions.
  - Logs all actions for easy debugging.
  - Skips already processed files unless forced.

- **Usage**:
   ```bash
   ./01_Download_Sort.sh [--force] [--dry-run] [--verbose]
   ```

#### 01_Download_Sort.sh Configuration

- **INPUT_DIR**: The directory containing files to process.
- **MANUAL_LABEL**: A custom label to prepend to sorted file paths (e.g., "Brandon Sanderson").
- **ALWAYS_OVERWRITE**: If `true`, deletes the target directory before copying files.
- **FORCE_RECOPY**: If `true`, reprocesses files even if they are already logged as copied.
- **DRY_RUN**: If `true`, simulates actions without making changes.
- **VERBOSE**: If `true`, enables detailed logging.
- **SET_OWNER**: Ownership to apply to copied files (e.g., `nobody:nobody`).
- **SET_MODE**: File permissions to apply (e.g., `777`).
- **SET_DIR_MODE**: Directory permissions to apply (e.g., `777`).
- **FILETYPE_DIRS**: A mapping of file extensions to their respective output directories.

---

### 02_Audiobook_After_Beets.sh

This script performs post-processing tasks after Beets has imported audiobooks. It can clean up temporary files, adjust permissions, and organize additional metadata.

- **Usage**:
   ```bash
   ./02_Audiobook_After_Beets.sh
   ```

#### 02_Audiobook_After_Beets.sh Configuration

- **AUDIO_EXTENSIONS**: Supported audiobook file extensions to search for (case-insensitive). Default: `("m4b" "M4B")`.
- **TARGET_DIR**: The directory to scan for audiobook folders. Default: `"/path/to/m4b_input/"`.
- **DRY_RUN**: If `true`, simulates actions without making changes. Default: `false`.
- **FIX_CUE**: If `true`, updates the `FILE` line inside `.cue` files to match the audiobook filename. Default: `true`.
- **MOVE_FIXED**: If `true`, moves successfully processed directories to another location. Default: `true`.
- **MOVE_TARGET**: The destination directory for moved audiobook folders (if `MOVE_FIXED` is `true`). Default: `"/path/to/m4b_output/"`.
- **EXCLUDE_FILES**: Files that should not be renamed to match the audiobook file. Default: `("cover.jpg" "folder.jpg" "reader.txt" "desc.txt" "metadata.json" "album.nfo")`.
- **SET_OWNER**: Desired ownership for all files and directories (e.g., `nobody:nobody`). Leave empty (`""`) to skip changing ownership. Default: `"nobody:nobody"`.
- **SET_MODE**: Desired file permission mode (e.g., `644` or `777`). Leave empty (`""`) to skip `chmod` on files. Default: `"777"`.
- **SET_DIR_MODE**: Desired directory permission mode. Leave empty (`""`) to skip `chmod` on directories. Default: `"777"`.
- **LOG_FILE**: Path to the main log file for processed audiobook directories. Automatically generated with a timestamp.
- **SKIPPED_MULTIPLE_LOG_FILE**: Path to the log file for skipped directories with multiple audiobook files. Automatically generated with a timestamp.

---

## Configuration

### beets.io.config.yaml

This is the Beets configuration file tailored for audiobook processing. It includes:

- **Plugins**: Audible, copyartifacts, scrub, and more.
- **File Organization Rules**: Organize audiobooks by author, series, and title.
- **Metadata Sources**: Fetch metadata from Audible and optionally Goodreads.
- **Permissions**: Set custom file and directory permissions.

To use this configuration, copy it to your Beets configuration directory:
```bash
cp beets.io.config.yaml ~/.config/beets/config.yaml
```

---

## Usage

1. **Sort Files**:
   Run the `01_Download_Sort.sh` script to organize files into appropriate directories:
   ```bash
   ./01_Download_Sort.sh
   ```

2. **Import into Beets**:
   Use Beets to import and process the sorted files:
   ```bash
   beet import /path/to/sorted/files
   ```

3. **Post-Processing**:
   Run the `02_Audiobook_After_Beets.sh` script to finalize the organization:
   ```bash
   ./02_Audiobook_After_Beets.sh
   ```

---

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.