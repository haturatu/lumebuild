#!/bin/bash

#######################
# CONFIG
#######################
LUME_DIR="/your/lume/dir"
SRC_DIR="$LUME_DIR/src"
BUILD_DIR="site"

########################
# OPTIONAL
########################
BLOG_URL="https://yourblog.url"
POST_URL_DIR="posts"
WEBPSH="/your/webp/convert/path"
COMMIT_COMMENT="`echo "Memory" && free -h | head -2 | awk  '{print $(NF-5)"," $(NF-4)"," $(NF-3)}' | column -t -s ","`"
FEDI_CMT="y"

# Deno Env
export DENO_INSTALL="/home/$USER/.deno"; export PATH="$DENO_INSTALL/bin:$PATH"

# Commands check
commands=("deno" "git" "toot" "cwebp")

for cmd in "${commands[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Please install: $cmd"
      exit 1
  fi
done

git_commit() {
  cd "$SRC_DIR" || exit
  ls "$SRC_DIR/.git" || git init || exit
  git add . || exit
  git commit -m "$COMMIT_COMMENT"
}

build() {
  cd $LUME_DIR || exit
  deno task lume --dest=$BUILD_DIR > /dev/null 2>&1
}

fedi_posts() {
    LAST_POST=`ls -tr | tail -1`
    POST_URL=`echo "$BLOG_URL/$POST_URL_DIR/$LAST_POST/" | sed "s/\.md//g"`
    TITLE=`grep "^title: " "$LAST_POST" | sed "s/^title: //g"`

    toot post "$TITLE - $POST_URL" > "/tmp/temp_toot"
    MSTDN_URL=`cat "/tmp/temp_toot" | sed "s/Toot posted: //g" `
    rm -f "/tmp/temp_toot"

    INS_TXT=`cat <<EOF
comments:
  src: '$MSTDN_URL'
EOF`


    awk -v ins="$INS_TXT" '
      /^---/ {
        if (++count == 2) {
          print ins
        }
      }

      {print} ' "$LAST_POST" > tmp && mv tmp "$LAST_POST"
    sed -i '/comments: {}/d' "$LAST_POST"
}

########################
# Main
########################

git_commit

if [ $? -eq 0 ]; then
  $WEBPSH

  cd $SRC_DIR/$POST_URL_DIR || exit

  if ! grep -A 1 -E "^comments:" "$(ls -tr | tail -1)" | grep -qi "}" ; then
    if [ "$FEDI_CMT" = "y" ]; then
      fedi_posts
      git_commit
      build
    fi
  else
    build
    exit 0
  fi
else
  exit 1
fi

