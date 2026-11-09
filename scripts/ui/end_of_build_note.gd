class_name EndOfBuildNote
extends PopupNote
## The note a cut-down build (a playtest build made by tools/package_alpha.py,
## CardDatabase.build) shows when its last chapter is complete: there's no
## more to play in it yet.

## %d: the chapter just finished; %s: the build's name; then the chapters
## still to come.
const TEXT := "Congrats on reaching the end of Chapter %d! This is as far as the %s build goes, check back later for %s!"


func _init(finished: int, build: String, total: int) -> void:
	text = message(finished, build, total)


## The note's text, for a build that stops after chapter `finished` of
## `total` (the chapters data/chapters.txt lists).
static func message(finished: int, build: String, total: int) -> String:
	var coming := "more"
	if total == finished + 1:
		coming = "Chapter %d" % total
	elif total > finished + 1:
		coming = "Chapters %d through %d" % [finished + 1, total]
	return TEXT % [finished, build, coming]
