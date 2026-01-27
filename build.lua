module = "afesbrand"

unpackexe        = ""
sourcefiles      = {"*.def", "*.def", "*bg.pdf", "*fg.pdf", "*.sty"}
installfiles     = {"*.def", "*.def", "*bg.pdf", "*fg.pdf", "*.sty"}
typesetfiles     = {"afesbrand.tex"}
typesetsuppfiles = {"*.png", "*.jpg"}
docfiles         = {"illustration_remove_colour.sh"}

typesetexe = "lualatex"

stdengine    = "luatex"
checkengines = {"luatex"}
