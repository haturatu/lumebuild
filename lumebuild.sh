#!/bin/bash
set -euo pipefail

# Configure environment for Deno
export USER=deno
export DENO_INSTALL="/home/deno/.$USER"
export PATH="$DENO_INSTALL/bin:$PATH"

################################################################################
# CONFIGURATION
#
# Please configure the following variables to match your environment.
################################################################################

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
# If you don't have one, you can leave this empty.
readonly WEBPSH="/opt/sh/your_webp_script.sh"

# Whether to post to the Fediverse. Set to "y" to enable.
readonly FEDI_CMT="y"

# Checksum file for change detection.
readonly CHECKSUM_FILE="/home/${USER}/.lumebuild_checksums"

# File patterns to include in checksums.
readonly PATTERNS=("*.md" "*.js" "*.vto")


################################################################################
# FUNCTIONS
################################################################################

# Check for required commands.
check_commands() {
  local commands=("deno" "toot" "cwebp" "jq" "curl" "md5sum" "rsync" "mktemp")
  for cmd in "${commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Error: Please install '$cmd'." >&2
      exit 1
    fi
  done
}

# Generate checksums for all target files.
generate_checksums() {
    echo "Info: Generating new checksums..."
    > "${CHECKSUM_FILE}" # Clear the file
    for pattern in "${PATTERNS[@]}"; do
        find "${SRC_DIR}" -type f -name "$pattern" -print0 | xargs -0 md5sum >> "${CHECKSUM_FILE}"
    done
    sort -o "${CHECKSUM_FILE}" "${CHECKSUM_FILE}"
}

# Check for file changes.
check_changes() {
    if [ ! -f "${CHECKSUM_FILE}" ]; then
        echo "Info: Checksum file not found. Generating initial checksums."
        generate_checksums
        echo "Info: First run, assuming changes exist."
        return 0
    fi

    local current_checksums
    current_checksums=$(mktemp)

    > "${current_checksums}" # Clear the file
    for pattern in "${PATTERNS[@]}"; do
        find "${SRC_DIR}" -type f -name "$pattern" -print0 | xargs -0 md5sum >> "${current_checksums}"
    done
    sort -o "${current_checksums}" "${current_checksums}"

    if diff --brief "${CHECKSUM_FILE}" "${current_checksums}" >/dev/null; then
        rm "${current_checksums}"
        return 1 # No changes
    else
        echo "Info: The following changes were detected:"
        diff "${CHECKSUM_FILE}" "${current_checksums}" || true # diff returns 1 on differences, so we use || true
        rm "${current_checksums}"
        return 0 # Changes detected
    fi
}

# Build the Lume site.
build_site() {
  local tmp_dir=$1
  local symlink_name="lumebuild_temp"
  local symlink_path="${LUME_DIR}/${symlink_name}"

  # Ensure symlink is removed on function exit, even on error
  trap "rm -f '${symlink_path}'" RETURN

  echo "Info: Creating build symlink at ${symlink_path}"
  ln -s "${tmp_dir}" "${symlink_path}"

  echo "Info: Building site using relative path '${symlink_name}'"
  deno task -q --cwd "${LUME_DIR}" lume --dest="${symlink_name}"
}

# Sync built files to the final destination.
sync_site() {
  local tmp_dir=$1
  echo "Info: Syncing built files to final destination..."
  mkdir -p "${LUME_DIR}/${FINAL_BUILD_DIR}"
  rsync -a --delete --chmod=F644,D755 "${tmp_dir}/" "${LUME_DIR}/${FINAL_BUILD_DIR}/"
}

# Get the latest post URL and title from the JSON feed.
get_latest_post_info() {
    local json_feed
    json_feed=$(curl -s --fail "${BLOG_URL}/feed.json?_=$(date +%s)") || {
        echo "Error: Failed to fetch JSON feed from ${BLOG_URL}/feed.json" >&2
        return 1
    }

    # Check if feed is valid JSON before parsing
    if ! echo "${json_feed}" | jq -e . > /dev/null; then
        echo "Error: Invalid JSON received from feed." >&2
        echo "Feed content: ${json_feed}" >&2
        return 1
    fi

    local post_url
    post_url=$(echo "${json_feed}" | jq -r '.items[0].url')

    local title
    title=$(echo "${json_feed}" | jq -r '.items[0].title')

    if [[ "${post_url}" == "null" || "${title}" == "null" ]]; then
        echo "Error: Failed to parse post URL or title from JSON feed." >&2
        echo "Feed content: ${json_feed}" >&2
        return 1
    fi

    echo "${title} - ${post_url}"
}

