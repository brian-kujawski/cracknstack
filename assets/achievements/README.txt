Achievement icons, two per achievement, numbered in the order of
Achievements.LIST (scripts/progression/achievements.gd): 001 is the first
entry, 002 the second, and so on.

  achievementNNN.png         shown once the achievement is unlocked
  achievementNNN_locked.png  shown while it's locked

The files here now are placeholders (plain green and grey squares,
128 x 128 px). Replace them with the real art under the same names; the
game shows each image as it is, scaled to the tile. If a number's pair is
missing, its tile falls back to achievement001.

001-016 are the upgrade tree's cards (Achievements.LIST), 017-052 the 36
rare cards in the display cabinets in order (Achievements.RARE), 053
the one for putting every rare card on display, and 054-065 the twelve
wall art frames in WallArt.LIST order (scripts/data/wall_art.gd): 054-058
the basic lands over the shelf, 059-065 the reading corner's frames;
066 finding the first of the seven cards banned in 2020 for racist
content (Achievements.BANNED_CARDS), 067 finding all seven.
