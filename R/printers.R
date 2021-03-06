#' @importFrom htmltools htmlDependency
tabwid_htmldep <- function(){
  htmlDependency("tabwid",
                 "1.0.0",
                 src = system.file(package="flextable", "web_1.0.0"),
                 stylesheet = "tabwid.css", script = "tabwid.js")

}

#' @export
#' @title flextable a tag object from htmltools package
#'
#' @description get a \code{\link[htmltools]{div}} from a flextable object.
#' This can be used in a shiny application.
#' @param x a flextable object
#' @family flextable print function
#' @examples
#' htmltools_value(flextable(iris[1:5,]))
htmltools_value <- function(x){
  codes <- html_str(x)
  html_o <- div( class='tabwid',
                 tabwid_htmldep(),
                 HTML(as.character(codes))
  )
}


#' @importFrom htmltools HTML browsable
#' @export
#' @title flextable printing
#'
#' @description print a flextable object to format \code{html}, \code{docx},
#' \code{pptx} or as text (not for display but for informative purpose).
#' This function is to be used in an interactive context.
#'
#' @note
#' When argument \code{preview} is set to \code{"docx"} or \code{"pptx"}, an
#' external client linked to these formats (Office is installed) is used to
#' edit a document. The document is saved in the temporary directory of
#' the R session and will be removed when R session will be ended.
#'
#' When argument \code{preview} is set to \code{"html"}, an
#' external client linked to these HTML format is used to display the table.
#' If RStudio is used, the Viewer is used to display the table.
#'
#' Note also that a print method is used when flextable are used within
#' R markdown documents. See \code{\link{knit_print.flextable}}.
#' @param x flextable object
#' @param preview preview type, one of c("html", "pptx", "docx", "log").
#' When \code{"log"} is used, a description of the flextable is printed.
#' @param ... unused argument
#' @family flextable print function
#' @importFrom utils browseURL
#' @importFrom officer read_pptx add_slide read_docx
print.flextable <- function(x, preview = "html", ...){
  if (!interactive() || "log" %in% preview ){
    cat("a flextable object.\n")
    cat( "col_keys:", paste0("`", x$col_keys, "`", collapse = ", " ), "\n" )
    cat( "header has", nrow(x$header$dataset), "row(s)", "\n" )
    cat( "body has", nrow(x$body$dataset), "row(s)", "\n" )
    cat("original dataset sample:", "\n")
    print(x$body$dataset[seq_len( min(c(5, nrow(x$body$dataset) ) ) ), ])
  } else  if( preview == "html" ){
    print( browsable( htmltools_value(x) ) )
  } else if( preview == "pptx" ){
    doc <- read_pptx()
    doc <- add_slide(doc, layout = "Title and Content", master = "Office Theme")
    doc <- ph_with_flextable(doc, value = x, type = "body")
    file_out <- print(doc, target = tempfile(fileext = ".pptx"))
    browseURL(file_out)
  } else if( preview == "docx" ){
    doc <- read_docx()
    doc <- body_add_flextable(doc, value = x, align = "center")
    file_out <- print(doc, target = tempfile(fileext = ".docx"))
    browseURL(file_out)
  }

  invisible(NULL)
}

