Wall art, one image per picture frame, numbered in the order of
WallArt.LIST (scripts/data/wall_art.gd): art01 is the first entry, art02
the second, up to art12. Each can be a .png or a .jpg (or .jpeg or .webp).

The frames hang empty (white) until their card is locked into its own
binder pocket; then the art fades in and the frame's achievement unlocks.

  Over the binder shelf, left to right as you face it (landscape):
    art01  Plains     art02  Island     art03  Swamp
    art04  Mountain   art05  Forest
  Over the reading corner, as you face the wall (the shelf is on your
  right, the door on your left):
    art06  the big centre piece, over the floor lamp (landscape)
    art07  shelf side of the centre piece, top (landscape, small)
    art08  shelf side, bottom (landscape, small)
    art09  door side, top (landscape, small)
    art10  door side, bottom (landscape, small)
    art11  shelf end (portrait)
    art12  door end (portrait)

Shapes of the windows in the mats (width x height):
  art01-05   88 x 64 cm, about 1.37 : 1 (the usual card art box)
  art06      75 x 55 cm, about 1.37 : 1
  art07-10   36 x 26 cm, about 1.37 : 1
  art11-12   30 x 42 cm, 5 : 7 (full-art and showcase cards)
Any size of image works: it's cropped to fill its window, keeping the
middle. For a sharp picture up close, use at least 1600 px across for
art01-06, 1000 px across for art07-10, and 1000 px across for art11-12.

Which card fills each frame (set code and collector number), and its
achievement's title and line, are in WallArt.LIST; the ones there now are
placeholders from Khans of Tarkir. A frame whose card is filed before its
image is here shows the art box cut from the card's own scan instead.
Images are read when the frame fills, so restart the game (or load the
save) to see a change.

The achievements' icons are achievement054-065 in assets/achievements/.
