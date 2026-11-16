args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L || !file.exists(file.path(args[1], "recording.g3"))) {
  stop("Usage: Rscript data-raw/example.R <recording folder> [seconds]", call. = FALSE)
}
source_dir <- args[1]
seconds <- if (length(args) > 1L) as.numeric(args[2]) else 30
out_dir <- file.path("inst", "extdata", "recording")

unlink(out_dir, recursive = TRUE)
dir.create(file.path(out_dir, "meta"), recursive = TRUE)

rec <- jsonlite::fromJSON(file.path(source_dir, "recording.g3"), simplifyVector = FALSE)
meta_dir <- file.path(source_dir, if (is.null(rec[["meta-folder"]])) "meta" else rec[["meta-folder"]])

trim <- function(file) {
  con <- gzfile(file.path(source_dir, file), "rt")
  lines <- readLines(con, warn = FALSE)
  close(con)
  lines <- lines[nzchar(trimws(lines))]
  time <- as.numeric(sub('.*"timestamp":([-0-9.eE+]+).*', "\\1", lines))
  lines <- lines[!is.na(time) & time < seconds]
  con <- gzfile(file.path(out_dir, file), "w")
  writeLines(lines, con)
  close(con)
  lines
}

gaze <- trim(rec$gaze$file)
invisible(trim(rec$imu$file))
invisible(trim(rec$events$file))

rec$uuid <- "00000000-0000-4000-8000-000000000000"
rec$name <- "Example recording"
rec$created <- "2025-01-01T12:00:00Z"
rec$timezone <- "UTC"
rec$duration <- seconds
rec$gaze$samples <- length(gaze)
rec$gaze[["valid-samples"]] <- sum(grepl('"gaze2d"', gaze, fixed = TRUE))
rec$scenecamera$snapshots <- list()
rec[["meta-folder"]] <- "meta"
writeLines(jsonlite::toJSON(rec, auto_unbox = TRUE, digits = NA, null = "null"),
           file.path(out_dir, "recording.g3"))

writeLines("TG03G-000000000000", file.path(out_dir, "meta", "HuSerial"))
writeLines("TG03B-000000000000", file.path(out_dir, "meta", "RuSerial"))
invisible(file.copy(file.path(meta_dir, "RuVersion"), file.path(out_dir, "meta", "RuVersion")))
writeLines('{"name":"example"}', file.path(out_dir, "meta", "participant"))
