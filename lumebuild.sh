#!/bin/bash

LUME_DIR="/your/lume/dir"
SRC_DIR="$LUME_DIR/src"
BUILD_DIR="site"
WEBPSH="/your/webp/convert/path"
COMMIT_COMMENT="`echo "Memory" && free -h | head -2 | awk  '{print $(NF-5)"," $(NF-4)"," $(NF-3)}' | column -t -s ","`"

export DENO_INSTALL="/home/$USER/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"

cd "$SRC_DIR" || exit
ls "$SRC_DIR/.git" || git init || exit
git add . || exit

git commit -m "$COMMIT_COMMENT"

if [ $? -eq 0 ]; then
  $WEBPSH
  cd $LUME_DIR || exit
  # deno task lume --dest=$BUILD_DIR
  deno task lume --dest=$BUILD_DIR > /dev/null 2>&1
else
  exit 1
fi

