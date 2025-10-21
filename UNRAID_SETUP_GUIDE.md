# Unraid Setup Guide for Audiobook Processing

This guide will walk you through setting up the complete audiobook processing pipeline on Unraid using Docker containers and the scripts in this repository.

## Overview

This setup creates an automated workflow that:
1. Processes downloaded audiobook files (MP3, M4A, M4B, etc.)
2. Converts files to M4B format using autom4b
3. Tags audiobooks with metadata from Audible using Beets
4. Organizes files into your final library structure
5. Optionally imports ebooks (EPUB, MOBI, PDF) into Calibre

## Prerequisites

- Unraid server with Docker support enabled
- Community Applications plugin installed
- Basic familiarity with Unraid's Docker interface
- qBittorrent (or similar download client) configured

## Part 1: Install Required Docker Containers

### 1.1 Install autom4b

1. Open the Community Applications (CA) in Unraid
2. Search for "autom4b"
3. Install the container and configure:
   - **Input Directory**: Where 01_Download_Sort.sh will send files (e.g., `/mnt/user/Media/Processing/autom4b_input`)
   - **Output Directory**: Where converted M4B files go (e.g., `/mnt/user/Media/Processing/beets_untagged`)
4. Start the container and verify it's running

### 1.2 Install Beets (with Audible Plugin)

#### Important Version Requirement
**As of this writing, the Audible plugin for Beets from linuxserver.io only supports up to version 2.3.0.**

1. Open Community Applications and search for "beets"
2. Select the linuxserver/beets template
3. **CRITICAL**: Before installing, change the **Repository** field to:
   ```
   lscr.io/linuxserver/beets:2.3.0
   ```
4. Configure the basic paths:
   - **Config Directory**: `/mnt/user/appdata/beets`
   - **Music/Audiobooks Directory**: Your 02_Audiobooks_to_ABS.sh input path
   - **Downloads**: Where 01_Download_Sort.sh and autom4b outputs single mp4 files (becomes Beets input)
5. Click "Apply" to install the container
6. **Start the container** (this creates the initial config directory structure)
7. **Stop the container** (we need to modify configs before running it properly)

## Part 2: Configure Beets for Audiobook Processing

### 2.1 Initial Configuration

1. **Backup the default config**:
   - Navigate to `/mnt/user/appdata/beets` on your Unraid server
   - Rename `config.yaml` to `config.yaml.stock` (preserves the original)

2. **Copy the custom configuration files**:
   - Copy `beets-audible.config.yaml` from this repository to `/mnt/user/appdata/beets/`
   - Copy the entire `custom-cont-init.d/` directory to `/mnt/user/appdata/beets/`

3. **Rename the custom config**:
   - Rename `beets-audible.config.yaml` to `config.yaml`

4. **Edit paths in config.yaml**:
   - Open the newly renamed `config.yaml`
   - Update all directory paths to match your Unraid setup:
     - `directory:` - Your final audiobook library location
     - `audible.fetch_art:` - Cover art settings
     - Any other paths as needed
   - Save the file

### 2.2 Add Docker Mod for Custom Initialization

This step enables automatic installation of required Beets plugins on container startup.

1. **Edit the Beets container** in Unraid's Docker UI
2. **Add a new Path mapping**:
   - Click "Add another Path, Port, Variable, Label or Device"
   - Select **"Path"** as Config Type
   - Fill in:
     - **Name**: `custom-cont-init.d`
     - **Container Path**: `/custom-cont-init.d`
     - **Host Path**: `/mnt/user/appdata/beets/custom-cont-init.d/`
     - **Access Mode**: Read Only
3. Click "Apply" to save changes

### 2.3 Start Beets

1. Start the Beets container
2. **Verify plugin installation**:
   - Check the container logs in Unraid
   - Look for successful execution of `install-deps.sh`
   - Verify installation of:
     - `beets-audible`
     - `beets-copyartifacts3`
     - `beets[web]`

## Part 3: Configure Processing Scripts

### 3.1 Configure 01_Download_Sort.sh

1. Open `01_Download_Sort.sh` in a text editor
2. Review and update configuration variables (lines 17-32):
   - **`INPUT_DIR`**: Where qBittorrent downloads files
   - **`LOG_DIR`**: Where to store processing logs
   - **`FILETYPE_DIRS`**: Verify paths match your Docker container configurations:
     - MP3/M4A → autom4b input directory
     - M4B → Beets untagged/input directory
     - EPUB/MOBI/PDF → Calibre import directory (if using)

3. Set permissions:
   ```bash
   chmod +x 01_Download_Sort.sh
   ```

### 3.2 Configure 02_Audiobooks to ABS.sh

1. Open `02_Audiobooks to ABS.sh` in a text editor
2. Update configuration variables (lines 5-44):
   - **`INPUT_DIR`**: Beets output directory (where tagged audiobooks go)
   - **`MOVE_TARGET`**: Final library location for AudioBookshelf or other player
   - **`OVERWRITE_POLICY`**: How to handle existing sidecar files (never/always/newer/larger)
   - **`PUID`/`PGID`**: Match your Unraid user/group IDs

