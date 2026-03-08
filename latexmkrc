$pdflatex = 'lualatex %O %S';

END {
  system('inkscape output.pdf --export-filename=AFESBrandFactory.svg --pdf-poppler --export-type=svg --export-plain-svg --export-area-page');
  system('perl -i -0pe \'s/<clipPath[^>]*>.*?<\/clipPath>//gs; s/ clip-path="url\(#[^"]*\)"//g\' AFESBrandFactory.svg');
  system('convert -density 300 output.pdf AFESBrandFactory.png');
  system('cp output.pdf AFESBrandFactory.pdf');
}
