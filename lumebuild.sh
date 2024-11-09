#!/bin/bash

# CONFIG
LUME_DIR="/your/lume/dir"
SRC_DIR="$LUME_DIR/src"
BUILD_DIR="site"

# OPTIONAL
BLOG_URL="https://yourblog.url"
POST_URL_DIR="posts"
WEBPSH="/your/webp/convert/path"
COMMIT_COMMENT="`echo "Memory" && free -h | head -2 | awk  '{print $(NF-5)"," $(NF-4)"," $(NF-3)}' | column -t -s ","`"

export DENO_INSTALL="/home/$USER/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"

git_commit() {
  cd "$SRC_DIR" || exit
  ls "$SRC_DIR/.git" || git init || exit
  git add . || exit
  git commit -m "$COMMIT_COMMENT"
}

git_commit

if [ $? -eq 0 ]; then
  $WEBPSH

  cd $SRC_DIR/$POST_URL_DIR || exit
  grep "^comments:" "$(ls -tr | tail -1)"

  if [ $? -eq 0 ]; then
    break
  else
    LAST_POST=`ls -tr | tail -1`
    POST_URL=`echo "$BLOG_URL/$POST_URL_DIR/$LAST_POST" | sed "s/\.md//g"`
    TITLE=`grep "^title: " "$LAST_POST" | sed "s/^title: //g"`
    MSTDN_URL=`toot post "$TITLE - $POST_URL" | sed "s/Toot posted: //g" `
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
    git_commit
  fi

  # deno task lume --dest=$BUILD_DIR
  cd $LUME_DIR || exit
  deno task lume --dest=$BUILD_DIR > /dev/null 2>&1
else
  exit 1
fi