3. Set permissions:
   ```bash
   chmod +x "02_Audiobooks to ABS.sh"
   ```

## Part 4: Integration with qBittorrent

### 4.1 Configure Download Completion Script

1. Open qBittorrent settings
2. Navigate to **Downloads** → **Run external program on torrent completion**
3. Enable the option and add:
   ```bash
   /path/to/01_Download_Sort.sh "%F"
   ```
   Replace `/path/to/` with the actual script location

### 4.2 Test the Integration

1. **Dry run test** (recommended first):
   ```bash
   ./01_Download_Sort.sh --dry-run --verbose /path/to/test/file
   ```

2. Review the log output to ensure files would be sorted correctly

## Part 5: Verification and Testing

### 5.1 Test the Complete Pipeline

1. **Place a test audiobook** in your qBittorrent download directory
2. **Manually run** the first script:
   ```bash
   ./01_Download_Sort.sh --verbose /path/to/test/audiobook
   ```
3. **Monitor the workflow**:
   - Check autom4b logs for conversion (if MP3/M4A)
   - Verify file appears in Beets input directory
   - Run Beets import manually to test tagging
   - Check Beets output directory for tagged files
4. **Run post-processing**:
   ```bash
   ./02_Audiobooks\ to\ ABS.sh
   ```
5. **Verify** files in final library location

### 5.2 Check Logs

Each script creates detailed logs:
- **01_Download_Sort.sh**: Creates `download_sort_YYYYMMDD_HHMMSS.log` in the source directory
- **02_Audiobooks to ABS.sh**: Creates `Audiobook_Processing_YYYYMMDD_HHMMSS.log` in the input directory

Review these for any errors or warnings.

## Troubleshooting

### Beets Plugins Not Installing

**Symptoms**: Beets doesn't recognize audible plugin commands

**Solutions**:
1. Check container logs for errors during startup
2. Verify `custom-cont-init.d` path mapping is correct
3. Ensure `install-deps.sh` has execute permissions
4. Manually enter the container and run:
   ```bash
   pip install beets-audible beets-copyartifacts3 beets[web]
   ```

### Files Not Moving

**Symptoms**: Scripts run but files remain in place

**Solutions**:
1. Check log files for permission errors
2. Verify PUID/PGID match your Unraid user
3. Ensure all directories exist and are writable
4. Test with `--dry-run --verbose` flags

### Metadata Not Fetching

**Symptoms**: Beets imports audiobooks but without Audible metadata

**Solutions**:
1. Verify Audible plugin is installed: `beet version`
2. Check `config.yaml` has `audible` in plugins list
3. Ensure audiobook files have reasonable filenames for matching
4. Try manual fetch: `beet audible -f`

### Version Compatibility Issues

**Symptoms**: Audible plugin errors after Beets update

**Solutions**:
1. Verify container is running version 2.3.0: `beet version`
2. If updated accidentally, change repository back to `lscr.io/linuxserver/beets:2.3.0`
3. Recreate the container with the correct version

## Maintenance

### Regular Tasks

1. **Monitor disk space** in processing directories
2. **Review logs** periodically for recurring errors
3. **Update scripts** from repository when improvements are released
4. **Test dry-run** after any configuration changes

### Updates

- **autom4b**: Can be updated normally through CA
- **Beets**: Stay on 2.3.0 until Audible plugin supports newer versions
- **Scripts**: Pull latest from repository and review CLAUDE.md for changes

## Additional Resources

- **Beets Documentation**: https://beets.readthedocs.io/
- **Audible Plugin**: https://github.com/beatunes/beets-audible
- **autom4b**: Check Docker Hub for documentation
- **Script Repository**: See CLAUDE.md for development guidance

## Quick Reference

### Common Commands

```bash
# Test download sorting
./01_Download_Sort.sh --dry-run --verbose /path/to/test

# Run post-processing in dry-run mode
# (Edit script, set DRY_RUN=true on line 19)
./02_Audiobooks\ to\ ABS.sh

# Manual Beets import
beet import /path/to/audiobook

# Check Beets configuration
beet config

# List installed Beets plugins
beet version
```

### Directory Structure Example

```
/mnt/user/Media/
├── Downloads/              # qBittorrent download location
├── Processing/
│   ├── autom4b_input/     # 01_Download_Sort.sh sends MP3/M4A here
│   ├── beets_untagged/    # autom4b outputs M4B files here
│   └── beets_tagged/      # Beets outputs tagged audiobooks here
└── Audiobooks/            # Final library (02_Audiobooks to ABS.sh target)
```

## Support

For issues with:
- **Scripts**: Check logs and review CLAUDE.md
- **Docker containers**: Check Unraid forums and container-specific documentation
- **Beets/Audible**: Review plugin documentation and GitHub issues
