#' Sanitise input Fields for plotting
#' 
#' This is an internal helper function which checks the inputs to a plotXXXX function (which should be a single Field or a list of Fields) and returns a list of Fields
#' 
#' @param fields The input to a plotXXXX() functions to be checked
#' @return Returns a list of DGVMTools::Field objects or NULL if a problem was found
#' @author Matthew Forrest \email{matthew.forrest@@senckenberg.de}
#' @keywords internal
#' 
#' 
santiseFieldsForPlotting <- function(fields) {
  
  if(is.Field(fields)) {
    fields <- list(fields)
  }
  else if(class(fields)[1] == "list") {
    for(object in fields){ 
      if(!is.Field(object)) {
        warning("You have passed me a list of items to plot but the items are not exclusively Fields.  Returning NULL")
        return(NULL)
      }
    }
  }
  else{
    warning(paste("This plot function can only handle single a Field, or a list of Fields, it can't plot an object of type", class(fields)[1], sep = " "))
    return(NULL)
  }
  
  return(fields)
  
}


#' Sanitise input Comparisons for plotting
#' 
#' This is an internal helper function which checks the inputs to a plotXXXXComparison() function (which should be a single Comparison or a list of Comparisons) 
#' and returns a list of Comparisons
#' 
#' @param comparisons The input to a plotXXXXComparison() functions to be checked
#' @return Returns a list of DGVMTools::Comparison objects or NULL if a problem was found
#' @author Matthew Forrest \email{matthew.forrest@@senckenberg.de}
#' @keywords internal
#' 
#' 
santiseComparisonsForPlotting <- function(comparisons) {
  
  if(is.Comparison(comparisons)) {
    comparisons <- list(comparisons)
  }
  else if(class(comparisons)[1] == "list") {
    for(object in comparisons){ 
      if(!is.Comparison(object)) {
        warning("You have passed me a list of items to plot but the items are not exclusively Comparisons.  Returning NULL")
        return(NULL)
      }
    }
  }
  else{
    warning(paste("This plot function can only handle single a Comparison, or a list of Comparison, it can't plot an object of type", class(comparisons)[1], sep = " "))
    return(NULL)
  }
  
  return(comparisons)
  
}

#' Sanitise input layers for plotting
#' 
#' This is an internal helper function which checks the layers requested to be plotted against the layers in the the fields to be plotted.  If layers is NULL, then 
#' it returns all layers present in any fields
#' 
#' @param fields The list of Fields to be plotted (should have been check by santiseFieldsForPlotting first)
#' @param layers The layers requested to be plotted
#' @return Returns character vector of the layers to be plotted
#' @author Matthew Forrest \email{matthew.forrest@@senckenberg.de}
#' @keywords internal
#' 
#' 
santiseLayersForPlotting <- function(fields, layers) {
  
  
  layers.superset <- c()
  num.layers.x.fields <- 0
  
  # if no layers argument supplied make a list of all layers present (in any object)
  if(is.null(layers) || missing(layers)){
    
    for(object in fields){
      temp.layers <- names(object)
      num.layers.x.fields <- num.layers.x.fields + length(temp.layers)
      layers.superset <- append(layers.superset, temp.layers)
    } 
    layers <- unique(layers.superset)
    
  }
  
  # else if layers have been specified check that we have some of the requested layers present
  else{
    
    for(object in fields){
      
      layers.present <- intersect(names(object), layers)
      num.layers.x.fields <- num.layers.x.fields + length(layers.present)
      
      if(length(layers.present) == 0) {warning("Some Fields to plot don't have all the layers that were requested to plot")}
      layers.superset <- append(layers.superset, layers.present)
      
    } 
    
    # Return empty plot if not layers found
    if(num.layers.x.fields == 0){
      warning("None of the specified layers found in the objects provided to plot.  Returning NULL.")
      return(NULL)
    }
    
    # Also check for missing layers and given a warning
    missing.layers <- layers[!(layers %in% unique(layers.superset))]
    if(length(missing.layers) != 0) { warning(paste("The following layers were requested to plot but not present in any of the supplied objects:", paste(missing.layers, collapse = " "), sep = " ")) }
    
    # finally make a unique list of layers to be carried in to the actual plotting
    layers <- unique(layers.superset)
    
  }
  
  return(layers)
  
}



