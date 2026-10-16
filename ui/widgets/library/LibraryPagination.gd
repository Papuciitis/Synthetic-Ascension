extends RefCounted
## Synchronous pagination for the library's textual BBCode. Every continuation
## is independently parseable: open formatting and URL scopes are reopened.
## The supplied dimensions are the text inset, after page furniture is removed.

const INLINE_TAGS := ["b", "i", "u", "s", "code", "url", "color", "bgcolor", "font", "font_size", "outline_size", "outline_color", "lang", "opentype_features", "hint", "fade", "wave", "tornado", "shake", "rainbow", "pulse"]
const WRAP_FLAGS := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE


static func paginate(bbcode: String, font: Font, font_size: int, width: float, height: float) -> Array[String]:
	if bbcode.is_empty():
		return [""]
	if font == null:
		font = ThemeDB.fallback_font
	var tokens := _tokenize(bbcode)
	var plain := ""
	var measured_size := maxi(1, font_size)
	for token: Dictionary in tokens:
		plain += String(token.get("text", ""))
		if token.get("name", "") == "font_size" and not token.get("closing", false):
			var value := String(token["raw"]).trim_prefix("[font_size=").trim_suffix("]").trim_prefix("\"").trim_suffix("\"")
			if value.is_valid_int():
				measured_size = maxi(measured_size, int(value))
	if plain.is_empty():
		return [bbcode]
	var boundaries := TextServerManager.get_primary_interface().string_get_character_breaks(plain)
	if boundaries.is_empty() or boundaries[-1] != plain.length():
		boundaries.append(plain.length())
	var cuts: Array[int] = []
	var start := 0
	while start < plain.length():
		var end := _page_end(plain, start, boundaries, font, measured_size, width, height)
		cuts.append(end)
		start = end
	if cuts.size() == 1:
		return [bbcode]
	return _split_markup(tokens, cuts)


static func _fits(text: String, font: Font, font_size: int, width: float, height: float) -> bool:
	# Leave room for semibold/italic variation, RichTextLabel line separation,
	# and its paragraph metrics. Measurement still shapes whole strings, so
	# kerning, fallback glyphs and long-word wrapping are retained.
	var measured := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, maxf(1.0, width * 0.92 - 4.0), font_size, -1, WRAP_FLAGS)
	var lines := maxf(1.0, ceilf(measured.y / maxf(1.0, font.get_height(font_size))))
	return measured.y * 1.18 + lines * 4.0 <= height - 4.0


static func _page_end(plain: String, start: int, boundaries: PackedInt32Array, font: Font, font_size: int, width: float, height: float) -> int:
	var first := boundaries.bsearch(start + 1)
	var low := first
	var high := boundaries.size() - 1
	var best := first
	while low <= high:
		var middle := (low + high) / 2
		var end := boundaries[middle]
		if _fits(plain.substr(start, end - start), font, font_size, width, height):
			best = middle
			low = middle + 1
		else:
			high = middle - 1
	var cut := boundaries[best]
	if cut == plain.length():
		return cut
	var prefix := plain.substr(start, cut - start)
	# Prefer a whole paragraph only when the preceding text fills most of
	# the leaf. Character counts confuse a short heading with a dense passage
	# and can otherwise leave nearly half the printed page empty.
	var paragraph := prefix.rfind("\n\n")
	if paragraph >= 0:
		var preceding := prefix.substr(0, paragraph + 2)
		var measured := font.get_multiline_string_size(preceding, HORIZONTAL_ALIGNMENT_LEFT, maxf(1.0, width * 0.92 - 4.0), font_size, -1, WRAP_FLAGS)
		var lines := maxf(1.0, ceilf(measured.y / maxf(1.0, font.get_height(font_size))))
		if measured.y + maxf(0.0, lines - 1.0) * 4.0 >= height * 0.70:
			return start + paragraph + 2
	for index: int in range(prefix.length() - 1, -1, -1):
		if prefix[index] in [" ", "\n", "\t"]:
			return _avoid_short_tail(plain, start, start + index + 1)
	return cut


