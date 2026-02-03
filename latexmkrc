$pdflatex = 'lualatex %O %S';

END {
  system('inkscape output.pdf --export-filename=AFESBrandFactory.svg --pdf-poppler --export-type=svg --export-plain-svg --export-area-page');
  system('convert -density 300 output.pdf AFESBrandFactory.png');
}
