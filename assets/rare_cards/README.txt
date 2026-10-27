Rare card art, one image per rare card, numbered in the order of
RareCards.LIST (scripts/data/rare_cards.gd): rare001.png is the first
entry, rare002.png the second, up to rare036.png.

  rareNNN.png   the card's face, shown in hand, up close and in its
                shadow box in the display cabinets
  back.png      the back of every rare card, in place of the usual card
                back (delete it and they share the usual back). The one
                here is a placeholder to draw over.

There is no art here yet. A card with no image shows the gold placeholder
face drawn by the card shader, so add images one at a time as they're
ready. Use the same shape as the real card scans (63 x 88 mm, portrait,
e.g. 488 x 680 px); the rounded corners are cut by the shader.

The cards' names live in RareCards.LIST, and their achievements' titles and
lines in Achievements.RARE (scripts/progression/achievements.gd), with
icons achievement017-052 (one per card) and achievement053 (all 36) in
assets/achievements/.