# Post a message to the Fediverse and get the post URL.
post_to_fediverse() {
    local message=$1
    local temp_file
    temp_file=$(mktemp)

    toot post "${message}" > "${temp_file}"
    local mstdn_url
    mstdn_url=$(sed "s/Toot posted: //g" "${temp_file}")

    rm -f "${temp_file}"
    echo "${mstdn_url}"
}

# Update the latest post with the Fediverse comment URL.
update_post_with_comment() {
    local post_file=$1
    local comment_url=$2

    local ins_txt
    ins_txt=$(cat <<EOF
comments:
  src: '${comment_url}'
EOF
)

    local temp_file
    temp_file=$(mktemp)

    awk -v ins="${ins_txt}" '
      /^---/ {
        if (++count == 2) {
          print ins
        }
      }
      {print} ' "${post_file}" > "${temp_file}" && mv "${temp_file}" "${post_file}"

    sed -i '/comments: {}/d' "${post_file}"
}


# Check if a post should be sent to the Fediverse.
should_toot() {
  local file=$1

  # If file doesn't exist, skip
  if [ ! -f "$file" ]; then
    echo "Info: should_toot No File"
    return 1
  fi

  # If draft is true, skip
  if grep -q 'draft: true' "$file"; then
    echo "Info: should_toot draft: true"
    return 1
  fi

  # If comments section already has a src with http, skip
  if grep -A 1 -E "^comments:" "$file" | grep "src:" | grep -q "http" ; then
    echo "Info: should_toot comments: src: http OK"
    return 1
  fi

  local post_date_str
  post_date_str=$(grep -E "^date:" "$file" | head -1 | cut -d':' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//')

  # If no date found, skip
  if [ -z "$post_date_str" ]; then
    echo "Warning: No date found in $file" >&2
    return 1
  fi

  local post_date_epoch
  # Try parsing the date, handle potential quotes
  if ! post_date_epoch=$(date -d "$post_date_str" +%s 2>/dev/null); then
    local cleaned_date
    cleaned_date=$(echo "$post_date_str" | sed 's/^"//;s/"$//')
    if ! post_date_epoch=$(date -d "$cleaned_date" +%s 2>/dev/null); then
      echo "Warning: Invalid date format in $file: $post_date_str" >&2
      return 1
    fi
  fi

  local current_date_epoch
  current_date_epoch=$(date +%s)

  local one_week_seconds=$((7 * 24 * 60 * 60))
  local time_diff=$((current_date_epoch - post_date_epoch))

  # if post is older than one week, skip
  if [ $time_diff -gt $one_week_seconds ]; then
    echo "Info: Post date is more than one week old: $post_date_str" >&2
    return 1
  fi

  # if post date is in the future, skip
  if [ $time_diff -lt 0 ]; then
    echo "Info: Post date is in the future: $post_date_str" >&2
    return 1
  fi

  return 0
}

################################################################################
# MAIN
################################################################################

main() {
  check_commands
  local latest_file
  latest_file=$(ls -tr "${SRC_DIR}/${POST_URL_DIR}" | tail -1)
  local latest_file_path="${SRC_DIR}/${POST_URL_DIR}/${latest_file}"

  if ! check_changes; then
      echo "Info: No changes detected. Nothing to do."
      exit 0
  fi

  echo "Info: Changes detected. Proceeding with build."

  if [ -n "${WEBPSH}" ] && [ -x "${WEBPSH}" ]; then
      echo "Info: Running WebP conversion script."
      "${WEBPSH}"
  fi

  # First build
  build_site "${TMP_BUILD_DIR}"
  sync_site "${TMP_BUILD_DIR}"
  echo "Info: Initial build complete."

  if should_toot "${latest_file_path}" && [ "${FEDI_CMT}" = "y" ]; then
      echo "Info: New post found. Posting to Fediverse..."
      local post_info
      post_info=$(get_latest_post_info)

      local mstdn_url
      mstdn_url=$(post_to_fediverse "${post_info}")

      update_post_with_comment "${latest_file_path}" "${mstdn_url}"

      echo "Info: Re-building site to include Fediverse comment..."
      # Final build after updating post
      build_site "${TMP_BUILD_DIR}"
      sync_site "${TMP_BUILD_DIR}"
      echo "Info: Final build complete."
  fi

  # Update checksums after all operations
  generate_checksums
}

# Use /dev/shm for in-memory build directory if it exists
if [ -d "/dev/shm" ]; then
  TMP_BUILD_DIR=$(mktemp -d -p /dev/shm lumebuild.XXXXXX)
else
  TMP_BUILD_DIR=$(mktemp -d -p /tmp lumebuild.XXXXXX)
fi

# Ensure the temporary directory is removed on script exit
trap 'rm -rf "${TMP_BUILD_DIR}"' EXIT

main "$@"

