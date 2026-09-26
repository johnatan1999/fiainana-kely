class_name Currency
extends RefCounted

## Formats a whole-Ariary amount for display everywhere in the game -
## single source of truth so no two screens format money differently.
## Ariary has no everyday subdivision, so this only ever deals in whole
## units: "12 000 Ar" (thousands grouped with spaces, Malagasy/French
## convention, no decimals).
static func format(amount: int) -> String:
	var is_negative := amount < 0
	var digits := str(absi(amount))
	var groups: Array = []
	var i := digits.length()
	while i > 0:
		var start: int = max(0, i - 3)
		groups.push_front(digits.substr(start, i - start))
		i = start
	var grouped := " ".join(groups)
	return "%s%s Ar" % ["-" if is_negative else "", grouped]
