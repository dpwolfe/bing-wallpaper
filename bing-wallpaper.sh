#!/usr/bin/env bash

readonly SCRIPT=$(basename "$0")
readonly VERSION='0.1.1'

usage() {
cat <<EOF
Usage:
  $SCRIPT [options]
  $SCRIPT -h | --help
  $SCRIPT --version

Options:
  -f --force                     Force download of picture. This will overwrite
                                 the picture if the filename already exists.
  -s --ssl                       Communicate with bing.com over SSL.
  -q --quiet                     Do not display log messages.
  -n --filename <file name>      The name of the downloaded picture. Defaults to
                                 the upstream name.
  -p --picturedir <picture dir>  The full path to the picture download dir.
                                 Will be created if it does not exist.
                                 [default: $HOME/Pictures/bing-wallpapers/]
  -h --help                      Show this screen.
  --version                      Show version.
EOF
}

print_message() {
    if [ ! "$QUIET" ]; then
        printf "%s\n" "${1}"
    fi
}

# Defaults
PICTURE_DIR="$HOME/Pictures/bing-wallpapers/"

# Option parsing
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        -p|--picturedir)
            PICTURE_DIR="$2"
            shift
            ;;
        -n|--filename)
            FILENAME="$2"
            shift
            ;;
        -f|--force)
            FORCE=true
            ;;
        -s|--ssl)
            SSL=true
            ;;
        -q|--quiet)
            QUIET=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --version)
            printf "%s\n" $VERSION
            exit 0
            ;;
        *)
            (>&2 printf "Unknown parameter: %s\n" "$1")
            usage
            exit 1
            ;;
    esac
    shift
done

# Set options
[ $QUIET ] && CURL_QUIET='-s'
[ $SSL ]   && PROTO='https'   || PROTO='http'

# Create picture directory if it doesn't already exist
mkdir -p "${PICTURE_DIR}"

# Parse bing.com and acquire picture URL(s)
# This currently grabs tomorrow's image.
urls=( $(curl -sL $PROTO://www.bing.com | \
       grep -Eo "url:'.*?'" | \
       sed -e "s/url:'\([^']*\)'.*/$PROTO:\/\/bing.com\1/" | \
       sed -e "s/\\\//g") )

# Use a direct API to easily access current and previous 7 images.
# Requesting anymore than 8 or going past index 7 will only return
# the url from index 7 as it is clamped server side.
# You can visit the Bing gallery to find earlier days.
for ((INDEX=0;INDEX<8;INDEX++)); do
    TIME=$(($(date +'%s * 1000 + %-N / 1000000')))
    url=( $(curl -sL "$PROTO://www.bing.com/HPImageArchive.aspx?format=js&idx=$INDEX&n=1&nc=$TIME&pid=hp&video=0&quiz=0&fav=1" | \
          grep -Eo "murl\":\"[^\"]*" | \
          sed -e "s/murl\":\"\([^\"]*\)/\1/" | \
          # Images with cinemagraphs come with a low-quality thumb image that need to be transformed.
          sed -e "s/_tmb/_1920x1080/" | \
          sed -e "s/\\\//g") )
    urls=("${urls[@]}" "${url[@]}")
done

for p in "${urls[@]}"; do
    if [ -z "$FILENAME" ]; then
        filename=$(echo "$p"|sed -e "s/.*\/\(.*\)/\1/")
    else
        filename="$FILENAME"
    fi
    if [ $FORCE ] || [ ! -f "$PICTURE_DIR/$filename" ]; then
        print_message "Downloading: $filename..."
        curl $CURL_QUIET -Lo "$PICTURE_DIR/$filename" "$p"
    else
        print_message "Skipping: $filename..."
    fi
done