static func _avoid_short_tail(plain: String, start: int, cut: int) -> int:
	var paragraph_end := plain.find("\n\n", cut)
	if paragraph_end < 0:
		paragraph_end = plain.length()
	var tail := plain.substr(cut, paragraph_end - cut)
	if tail.strip_edges().is_empty() or _word_count(tail) > 2:
		return cut
	var paragraph_start := plain.rfind("\n\n", cut - 1) + 2
	if paragraph_start == 1:
		paragraph_start = 0
	var earliest := maxi(start, paragraph_start)
	var candidate := cut
	# Move complete preceding words to the short ending. This only shortens
	# the current leaf; the next leaf is then measured afresh by _page_end.
	while _word_count(plain.substr(candidate, paragraph_end - candidate)) < 3:
		var cursor := candidate - 1
		while cursor >= earliest and plain[cursor] in [" ", "\n", "\t", "\r"]:
			cursor -= 1
		while cursor >= earliest and plain[cursor] not in [" ", "\n", "\t", "\r"]:
			cursor -= 1
		var word_start := cursor + 1
		if word_start <= start:
			return cut
		# A cut between the two newlines of a paragraph break starts the scan
		# after its own paragraph, where no earlier word exists. Without this
		# the candidate never moves and the reader freezes.
		if word_start >= candidate:
			return cut
		candidate = word_start
		if candidate == paragraph_start:
			return candidate
	# Do not cure a short ending by leaving a short beginning at the bottom.
	if _word_count(plain.substr(earliest, candidate - earliest)) < 3:
		return cut
	return candidate


static func _word_count(text: String) -> int:
	return text.replace("\n", " ").replace("\t", " ").replace("\r", " ").split(" ", false).size()


static func _tokenize(bbcode: String) -> Array[Dictionary]:
	var tokens: Array[Dictionary] = []
	var offset := 0
	while offset < bbcode.length():
		if bbcode[offset] == "[":
			var end := _tag_end(bbcode, offset)
			if end >= 0:
				var raw := bbcode.substr(offset, end - offset + 1)
				var inner := raw.substr(1, raw.length() - 2)
				var closing := inner.begins_with("/")
				var name := inner.trim_prefix("/").split("=", false, 1)[0].split(" ", false, 1)[0].to_lower()
				if inner == "lb" or inner == "rb":
					tokens.append({"raw": raw, "text": "[" if inner == "lb" else "]"})
					offset = end + 1
					continue
				if name in INLINE_TAGS:
					tokens.append({"raw": raw, "name": name, "closing": closing})
					offset = end + 1
					continue
		# A text run is retained verbatim, including whitespace and unrecognized
		# bracket text. No source characters are trimmed during page breaks.
		var next := bbcode.find("[", offset + 1)
		if next < 0:
			next = bbcode.length()
		var text := bbcode.substr(offset, next - offset)
		tokens.append({"raw": text, "text": text})
		offset = next
	return tokens


static func _tag_end(text: String, start: int) -> int:
	var quote := ""
	for index: int in range(start + 1, text.length()):
		var character := text[index]
		if not quote.is_empty():
			if character == quote:
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
		elif character == "]":
			return index
		elif character == "[" or character == "\n":
			return -1
	return -1


static func _split_markup(tokens: Array[Dictionary], cuts: Array[int]) -> Array[String]:
	# A shorthand [url] uses all of its visible text as its destination.
	# Resolve that before dividing it, otherwise each page links to a fragment.
	for index: int in range(tokens.size()):
		if tokens[index]["raw"] != "[url]":
			continue
		var destination := ""
		for next: int in range(index + 1, tokens.size()):
			if tokens[next].get("name", "") == "url" and tokens[next].get("closing", false):
				tokens[index]["raw"] = "[url=%s]" % destination
				break
			destination += String(tokens[next].get("text", ""))
	var pages: Array[String] = []
	var active: Array[Dictionary] = []
	var token_index := 0
	var token_offset := 0
	var visible_offset := 0
	for cut: int in cuts:
		var page := ""
		for scope: Dictionary in active:
			page += String(scope["raw"])
		while token_index < tokens.size():
			var token := tokens[token_index]
			if token.has("name"):
				page += String(token["raw"])
				if token["closing"]:
					if not active.is_empty() and active[-1]["name"] == token["name"]:
						active.pop_back()
				else:
					active.append(token)
				token_index += 1
				continue
			if visible_offset >= cut:
				break
			var text := String(token["text"])
			var take := mini(text.length() - token_offset, cut - visible_offset)
			if token["raw"] == text:
				page += text.substr(token_offset, take)
			else:
				page += String(token["raw"])
			token_offset += take
			visible_offset += take
			if token_offset == text.length():
				token_index += 1
				token_offset = 0
		for index: int in range(active.size() - 1, -1, -1):
			page += "[/%s]" % active[index]["name"]
		pages.append(page)
	return pages
