Rare card art, one image per rare card, numbered in the order of
RareCards.LIST (scripts/data/rare_cards.gd): rare001 is the first entry,
rare002 the second, up to rare036. Each can be a .png or a .jpg (or
.jpeg or .webp).

  rareNNN.png   the card's face, shown wherever the card lies face up: in
                hand, up close, on the floor and tables, and in its
                shadow box in the display cabinets
  rareNNN_back.png
                the card's back, in place of the usual card back (delete
                one and that card has the usual back)

A card with no face image shows the gold placeholder face drawn by the
card shader, so add images one at a time as they're ready. Use the same
shape as the real card scans (63 x 88 mm, portrait, e.g. 488 x 680 px);
the rounded corners are cut by the shader. Images are read when the game
starts, so restart it to see a change.

The cards' names live in RareCards.LIST, and their achievements' titles and
lines in Achievements.RARE (scripts/progression/achievements.gd), with
icons achievement017-052 (one per card) and achievement053 (all 36) in
assets/achievements/.
