package main

import "core:strings"
import "vendor:raylib"

Area :: [4]i32
WindowArea :: struct {
	name: string,
	color: raylib.Color,
	area: Area,
}

setup :: proc(windows: []^WindowArea) {
	// ...Do stuff? What stuff?
}

update :: proc(windows: []^WindowArea) {
	// ...Do animations?
}

render :: proc(windows: []^WindowArea) {
	border_width :i32= 4

	for w in windows {
		raylib.DrawRectangle(
			w.area.x,
			w.area.y,
			w.area.z,
			w.area.w,
			w.color
		)
		raylib.DrawRectangle(
			w.area.x+border_width,
			w.area.y+border_width,
			w.area.z-border_width*2,
			w.area.w-border_width*2,
			raylib.BLACK
		)

		cname, err := strings.clone_to_cstring(w.name, allocator=context.temp_allocator)
		if err != nil {
			panic("Failed to clone text!")
		}
		raylib.DrawText(cname, w.area.x+border_width*2, w.area.y+border_width*2, FontSize, w.color)
	}
}