#' @title Render flextable in rmarkdown
#' @description Function used to render flextable in knitr/rmarkdown documents.
#' HTML, Word and PowerPoint outputs are supported.
#'
#' Function \code{htmltools_value} return an HTML version of the flextable,
#' this function is to be used within Shiny applications with \code{renderUI()}.
#' @note
#' For Word (docx) output, if pandoc version >= 2.0 is used, a raw XML block
#' with the table code will be inserted. If pandoc version < 2.0 is used, an
#' error will be raised. Insertion of images is not supported
#' with rmarkdow for Word documents. For PowerPoint (pptx) output,
#' if pandoc version < 2.4 is used, an error will be raised.
#'
#' @section Word chunk options:
#' Result can be aligned with chunk option \code{ft.align} that
#' accepts values 'left', 'center' and 'right'.
#'
#' Word option 'Allow row to break across pages' can be
#' activated with chunk option \code{ft.split} set to TRUE.
#'
#' @section PowerPoint chunk options:
#' Position should be defined with options \code{ft.left}
#' and \code{ft.top}. Theses are the top left coordinates
#' of the placeholder that will contain the table. They
#' default to \code{{r ft.left=1, ft.left=2}}.
#'
#' @param x a \code{flextable} object
#' @param ... further arguments, not used.
#' @export
#' @author Maxim Nazarov
#' @importFrom htmltools HTML div
#' @importFrom knitr knit_print asis_output opts_knit opts_current
#' @importFrom rmarkdown pandoc_version
#' @importFrom stats runif
#' @family flextable print function
knit_print.flextable <- function(x, ...){

  if (is.null(opts_knit$get("rmarkdown.pandoc.to")))
    stop("`render_flextable` needs to be used as a renderer for ",
         "a knitr/rmarkdown R code chunk (render by rmarkdown)")

  if ( grepl( "^html", opts_knit$get("rmarkdown.pandoc.to") ) ) {
    knit_print(htmltools_value(x))
  } else if (opts_knit$get("rmarkdown.pandoc.to") == "docx") {

    if (pandoc_version() >= 2) {
      # insert rawBlock with Open XML
      if( is.null(align <- opts_current$get("ft.align")) )
        align <- "center"
      if( is.null(split <- opts_current$get("ft.split")) )
        split <- FALSE

      str <- docx_str(x, align = align, split = TRUE %in% split)

      knit_print( asis_output(
        paste("```{=openxml}", str, "```", sep = "\n")
      ) )
    } else {
      stop("pandoc version >= 2.0 required for flextable rendering in docx")
    }

  } else if (opts_knit$get("rmarkdown.pandoc.to") == "pptx") {
    if (pandoc_version() < 2.4) {
      stop("pandoc version >= 2.4 required for printing flextable in pptx")
    }

    if( is.null(left <- opts_current$get("ft.left")) )
      left <- 1
    if( is.null(top <- opts_current$get("ft.top")) )
      top <- 2
    uid <- as.integer(runif(n=1) * 10^9)
    str <- pml_flextable(x, uid = uid, offx = left, offy = top, cx = 10, cy = 6)

    knit_print( asis_output(
      paste("```{=openxml}", str, "```", sep = "\n")
    ) )


  } else {
    stop("unsupported format for flextable rendering:", opts_knit$get("rmarkdown.pandoc.to"))
  }
}

#' @export
#' @title Encode flextable in a document format.
#'
#' @description Encode flextable in a document format, \code{html}, \code{docx},
#' \code{pptx}.
#'
#' This function is exported so that users can create their own custom
#' component.
#' @param x flextable object
#' @param type one of pptx, docx or html.
#' @param ... unused
#' @examples
#' ft <- flextable(head(iris, n = 2))
#' format(ft, type = "html")
#' @family flextable print function
format.flextable <- function(x, type, ...){

  stopifnot( length(type) == 1,
             type %in% c("wml", "pml", "html", "pptx", "docx") )

  if( type %in% "pptx") type <- "pml"
  if( type %in% "docx") type <- "wml"

  if( type == "wml" ){
    out <- docx_str(x, ...)
  } else if( type == "pml" ){
    out <- pml_flextable(x)
  } else if( type == "html" ){
    out <- html_str(x)
  } else stop("unimplemented")
  out
}

#' @export
#' @title save a flextable in an HTML file
#' @description save a flextable in an HTML file. This function
#' has been implemented to help users that do not understand
#' R Markdown. It is highly recommanded to use R Markdown
#' instead.
#' @param x a flextable object
#' @param path HTML file to be created
#' @examples
#' ft <- flextable( head( mtcars ) )
#' tf <- tempfile(fileext = ".html")
#' save_as_html(ft, tf)
#' @family flextable print function
save_as_html <- function(x, path){

  if( !inherits(x, "flextable"))
    stop("x is not a flextable")

  str <- paste('<!DOCTYPE htm><html><head>',
  '<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />',
  '<meta name="viewport" content="width=device-width, initial-scale=1.0"/>',
  '<title>', deparse(substitute(x)), '</title></head>',
  '<body>', format(x, type = "html"),
  '</body></html>')
  cat(str, file = path)
  invisible(path)
}
