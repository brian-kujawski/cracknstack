Achievement icons, two per achievement, numbered in the order of the
achievements in scripts/progression/achievements.gd, from 017
(Achievements.FIRST_ICON).

  achievementNNN.png         shown once the achievement is unlocked
  achievementNNN_locked.png  shown while it's locked

The files here now are placeholders (plain green and grey squares,
128 x 128 px). Replace them with the real art under the same names; the
game shows each image as it is, scaled to the tile. If a number's pair is
missing, its tile falls back to achievement001.

001-016 are free: they were the old upgrade tree's card achievements,
removed with the tree (001 is still the fallback icon). 017-052 the 36
rare cards in the display cabinets in order (Achievements.RARE), 053
the one for putting every rare card on display, and 054-065 the twelve
wall art frames in WallArt.LIST order (scripts/data/wall_art.gd): 054-058
the basic lands over the shelf, 059-065 the reading corner's frames;
066 finding the first of the seven cards banned in 2020 for racist
content (Achievements.BANNED_CARDS), 067 finding all seven, and 068
"Hey, That's Expensive", for tossing the laptop (Achievements.OTHER).
