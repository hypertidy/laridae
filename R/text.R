#' Text as polygon outlines
#'
#' Shape a string with 'textshaping' and flatten each glyph outline with
#' 'systemfonts', returning the closed rings of every glyph. Letters with
#' counters (A, B, O, ...) come back as an outer ring and one or more hole
#' rings; [lari_glyphs()] meshes them.
#'
#' Coordinates are in ems: with the default `em = 1` one unit is one em, so `max_area` and `tolerance` read the same whatever the font.
#' Shaping is done at `res` and scaled down, so the glyph outlines keep full
#' precision. Font fallback is respected (each glyph is read from the font
#' file textshaping chose for it).
#'
#' @param text a character string (newlines start new lines)
#' @param em the size of one em (the font size) in output units
#' @param tolerance the maximum distance between the flattened outline and
#'   the curves of the font, in output units
#' @param ... passed to [textshaping::shape_text()], e.g. `family`,
#'   `weight`, `italic`, `path` (a font file), `lineheight`, `align`,
#'   `tracking`
#' @param res the internal shaping size (larger keeps more precision)
#' @return a data frame with `x`, `y`, `glyph` (the glyph's position in the
#'   shaped string), `ring` (the outline contour within the glyph), and
#'   `char` (the glyph's character, empty when one character does not map
#'   to one glyph). Rings are not closed (the first vertex is not repeated)
#'   and their orientation is whatever the font uses.
#' @seealso [lari_glyphs()], [lari_text()]
#' @export
#' @examplesIf requireNamespace("textshaping", quietly = TRUE) && requireNamespace("systemfonts", quietly = TRUE)
#' o <- lari_text_outline("B")
#' table(o$ring)
lari_text_outline <- function(text, em = 1, tolerance = 0.002, ..., res = 1000) {
  need_pkg("textshaping")
  need_pkg("systemfonts")
  if (!is.character(text) || length(text) != 1L || is.na(text)) {
    stop("'text' must be a single character string")
  }
  shaped <- textshaping::shape_text(text, size = res, ...)$shape
  scale <- em / res
  tol_px <- max(tolerance / scale, 1e-3)
  chars <- strsplit(text, "")[[1L]]
  pieces <- vector("list", nrow(shaped))
  font <- paste(shaped$font_path, shaped$font_index)
  for (f in unique(font)) {
    rows <- which(font == f)
    o <- systemfonts::glyph_outline(shaped$index[rows], shaped$font_path[rows[1L]],
                                    index = shaped$font_index[rows[1L]],
                                    size = res, tolerance = tol_px)
    for (k in seq_along(rows)) {
      g <- o[o$glyph == k, , drop = FALSE]
      if (nrow(g) == 0L) next
      i <- rows[k]
      pieces[[i]] <- data.frame(
        x = (g$x + shaped$x_offset[i]) * scale,
        y = (g$y + shaped$y_offset[i]) * scale,
        glyph = i,
        ring = g$contour
      )
    }
  }
  out <- do.call(rbind, pieces)
  if (is.null(out)) {
    return(data.frame(x = numeric(0), y = numeric(0), glyph = integer(0),
                      ring = integer(0), char = character(0)))
  }
  ## one glyph per character (the common case): label the glyph
  ch <- if (nrow(shaped) == length(chars)) chars[shaped$glyph] else rep("", nrow(shaped))
  out$char <- ch[out$glyph]
  open_rings(out)
}

