#! /usr/bin/sh

if [ $# -eq 0 ]; then
    echo "Usage: illustration_remove_colour.sh <name>"
    echo
    echo "The current directory should contain the background and foreground"
    echo "PDFs named 'afesbrand_illustration_<name>_bg.pdf' and"
    echo "'afesbrand_illustration_<name>_fg.pdf' respectively."
    echo
    echo "These two PDFs should be single colour RGB black illustrations"
    echo "only containing filled (not stroked) paths."
    exit 1
fi

if ! command -v pdftk >/dev/null 2>&1; then
  echo "Can not find pdftk in PATH"
  exit 1
fi

BGPDF="afesbrand_illustration_$1_bg.pdf"
FGPDF="afesbrand_illustration_$1_fg.pdf"

if [ ! -f "BGPDF" ]; then
  echo "Background file name found: $BGPDF"
  exit 2
fi

if [ ! -f "FGPDF" ]; then
  echo "Foreground file name found: $FGPDF"
  exit 3
fi

TMPAPDF=$(mktemp --suffix=.pdf tmp.XXXXX)

if [ ! -f "$TMPAPDF" ]; then
  echo "Could not make temporary PDF file: $TMPAPDF"
  exit 4
fi

TMPBPDF=$(mktemp --suffix=.pdf tmp.XXXXX)

if [ ! -f "$TMPBPDF" ]; then
  echo "Could not make temporary PDF file: $TMPBPDF"
  exit 5
fi

pdftk "$BGPDF" output "$TMPAPDF" uncompress
sed 's/0.0.0.[rR][gG]/        /g' < "$TMPAPDF" > "$TMPBPDF"
pdftk "$TMPBPDF" output "$BGPDF" compress

pdftk "$FGPDF" output "$TMPAPDF" uncompress
sed 's/0.0.0.[rR][gG]/        /g' < "$TMPAPDF" > "$TMPBPDF"
pdftk "$TMPBPDF" output "$FGPDF" compress

rm -f "$TMPAPDF" "$TMPBPDF"