#' Sanitise STAInfo for plotting
#' 
#' This is an internal helper function which checks the dimensions of the Fields to be plotted 
#' 
#' @param fields The list of Fields to be plotted (should have been check by santiseFieldsForPlotting first)
#' @return Returns character vector of the layers to be plotted
#' @author Matthew Forrest \email{matthew.forrest@@senckenberg.de}
#' @keywords internal
#' 
#' 
santiseDimensionsForPlotting <- function(fields, require = NULL) {
  
  ### Check if all the fields have the same ST dimensions and that Lon and Lat are present.  If not, warn and return NULL
  sta.info <- getDimInfo(fields[[1]], info = "names")
  
  # check Lon and Lat present
  for(required.sta in require)
  if(!required.sta %in% sta.info) {
    warning(paste0("Dimension ", required.sta, " is missing from an input Field but is required for this plot type.  Obviously this won't work, returning NULL."))
    return(NULL)
  }
  
  # check all the same dimensions
  if(length(fields) > 1) {
    for(counter in 2:length(fields)){
      if(!identical(sta.info, getDimInfo(fields[[counter]], info = "names"))) {
        warning(paste0("Trying to plot two Fields with different Spatial-Temporal dimensions.  One has \"", paste(sta.info, collapse = ","), "\" and the other has \"",  paste(getDimInfo(fields[[counter]], info = "names"), collapse = ","), "\".  So not plotting and returning NULL."))
        return(NULL)
      }
    }
  }
  
  return(sta.info)
  
}



#' Check values of a particular dimension 
#' 
#' This is an internal helper function which either stops if a dimension is requested to be plotted but is not present
#  or, if they have not explicitly been requested, it makes a list of possible values of that dimension.  If a value has been requested but is not present for the 
#' dimension, it gives a warning
#' 
#' @param fields The list of Fields to be plotted (should have been check by santiseFieldsForPlotting first)
#' @param input.values A list of the values that have been requested to be plotted
#' @param dimension A character string specifying which dimension is to be checked (one of "Lon", "Lat", "Year", "Month", "Day" or "Season") 
#' @return Returns character vector of the layers to be plotted
#' @author Matthew Forrest \email{matthew.forrest@@senckenberg.de}
#' @keywords internal
#' 
#' 
checkDimensionValues <- function(fields, input.values = NULL,  dimension) {
  
  all.values <- c()
  for(object in fields){
    
    # check if dimension is actually present in the source
    if(!dimension %in% getDimInfo(object)) {
      stop(paste("In plotSpatial you requested plotting of maps per", dimension, "but not all the fields have", dimension, "data.\n I am therefore returning NULL for this plot, but your script should continue.  Check that your input Fields have the time dimensions that you think they have.", sep = " "))
    }
    
    # get a list of all unique days present
    values.present <- unique(object@data[[dimension]])
    
    # input.list specified so check that they are present
    if(!is.null(input.values)) {
      for(counter in input.values) { if(!counter %in% values.present) warning(paste0(dimension, " ", counter, " not present in Field ", object@id)) }
    }
    # else input.list not specified so make a list of unique days across all Fields
    else { all.values <- append(all.values, values.present) }
    
  }
  
  # make a unique and sorted list of values
  if(is.null(input.values)) input.values <- sort(unique(all.values))
  
  # return
  return(input.values)
  
}

