# lumebuild

A simple bash script to automate the build process for Lume static site generator.

## Overview

This script automates the following tasks:
1. Commits changes in the source directory
2. Converts images to WebP format (if configured)
3. Builds the site using Lume

## Prerequisites

- Deno installed
- Lume static site generator
- Git
- WebP conversion tool (optional)
  
[WebP convert scripts are in this repository of mine](https://github.com/haturatu/webpsh)

## Configuration

Before using the script, update the following variables:
```bash
LUME_DIR="/your/lume/dir"        # Path to your Lume project directory
SRC_DIR="$LUME_DIR/src"          # Path to your Lume source directory
BUILD_DIR="site"                 # Path to your Lume output directory
WEBPSH="/your/webp/convert/path" # Path to WebP conversion script optional
COMMIT_COMMENT="`date`"          # Your fav commit comment
```

## Usage

Simply run the script:
```bash
./lumebuild.sh
```
Set up as a cron job to run automatically:
```bash
crontab -e
```
Add a line like this to run the script at your preferred interval:
```bash
*/5 * * * * /path/to/lumebuild.sh
```

## What it does

1. Sets up Deno environment variables
2. Changes to the source directory
3. Commits any changes using Git
4. Runs WebP conversion if configured
5. Builds the site using Lume, outputting to the 'site' directory

## Note

Make sure the script has executable permissions:
```bash
chmod +x lumebuild.sh
```

