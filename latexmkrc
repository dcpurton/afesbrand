$pdflatex = 'lualatex %O %S';

END {
  system('inkscape output.pdf --pdf-poppler --actions="select-all;object-to-path;select-all;object-to-path;export-filename:AFESBrandFactory.svg;export-do" --export-type=svg --export-plain-svg --export-area-page');
  system('convert -density 300 output.pdf AFESBrandFactory.png');
}
