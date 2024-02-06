filename=$(basename -- "$1")
filename="${filename%.*}"
echo "Converting $filename"
mkdir -p assets/plushies/$filename
gm convert -trim +repage -resize 512x -background none $1 assets/plushies/$filename/image.png
cp $1 assets/plushies/$filename/
