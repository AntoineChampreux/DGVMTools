#' Plot temporal data
#' 
#' Makes a line plot graphing the temporal evolution of data (using ggplot2).  Full functionality not implemented, or even defined...  
#'
#' @param fields The data to be plotted, either as a Field, DataObject or a list of Model/DataObjects.  
#' @param layers A list of strings specifying which layers to plot.  Defaults to all layers.  
#' @param gridcells A list of gridcells to be plotted in different panels, for formatting of this argument see \code{selectGridcells}.  
#' Leave empty or NULL to plot all gridcells (but note that if this involves too many gridcells the code will stop) 
#' @param title A character string to override the default title.  Set to NULL for no title.
#' @param subtitle A character string to override the default subtitle. Set to NULL for no subtitle.
#' @param quant A Quantity object to provide meta-data about how to make this plot
#' @param cols,types Colour and types for the lines.  They do not each necessarily need to be specified, but if they are then the they need to be 
#' the same length as the labels arguments
#' @param labels A list of character strings which are used as the labels for the lines.  Must have the same length as the layers argument (after expansion if necessary)
#' @param x.label,y.label Character strings for the x and y axes (optional)
#' @param x.lim,y.lim Limits for the x and y axes (each a two-element numeric, optional)
#' @param facet Logical, if TRUE split the plot into panels by source.  If false, plots all data in a single panel. 
#' @param facet.scales Character string.  If faceting (see above) use "fixed" to specify same scales on each ribbon (default), or "free"/"free_x"/"free_y" for tailored scales
#' @param legend.position Position of the legend, in the ggplot2 style.  Passed to the ggplot function \code{theme()}. Can be "none", "top", "bottom", "left" or "right" or two-element numeric vector
#' @param text.multiplier A number specifying an overall multiplier for the text on the plot.  
#' @param plot Logical, if FALSE return the data.table of data instead of the plot
#' Make it bigger if the text is too small on large plots and vice-versa.
#'  
#' @details
#' This function is WORK IN PROGRESS!!  For questions about functionality or feature requests contact the author
#' 
#' @author Matthew Forrest \email{matthew.forrest@@senckenberg.de}
#' @import ggplot2
#' @export
#' @return A ggplot
#'
plotTemporal <- function(fields, 
                         layers = NULL,
                         gridcells = NULL,
                         title = character(0),
                         subtitle = character(0),
                         quant = NULL,
                         cols = NULL,
                         types = NULL,
                         labels = NULL,
                         y.label = NULL,
                         y.lim = NULL,
                         x.label = NULL,
                         x.lim = NULL,
                         facet = TRUE,
                         facet.scales = "fixed",
                         legend.position = "bottom",
                         text.multiplier = NULL,
                         plot = TRUE
){
  
  
  Time = Year = Month = Day = Source = value = variable = Lat = Lon = NULL
  
  
  ### SANITISE FIELDS, LAYERS AND STINFO
  
  ### 1. FIELDS - check the input Field objects (and if it is a single Field put it into a one-item list)
  
  fields <- santiseFieldsForPlotting(fields)
  if(is.null(fields)) return(NULL)
  
  ### 2. LAYERS - check the number of layers
  
  layers <- santiseLayersForPlotting(fields, layers)
  if(is.null(layers)) return(NULL)
  
  
  ### 3. DIMENSIONS - check the dimensions (require that all fields the same dimensions and that they include 'Year' )
  
  dim.names <- santiseDimensionsForPlotting(fields, require = c("Year"))
  if(is.null(dim.names)) return(NULL)
  
  
  ### PREPARE AND CHECK DATA FOR PLOTTING
  
  # first select the layers and points in space-time that we want to plot
  final.fields <- trimFieldsForPlotting(fields, layers, gridcells = gridcells)
  
  
  # check if layers are all continuous, and if not fail
  for(this.field in final.fields) {
    for(layer in layers(this.field)) {
      if(!(class(this.field@data[[layer]]) == "numeric" || class(this.field@data[[layer]]) == "integer" )) {
        stop("plotTemoral can only plot continuous layers")
      }
    }
  }
  
  # melt and combine the final.fields 
  data.toplot.list <- list()
  for(this.field in final.fields) {
    this.field.melted <- melt(this.field@data, id.vars = getDimInfo(this.field))
    this.field.melted[, Source := this.field@source@name]
    data.toplot.list[[length(data.toplot.list)+1]] <- this.field.melted
  }
  data.toplot <- rbindlist(data.toplot.list)
  rm(data.toplot.list)
  
  # TODO quick n dirty
  quant <- fields[[1]]@quant
  PFTs <- fields[[1]]@source@pft.set
  
  ### Rename "variable" to "Layer" which makes more conceptual sense
  setnames(data.toplot, "variable", "Layer")
  setnames(data.toplot, "value", "Value")
  
  
  
 
  
  # Check for Lon and Lat (and remove 'em)
  #if("Lon" %in% names(data.toplot)) { data.toplot[, Lon := NULL] }
  #if("Lat" %in% names(data.toplot)) { data.toplot[, Lat := NULL] }
  
  
  ### MAKE A DESCRIPTIVE TITLE IF ONE HAS NOT BEEN SUPPLIED
  if(missing(title) || missing(subtitle)) {
    titles <- makePlotTitle(fields)  
    if(missing(title)) title <- titles[["title"]]
    else if(is.null(title)) title <- waiver()
    if(missing(subtitle)) subtitle <- titles[["subtitle"]]
    else if(is.null(subtitle)) subtitle <- waiver()
  }
  
  
  
  # make y label
  if(is.null(y.label)) {
    y.label <- element_blank()
    if(!is.null(quant)) y.label  <- paste0(quant@name, " (", quant@units, ")")
  }
 
  # helpful check here
  if(nrow(data.toplot) == 0) stop("Trying to plot an empty data.table in plotTemporal, something has gone wrong.  Perhaps you are selecting a site that isn't there?")
  
  
  # Now that the data is melted into the final form, set the colours if not already specified and if enough meta-data is available
  all.layers <- unique(as.character(data.toplot[["Layer"]]))
  labels <- all.layers
  names(labels) <- all.layers
  
  if(is.null(cols)){
    new.cols <- matchPFTCols(all.layers, PFTs)
    if(length(new.cols) == length(all.layers))  cols <- new.cols 
  }
  
  if(is.null(types)) {
    new.types <- list()
    for(layer in all.layers) {
      for(PFT in PFTs){
        if(layer == PFT@id) { 
          if(PFT@shade.tolerance != "no" &&  tolower(PFT@shade.tolerance) != "none") new.types[[layer]] <- 2
          else new.types[[layer]] <- 1
        }
      }
    }
    if(length(new.types) == length(all.layers)) {
      types <- unlist(new.types)
    }
  }
  
  
  
  ### Make a 'Time' column of data objects for the x-axis 
  earliest.year <- min(data.toplot[["Year"]])
  if(earliest.year >= 0) {
    # convert years and months to dates 
    if("Year" %in% names(data.toplot) && "Month" %in% names(data.toplot)) {
      pad <- function(x) { ifelse(x < 10, paste0(0,x), paste0(x)) }
      data.toplot[, Time := as.Date(paste0(Year, "-", pad(Month), "-01"), format = "%Y-%m-%d")]
      data.toplot[, Year := NULL]
      data.toplot[, Month := NULL]
    }
    # convert years and days to dates 
    else if("Year" %in% names(data.toplot) && "Day" %in% names(data.toplot)) {
      pad <- function(x) { ifelse(x < 10, paste0(0,x), paste0(x)) }
      data.toplot[, Time := as.Date(paste0(Year, "-", Day), format = "%Y-%j")]
      data.toplot[, Year := NULL]
      data.toplot[, Day := NULL]
    }
    # convert years to dates 
    else if("Year" %in% names(data.toplot)) {
      data.toplot[, Time := as.Date(paste0(Year, "-01-01"), format = "%Y-%m-%d")]
      data.toplot[, Year := NULL]
    }
  }
  else {
    if("Year" %in% names(data.toplot) && "Month" %in% names(data.toplot)) {
      latest.year <- max(data.toplot[["Year"]])
      print(latest.year)
      print(earliest.year)
      earliest.year.days <- as.numeric(earliest.year, as.Date(("0001-01-01")))
      latest.year.days <- as.numeric(latest.year, as.Date(("0001-01-01")))
      print(earliest.year.days)
      print(latest.year.days)
      stop("Hmm... not yet sure how to plot months with negative years")
    }
    else if("Year" %in% names(data.toplot)) {
      data.toplot[, Time := Year]
      data.toplot[, Year := NULL]
    }
    #
  }
  
  ### MAJOR TODO - tweak the facetting!
  
  ### If requested, just return the data
  if(!plot) return(data.toplot)
  
  # now make the plot
  p <- ggplot(as.data.frame(data.toplot), aes_string(x = "Time", y = "Value", colour = "Layer"))
  for(this.source in unique(data.toplot[["Source"]])) {
    p <- p + geom_line(data = data.toplot[Source == this.source,], size = 1)
    #p <- p + geom_line(data = data.toplot[Source == this.source,], size = 1)
  }
  
  # line formatting
  if(!is.null(cols)) p <- p + scale_color_manual(values=cols, labels=labels) 
  if(!is.null(types)) p <- p + scale_linetype_manual(values=types, labels=labels)
  
  # labels and positioning
  p <- p + labs(title = title, subtitle = subtitle, y = y.label)
  p <- p + theme(legend.title=element_blank())
  p <- p + theme(legend.position = legend.position, legend.key.size = unit(2, 'lines'))
  p <- p + theme(plot.title = element_text(hjust = 0.5),
                 plot.subtitle = element_text(hjust = 0.5))
  
  # overall text multiplier
  if(!missing(text.multiplier)) p <- p + theme(text = element_text(size = theme_get()$text$size * text.multiplier))
  
  # set limits
  if(!is.null(x.lim)) p <- p + xlim(x.lim)
  if(!is.null(y.lim)) p <- p + scale_y_continuous(limits = y.lim, name = y.label)
  p <- p + labs(y = y.label)
  
  # if facet
  if(facet){
    p <- p + facet_wrap(stats::as.formula(paste("~Source")), ncol = 1, scales = facet.scales)
  }
  
  
  
  return(p)
  
  
}