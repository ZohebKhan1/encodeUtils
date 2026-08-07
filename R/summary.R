encode_size <- function(files) {
    if (!is.data.frame(files) || !"file_size" %in% names(files)) return(0)
    sum(encode_as_file_size(files$file_size), na.rm = TRUE)
}