#' Mesh glyph outlines
#'
#' Turn glyph rings into constraint segments and triangulate them, one mesh
#' per glyph (the default) or one mesh for the whole string (`merge = TRUE`).
#' Holes come from the constraint depth: with the default `erase = "holes"`
#' only odd depth is kept, so a counter (depth 2) is a hole and the
#' orientation of the rings does not matter. `erase = "outer"` keeps the
#' counters as part of the mesh (their `depth` tells them apart).
#'
#' `outline` is a data frame with `x`, `y` and ring and glyph id columns. The
#' output of [lari_text_outline()] (`glyph`, `ring`), of
#' `systemfonts::glyph_outline()` (`glyph`, `contour`) and of
#' `string2path::string2path()` (`glyph_id`, `path_id`) are recognised as
#' they are. A ring may repeat its first vertex at the end, or not.
#'
#' @param outline a data frame of rings, see Details
#' @param merge if TRUE triangulate all glyphs in one mesh, so overlapping
#'   glyphs cross and stack in `depth`; otherwise mesh each glyph separately
#'   and bind the tables
#' @inheritParams lari_triangulate
#' @param erase which triangles to keep: "holes" (odd depth, the letter
#'   shapes), "outer" (depth > 0, letters with their counters filled), "hull"
#'   (all, including the space around each letter)
#' @param ... passed to [lari_triangulate()] (`size`, `max_steiner`, ...)
#' @return a list like [lari_triangulate()]: `vertices`, `triangles` and
#'   `segments` tables (rows of `vertices` index the whole result) with a
#'   `glyph` column (NA for triangles when `merge = TRUE`), and `report`, one
#'   row per mesh. The vertex `id` column is local to each glyph's mesh.
#' @seealso [lari_text()], [lari_text_outline()]
#' @export
#' @examples
#' ## a square "O": an outer ring and a hole ring, as a glyph would give
#' o <- data.frame(x = c(0, 1, 1, 0, 0.3, 0.7, 0.7, 0.3),
#'                 y = c(0, 0, 1, 1, 0.3, 0.3, 0.7, 0.7),
#'                 glyph = 1L, ring = rep(1:2, each = 4))
#' r <- lari_glyphs(o, max_area = 0.01)
#' nrow(r$triangles)
lari_glyphs <- function(outline, merge = FALSE, max_area = NULL, min_angle = NULL,
                        min_edge_length = NULL, erase = c("holes", "outer", "hull"), ...) {
  erase <- match.arg(erase)
  rings <- as_rings(outline)
  if (nrow(rings) == 0L) stop("no outline vertices")
  mesh1 <- function(r) {
    s <- ring_segments(r$ring)
    lari_triangulate(r$x, r$y, s$s0, s$s1, max_area = max_area, min_angle = min_angle,
                     min_edge_length = min_edge_length, erase = erase, ...)
  }
  if (merge) {
    rings$ring <- match(paste(rings$glyph, rings$ring), unique(paste(rings$glyph, rings$ring)))
    m <- mesh1(rings)
    ## input vertices come first, in input order
    glyph <- rep(NA_integer_, nrow(m$vertices))
    ids <- m$ids
    glyph[match(ids, m$vertices$id)] <- rings$glyph
    m$vertices$glyph <- glyph
    m$triangles$glyph <- rep(NA_integer_, nrow(m$triangles))
    m$segments$glyph <- rings$glyph[m$segments$segment]
    return(m[c("vertices", "triangles", "segments", "report")])
  }
  glyphs <- unique(rings$glyph)
  nv <- 0L
  ns <- 0L
  vv <- tt <- ss <- rr <- vector("list", length(glyphs))
  for (k in seq_along(glyphs)) {
    r <- rings[rings$glyph == glyphs[k], , drop = FALSE]
    m <- mesh1(r)
    v <- m$vertices
    v$glyph <- rep(glyphs[k], nrow(v))
    tr <- m$triangles
    tr[c("v0", "v1", "v2")] <- tr[c("v0", "v1", "v2")] + nv
    tr$glyph <- rep(glyphs[k], nrow(tr))
    sg <- m$segments
    sg[c("v0", "v1")] <- sg[c("v0", "v1")] + nv
    sg$segment <- sg$segment + ns
    sg$glyph <- rep(glyphs[k], nrow(sg))
    rp <- m$report
    rp$glyph <- glyphs[k]
    vv[[k]] <- v; tt[[k]] <- tr; ss[[k]] <- sg; rr[[k]] <- rp
    nv <- nv + nrow(v)
    ns <- ns + nrow(r)
  }
  list(vertices = bind_rows(vv), triangles = bind_rows(tt),
       segments = bind_rows(ss), report = bind_rows(rr))
}

