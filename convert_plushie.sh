#!/usr/bin/env bash
filename="$(basename -- "$1")"
filename="${filename%.*}"
echo "Converting $filename"
mkdir -p "assets/plushies/$filename"
magick convert \
    -bordercolor none -border 1 \
    -trim +repage \
    -background none -resize 512x \
    "$1" "assets/plushies/$filename/image.png"
cp "$1" "assets/plushies/$filename/"
if [ "$2" ]; then
    cp "assets/plushies/$2/config.toml" "assets/plushies/$filename/"
fi
