shader_type canvas_item;
// Coverage-only facade face (CityFacadeComposer): registered with WorldCover
// so actors behind the wall are covered, while the visible masonry is drawn by
// unregistered pieces. Draws nothing itself.
void fragment() {
	discard;
}
