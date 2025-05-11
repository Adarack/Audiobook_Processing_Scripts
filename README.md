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
   git clone https://github.com/yourusername/Audiobook_Processing_Scripts.git
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
   ./01_Download_Sort.sh [--force] [--dry-run]
   ```

---

### 02_Audiobook_After_Beets.sh

This script performs post-processing tasks after Beets has imported audiobooks. It can clean up temporary files, adjust permissions, and organize additional metadata.

- **Usage**:
   ```bash
   ./02_Audiobook_After_Beets.sh
   ```

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