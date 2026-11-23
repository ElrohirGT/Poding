package main

import "core:fmt"
import "core:math/linalg"
import "core:math"
import "core:strings"
import "vendor:raylib"

Area :: [4]f32
WindowArea :: struct {
	name: string,
	color: raylib.Color,
	current_area: Area,
	ideal_area: Area,
}
WindowSubArea :: struct {
	name: string,
	color: raylib.Color,
	parent: ^WindowArea,
	get_current: proc(Area) -> Area,
}

windows_setup :: proc(windows: []^WindowArea) { // Change window dimensions
	for w in windows {
		if w.name == "Debug" {
			handle_debug_window(w)
		}
		if w.name == "Game" {
			handle_game_window(w)
		}
	}
}

handle_game_window :: proc(w: ^WindowArea) {
	if ENABLE_DEBUG {
		w.ideal_area = GAME_CONFIG.GameRectangle
	} else {
		w.ideal_area = {
			0,
			0,
			f32(GAME_CONFIG.ScreenWidth),
			f32(GAME_CONFIG.ScreenHeight),
		}
	}
}

handle_debug_window :: proc(w: ^WindowArea) {
	if ENABLE_DEBUG {
		w.ideal_area = GAME_CONFIG.DebugRectangle
	} else {
		w.ideal_area = {
			GAME_CONFIG.DebugRectangle.x+GAME_CONFIG.DebugRectangle.z,
			GAME_CONFIG.DebugRectangle.y,
			GAME_CONFIG.DebugRectangle.z,
			GAME_CONFIG.DebugRectangle.w
		}
	}
}

windows_update :: proc(windows: []^WindowArea, dt: f32) {
	vel: f32 = 5
	for w in windows {
		if linalg.distance(w.current_area, w.ideal_area) < 1 {
			continue
		}

		w.current_area = linalg.lerp(w.current_area, w.ideal_area, dt*vel)
	}
}

windows_render :: proc(windows: []^WindowArea) {
	border_width :i32= 4

	for w in windows {
		// if w.name == "Debug" && !ENABLE_DEBUG {
		// 	continue
		// }

		raylib.DrawRectangle(
			i32(w.current_area.x),
			i32(w.current_area.y),
			i32(w.current_area.z),
			i32(w.current_area.w),
			w.color
		)
		raylib.DrawRectangle(
			i32(w.current_area.x+f32(border_width)),
			i32(w.current_area.y+f32(border_width)),
			i32(w.current_area.z-f32(border_width)*2),
			i32(w.current_area.w-f32(border_width)*2),
			raylib.BLACK
		)

		cname, err := strings.clone_to_cstring(w.name, allocator=context.temp_allocator)
		if err != nil {
			panic("Failed to clone text!")
		}
		raylib.DrawText(cname, i32(w.current_area.x+f32(border_width)*2), i32(w.current_area.y+f32(border_width)*2), FontSize, w.color)
	}
}

subwindows_render :: proc(windows: []^WindowSubArea) {
	border_width :i32= 4

	for w in windows {
		parent := w.parent.current_area
		current := w.get_current(parent)
		raylib.DrawRectangle(
			i32(current.x),
			i32(current.y),
			i32(current.z),
			i32(current.w),
			w.color
		)
		raylib.DrawRectangle(
			i32(current.x+f32(border_width)),
			i32(current.y+f32(border_width)),
			i32(current.z-f32(border_width)*2),
			i32(current.w-f32(border_width)*2),
			raylib.BLACK
		)

		cname, err := strings.clone_to_cstring(w.name, allocator=context.temp_allocator)
		if err != nil {
			panic("Failed to clone text!")
		}
		raylib.DrawText(cname, i32(current.x+f32(border_width)*2), i32(current.y+f32(border_width)*2), FontSize, w.color)
	}
}

Life :: struct {
	current: i32,
	max: i32,
	sub_key: raylib.KeyboardKey,
	add_key: raylib.KeyboardKey,
	color: raylib.Color,
}

life_update :: proc (lives: []^Life) {
	for l in lives {
		if raylib.IsKeyPressed(l.sub_key) {
			fmt.println("Reduced life!")
			l.current = max(0, l.current - 1)
		} else if raylib.IsKeyPressed(l.add_key) {
			fmt.println("Aumented life!")
			l.current = min(l.max, l.current + 1)
		}
	}
}

life_render :: proc(lives: []struct{ct1: ^Life, ct2: ^Area}) {
	width: i32 = 20
	padding: i32 = 5
	for l_pack in lives {
		l := l_pack.ct1
		rec := l_pack.ct2
		for i: i32 = 0; i < l.max; i += 1 {
			if i < l.current {
				raylib.DrawRectangle(
					i32(rec.x) + (width+padding) * i,
					i32(rec.y),
					width,
					width,
					l.color,
				)
			} else {
				raylib.DrawRectangleLines(
					i32(rec.x) + (width+padding) * i,
					i32(rec.y),
					width,
					width,
					l.color,
				)
			}
		}
	}
}
