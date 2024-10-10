#!/bin/bash

LUME_DIR="/your/lume/dir"
SRC_DIR="$LUME_DIR/src"
BUILD_DIR="site"
WEBPSH="/your/webp/convert/path"

export DENO_INSTALL="/home/$USER/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"

cd "$SRC_DIR" || exit

git add . || git init && git add . || exit

git commit -m "`date`"

if [ $? -eq 0 ]; then
  $WEBPSH
  cd $LUME_DIR || exit
  # deno task lume --dest=$BUILD_DIR
  deno task lume --dest=$BUILD_DIR > /dev/null 2>&1
else
  exit 1
fi

