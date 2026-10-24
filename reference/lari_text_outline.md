# Text as polygon outlines

Shape a string with 'textshaping' and flatten each glyph outline with
'systemfonts', returning the closed rings of every glyph. Letters with
counters (A, B, O, ...) come back as an outer ring and one or more hole
rings;
[`lari_glyphs()`](https://hypertidy.github.io/laridae/reference/lari_glyphs.md)
meshes them.

## Usage

``` r
lari_text_outline(text, em = 1, tolerance = 0.002, ..., res = 1000)
```

## Arguments

- text:

  a character string (newlines start new lines)

- em:

  the size of one em (the font size) in output units

- tolerance:

  the maximum distance between the flattened outline and the curves of
  the font, in output units

- ...:

  passed to
  [`textshaping::shape_text()`](https://rdrr.io/pkg/textshaping/man/shape_text.html),
  e.g. `family`, `weight`, `italic`, `path` (a font file), `lineheight`,
  `align`, `tracking`

- res:

  the internal shaping size (larger keeps more precision)

## Value

a data frame with `x`, `y`, `glyph` (the glyph's position in the shaped
string), `ring` (the outline contour within the glyph), and `char` (the
glyph's character, empty when one character does not map to one glyph).
Rings are not closed (the first vertex is not repeated) and their
orientation is whatever the font uses.

## Details

Coordinates are in ems: with the default `em = 1` one unit is one em, so
`max_area` and `tolerance` read the same whatever the font. Shaping is
done at `res` and scaled down, so the glyph outlines keep full
precision. Font fallback is respected (each glyph is read from the font
file textshaping chose for it).

## See also

[`lari_glyphs()`](https://hypertidy.github.io/laridae/reference/lari_glyphs.md),
[`lari_text()`](https://hypertidy.github.io/laridae/reference/lari_text.md)

## Examples

``` r
o <- lari_text_outline("B")
table(o$ring)
#> 
#>  1  2  3 
#> 35 35 67 
```