#' Subsets data from Field for plotting 
#' 
#' This is an internal helper function which pulls out the data needed to make a plot from a bunch of Fields, and returns 
#' a list of the Field with only the required layers and points in space and time included  
#' 
#' @param fields The list of Fields to be plotted (should have been check by santiseFieldsForPlotting first)
#' @param layers A character vector of the layers to be plotted
#' @param years The years to be extracted (as a numeric vector), if NULL all years are used
#' @param days The days to be extracted (as a numeric vector), if NULL all days are used
#' @param months The months to be extracted (as a numeric vector), if NULL all months are used
#' @param seasons The months to be extracted (as a character vector), if NULL all seasons are used
#' @param gridcells The months to be extracted (as a character vector), if NULL all seasons are used
#' 
#' @return Returns a list of Fields
#' @author Matthew Forrest \email{matthew.forrest@@senckenberg.de}
#' @keywords internal
#' 
#' 
trimFieldsForPlotting <- function(fields, layers, years = NULL, days = NULL, months = NULL, seasons = NULL, gridcells = NULL) {

  J = Year = NULL
  
  discrete <- FALSE
  continuous <- FALSE
  
  # Loop through the objects and select the layers and dimensions that we want for plotting
 
  final.fields <- list()
  
  for(object in fields){
    
    # check that at least one layer is present in this object and make a list of those which are
    all.layers <- names(object)
    layers.present <- c()
    for(this.layer in layers) {
      if(this.layer %in% all.layers)  layers.present <- append(layers.present, this.layer)
    }
    
    # if at least one layer present subset it
    if(length(layers.present) > 0) {
      
      # select the layers and time periods required and mash the data into shape
      these.layers <- selectLayers(object, layers.present)
      if(!is.null(years)) {
        # set key to Year, subset by years, the set keys back
        # note we are not doing selectYears() because we may want to select non-contiguous years
        setkey(these.layers@data, Year)
        these.layers@data <- these.layers@data[J(years)]
        setKeyDGVM(these.layers@data)
      }
      if(!is.null(days)) these.layers <- selectDays(these.layers, days)
      if(!is.null(months)) these.layers <- selectMonths(these.layers, months)
      if(!is.null(seasons)) these.layers <- selectSeasons(these.layers, seasons)
      if(!is.null(gridcells)) these.layers <- selectGridcells(these.layers, gridcells, spatial.extent.id = "Subset_For_Plotting")
      
      # check if layers are all continuous or discrete
      for(layer in layers.present) {
        if(class(object@data[[layer]]) == "factor" || class(object@data[[layer]]) == "logical" || class(object@data[[layer]]) == "ordered") discrete <- TRUE
        if(class(object@data[[layer]]) == "numeric" || class(object@data[[layer]]) == "integer" ) continuous <- TRUE
      }
      if(discrete & continuous) stop("Cannot simultaneously plot discrete and continuous layers, check your layers") 
      if(!discrete & !continuous) stop("Can only plot 'numeric', 'integer', 'factor', 'ordered' or 'logical' layers, check your layers")   
      
      
      final.fields <- append(final.fields, these.layers)
  
    } # end if length(layers.present) > 0
    
  }
  
  return(final.fields)
  
}


#####################################################################################################################
################ CORRECTS AN ARTEFACT FROM MAPS PACKAGE WHERE EASTERN ASIA IS WRONGLY PLACED ########################
#####################################################################################################################

#' 
#' Fixes a spatial lines object where some of eastern Russia transposed to the other side of the world
#' 
#' 
#' @param spl SpatialLines object to fix
#' @return a the SpatialLines object 
#' @author Joerg Steinkamp \email{joerg.steinkamp@@senckenberg.de}
#' @keywords internal
correct.map.offset <- function(spl) {
  
  we <- raster::crop(spl, raster::extent(-180, 180, -90, 90))
  ww <- raster::crop(spl, raster::extent(179.999, 200, -90, 90))
  
  if(!is.null(ww) & !is.null(we)) {
    
    ww <- raster::shift(ww, -360)
    spl <- raster::bind(we, ww)  
    
  }
  return(spl)
}