#' Meshed text
#'
#' Shape a string, take its glyph outlines and mesh them: the one-call form
#' of [lari_text_outline()] followed by [lari_glyphs()]. Needs the
#' 'textshaping' and 'systemfonts' packages.
#'
#' @inheritParams lari_text_outline
#' @inheritParams lari_glyphs
#' @param family,weight,italic,path font selection, passed to
#'   [textshaping::shape_text()] (`path` is a font file, which overrides
#'   `family`)
#' @param ... passed to [lari_glyphs()] and on to [lari_triangulate()]
#'   (`max_area`, `min_angle`, `size` for a sizing field, `erase`, `merge`)
#' @return see [lari_glyphs()]
#' @export
#' @examplesIf requireNamespace("textshaping", quietly = TRUE) && requireNamespace("systemfonts", quietly = TRUE)
#' r <- lari_text("lari", max_area = 0.002, min_angle = 25)
#' table(r$triangles$glyph)
#' tri <- r$triangles
#' idx <- rbind(tri$v0, tri$v1, tri$v2, NA)
#' plot(r$vertices$x, r$vertices$y, type = "n", asp = 1, axes = FALSE,
#'      xlab = "", ylab = "")
#' polygon(r$vertices$x[idx], r$vertices$y[idx], col = "grey90", border = "grey40")
lari_text <- function(text, family = "", weight = "normal", italic = FALSE, path = NULL,
                      em = 1, tolerance = 0.002, ...) {
  o <- lari_text_outline(text, em = em, tolerance = tolerance, family = family,
                         weight = weight, italic = italic, path = path)
  out <- lari_glyphs(o, ...)
  chars <- unique(o[c("glyph", "char")])
  out$vertices$char <- chars$char[match(out$vertices$glyph, chars$glyph)]
  out$triangles$char <- chars$char[match(out$triangles$glyph, chars$glyph)]
  out
}

need_pkg <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(sprintf("package '%s' is needed for text outlines", pkg), call. = FALSE)
  }
}

bind_rows <- function(x) {
  x <- x[!vapply(x, is.null, logical(1))]
  out <- do.call(rbind, x)
  rownames(out) <- NULL
  out
}

## standardise ring columns to x, y, glyph, ring and drop closing vertices
as_rings <- function(outline) {
  if (!is.data.frame(outline)) stop("'outline' must be a data frame")
  pick <- function(cands) {
    hit <- intersect(cands, names(outline))
    if (length(hit) == 0L) NULL else outline[[hit[1L]]]
  }
  x <- pick("x")
  y <- pick("y")
  if (is.null(x) || is.null(y)) stop("'outline' needs 'x' and 'y' columns")
  glyph <- pick(c("glyph", "glyph_id"))
  ring <- pick(c("ring", "contour", "path_id", "path"))
  if (is.null(glyph)) glyph <- rep(1L, length(x))
  if (is.null(ring)) ring <- rep(1L, length(x))
  out <- data.frame(x = as.numeric(x), y = as.numeric(y),
                    glyph = as.integer(glyph), ring = as.integer(ring))
  if (anyNA(out)) stop("'outline' must not contain missing values")
  open_rings(out)
}

## drop the last vertex of a ring when it repeats the first, and rings too
## short to bound anything
open_rings <- function(d) {
  key <- paste(d$glyph, d$ring)
  n <- nrow(d)
  if (n == 0L) return(d)
  last <- c(key[-1L] != key[-n], TRUE)
  first <- c(TRUE, key[-1L] != key[-n])
  first_row <- cumsum(first)
  start <- which(first)[first_row]
  closing <- last & !first & d$x == d$x[start] & d$y == d$y[start]
  d <- d[!closing, , drop = FALSE]
  key <- key[!closing]
  d <- d[key %in% names(which(table(key) >= 3L)), , drop = FALSE]
  rownames(d) <- NULL
  d
}

## segments closing each run of rows with the same ring id
ring_segments <- function(ring) {
  n <- length(ring)
  i <- seq_len(n)
  first <- c(TRUE, ring[-1L] != ring[-n])
  last <- c(ring[-1L] != ring[-n], TRUE)
  start <- which(first)[cumsum(first)]
  list(s0 = i, s1 = ifelse(last, start, i + 1L))
}
