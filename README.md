# lumebuild

A simple bash script to automate the build process for the Lume static site generator.

## Overview

This script automates the following tasks:
1. Detects file changes using checksums.
2. Converts images to WebP format (if configured).
3. Builds the site using Lume.
4. Posts new articles to the Fediverse (Mastodon, etc.) and adds the post URL to the article.

## Prerequisites

Make sure the following commands are installed on your system:
- `deno`
- `lume` (as a Deno task)
- `toot` (for Fediverse posting)
- `cwebp` (for WebP conversion)
- `jq`
- `curl`
- `md5sum`
- `rsync`
- `mktemp`

[WebP conversion scripts can be found in this repository.](https://github.com/haturatu/webpsh)

## Configuration

Before using the script, update the variables in the "CONFIGURATION" section of `lumebuild.sh`:

```bash
# The absolute path to your Lume project directory.
readonly LUME_DIR="/var/www/deno/lumeblog"

# The source directory of your Lume project.
readonly SRC_DIR="${LUME_DIR}/src"

# The destination directory for the built site.
readonly FINAL_BUILD_DIR="main"

# The base URL of your blog.
readonly BLOG_URL="https://example.com/"

# The directory where your blog posts are stored, relative to SRC_DIR.
readonly POST_URL_DIR="posts"

# Optional: The absolute path to a script that converts images to WebP.
readonly WEBPSH="/opt/sh/your_webp_script.sh"

# Whether to post to the Fediverse. Set to "y" to enable.
readonly FEDI_CMT="y"

# Checksum file for change detection.
readonly CHECKSUM_FILE="/home/${USER}/.lumebuild_checksums"

# File patterns to include in checksums.
readonly PATTERNS=("*.md" "*.js" "*.vto")
```

## Usage

1.  Make the script executable:
    ```bash
    chmod +x lumebuild.sh
    ```
2.  Run the script:
    ```bash
    ./lumebuild.sh
    ```
3.  (Optional) Set up a cron job to run it automatically:
    ```bash
    crontab -e
    ```
    Add a line like this to run the script at your preferred interval (e.g., every 5 minutes):
    ```
    */5 * * * * /path/to/lumebuild.sh
    ```

## What it does

1.  **Checks for Changes:** It generates checksums of your source files (`*.md`, `*.js`, `*.vto`) and compares them against a stored checksum file. If no changes are detected, the script exits.
2.  **WebP Conversion:** If the `WEBPSH` variable is set to an executable script, it runs the script to convert images.
3.  **Initial Build:** It builds the Lume site into a temporary directory (`/dev/shm` or `/tmp`) and syncs the files to the `FINAL_BUILD_DIR` using `rsync`.
4.  **Fediverse Posting:**
    - It checks the most recent post to see if it's new (published within the last week and not a draft).
    - If it's a new post, it fetches the post title and URL from your site's JSON feed.
    - It posts a message with the title and URL to the Fediverse using `toot`.
    - It then updates the original post file to include a link to the Fediverse post.
5.  **Final Build:** If the post file was updated with a Fediverse link, it rebuilds the site and syncs the changes again to ensure the link is included in the live site.
6.  **Updates Checksums:** Finally, it updates the checksum file with the new checksums of the source files for the next run.