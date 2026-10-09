class_name CockfightRankingList
extends VBoxContainer

## The season's cockfight ranking, one line a rooster: place, name, owner,
## points - the player's in bold color, the village's best with a star.
## Shared by RoosterPanel and CockfightPanel. Built in code.

const TEXT_COLOR := Color(0.27, 0.17, 0.09)
const PLAYER_COLOR := Color(0.2, 0.45, 0.15)
const CHAMPION_MARK := "★"

## `rows`: [{"rank", "name", "owner" ("" for the player's), "points",
## "is_player", "is_champion"}], best first.
func show_ranking(rows: Array) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", 2)
	for row: Dictionary in rows:
		var label := Label.new()
		var who: String = row["name"] if row["owner"].is_empty() else tr("%s (à %s)") % [row["name"], row["owner"]]
		label.text = "%d. %s — %d pts%s" % [row["rank"], who, row["points"],
			("  " + CHAMPION_MARK) if row["is_champion"] else ""]
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", PLAYER_COLOR if row["is_player"] else TEXT_COLOR)
		add_child(label)