#' Make a PFT colour list
#' 
#' This is a helper function for when plotting PFTs by colour.  It takes a list of PFT ids (other things like "Total" or "Tree" can also be specified) and returns a list 
#' of colours with the names of the PFT (which is how ggplot likes colours to be specified).
#' 
#' @param values List of values (as chararacters) for which you want standard colours.
#' @param pfts A list of PFT objects (which should contain PFTs with ids provided in 'values)
#' @param others A list of other name-colour combinations, for example to plot 'Total' as black, "None" as grey, or whatever.  Some defaults are defined.
#' @return Returns a named list of colours, where the names are the values that the colours will represent
#' @author Matthew Forrest \email{matthew.forrest@@senckenberg.de}
#' @export
#' 
#' 
matchPFTCols <- function(values, pfts, others = list(Total = "black", None = "grey75", Tree = "brown", Grass = "green", Shrub = "red")) {
  
  these.cols <- list()
  at.least.one.match <- FALSE
  for(val in values) {
    
    # ignore NAs
    if(!is.na(val)) {
      
      # check if it is a PFT
      done <- FALSE
      for(PFT in pfts){
        if(val == PFT@id) {
          these.cols[[val]] <- PFT@colour
          done <- TRUE
          at.least.one.match <- TRUE
        }
      } 
      
      # if not a PFT, check if it is as 'other' 
      if(!done) {
        for(other in names(others)) {
          if(tolower(val) == tolower(other)) {
            these.cols[[val]] <- others[[other]]
            done <- TRUE
            at.least.one.match <- TRUE
          }
        }
      }
      
      # if no colour can be found to match the value, fail gently
      if(!done && at.least.one.match) {
        warning(paste0("Some value (", val, ") doesn't have a specified colour, so matchPFTCols is returning NULL. Check your inputs and note the you can provide a colour for (", val, ") using the 'others' argument"))
        return(NULL)
      }  
      
    }  # if not NA
    
  } # for each value
  
  return(unlist(these.cols))
  
}

#' Make a map overlay for ggplot2
#' 
#' Take a string and derives an approriate data.frame that can be used to add a map overlay 
#' (eg coast or country lines from the maps and mapdata packages) with the ggplot::geom_path function.
#' 
#' @param map.overlay A character string specifying the overlay to be used a string matching maps package dataset
#' @param all.lons A numeric vector of all the longitudes to be plotted, this is used to determine if it the over lay should be on longitues (-180,180) or (0,360).
#' @param interior.lines A logical, if TRUE include the internal country lines
#' @param xlim A numeric vector of length 2 to giving the longitude window that the overlay should cover
#' @param ylim A numeric vector of length 2 to giving the latitide window that the overlay should cover
#' @return Returns data.frame suitable for plotting with ggplot::geom_path
#' @author Matthew Forrest \email{matthew.forrest@@senckenberg.de} 
makeMapOverlay <- function(map.overlay, all.lons, interior.lines, xlim, ylim) {
  
  # first check that rgeos package is installed
  if (! requireNamespace("rgeos", quietly = TRUE))  {
    warning("Please install the rgoes R package and, if necessary the GEOS libraries, on your system to make map overlays.")
    return(NULL)
  }
  
  
  ### PREPARE THE MAP OVERLAY
  if(is.character("character")){
    
    # determine if london centered (if not call "maps2" for Pacific centered versions)
    gt.180 <- FALSE
    for(lon in all.lons) {
      if(lon > 180) gt.180 <- TRUE
    }
    
    if(map.overlay=="world" && gt.180) map.overlay <- "world2"
    else if(map.overlay=="worldHires" && gt.180) map.overlay <- "worldHires2"
    else if(map.overlay=="world2" && !gt.180) map.overlay <- "world"
    else if(map.overlay=="world2Hires" && !gt.180) map.overlay <- "worldHires"
    
    # Convert map to SpatialLinesDataFrame, perform the 'Russian Correction' and then fortify() for ggplot2
    proj4str <- "+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0 +no_defs"
    map.sp.lines <- maptools::map2SpatialLines(maps::map(map.overlay, plot = FALSE, interior = interior.lines, xlim=xlim, ylim=ylim, fill=TRUE), proj4string = sp::CRS(proj4str))
    suppressWarnings(df <- data.frame(len = sapply(1:length(map.sp.lines), function(i) rgeos::gLength(map.sp.lines[i, ]))))
    rownames(df) <- sapply(1:length(map.sp.lines), function(i) map.sp.lines@lines[[i]]@ID)
    map.sp.lines.df <- sp::SpatialLinesDataFrame(map.sp.lines, data = df)
    if(!gt.180) map.sp.lines.df <- correct.map.offset(map.sp.lines.df)
    return(fortify(map.sp.lines.df))
    
  }
  else {
    stop(paste0("Can't make an overlay from type ", class(map.overlay)))
  }
  
}