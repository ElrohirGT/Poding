package main

import "ecs"
import "domain"
import "vendor:raylib"

// The Home map: a small field with a Library and one spot per character. The
// player walks with WASD / arrows and presses E next to something to use it.
//   - next to a character -> Date_Start_Requested (the rules still decide)
//   - next to the Library -> Scene_Change_Requested{.Deck}
// These systems only read input and emit intents; they never touch w.state.

MAP_PLAYER_SIZE  :: f32(48)  // px
MAP_PLAYER_SPEED :: f32(240) // px / second
MAP_REACH        :: f32(16)  // px: how close counts as "next to" a spot
MAP_START        :: [2]f32{0.5, 0.82} // centre of the player, fractions of the map

// Rects are fractions of the map area (x, y, w, h).
MAP_LIBRARY_RECT   := [4]f32{0.36, 0.06, 0.28, 0.30}
MAP_CHARACTER_RECT := [domain.Character_Id][4]f32{
	.Rin = {0.10, 0.42, 0.09, 0.16},
	.Kai = {0.81, 0.42, 0.09, 0.16},
}

// ---- sprites ---------------------------------------------------------------
// Point `path` at your sprite sheet and describe its grid. Paths are relative to
// where you run the game. Until the file exists the coloured box is drawn.
//   frame_w/frame_h: one cell in pixels   frames: cells used   row: which strip
//   padding: gap in pixels between cells   margin: border around the whole sheet
//   fps: animation speed                  playing: NPCs idle-animate forever
CHARACTER_SPRITES := [domain.Character_Id]Sprite{
	.Rin = {path = "assets/Rin.png", frame_w = 50, frame_h = 50, padding = 1, frames = 7, row = 0, fps = 6, playing = true},
	.Kai = {path = "assets/Kai.png", frame_w = 85, frame_h = 115, padding = 15, frames = 8, row = 0, fps = 6, playing = true},
}

// The player only animates while walking. With PLAYER_DIRECTIONAL the sheet has
// one row per facing; PLAYER_ROWS gives them as {down, left, right, up}.
PLAYER_SPRITE := Sprite{
	path = "assets/Player.png", frame_w = 48, frame_h = 48, padding = 0, frames = 11, row = 0, fps = 24,
	fallback = {245, 205, 90, 255},
}
PLAYER_DIRECTIONAL :: true
PLAYER_ROWS        := [4]i32{0, 1, 2, 3}

character_color :: proc(who: domain.Character_Id) -> raylib.Color {
	switch who {
	case .Rin: return {210, 110, 160, 255}
	case .Kai: return {100, 140, 210, 255}
	}
	return {150, 150, 150, 255}
}

map_player_rect :: proc(area: Area, centre: [2]f32) -> raylib.Rectangle {
	half := MAP_PLAYER_SIZE / 2
	return {area.x + centre.x - half, area.y + centre.y - half, MAP_PLAYER_SIZE, MAP_PLAYER_SIZE}
}

// Library and characters are solid.
map_blocked :: proc(w: ^World, rect: raylib.Rectangle) -> bool {
	for q in ecs.store_query2(w.store, ^Map_Spot, ^Area) {
		if raylib.CheckCollisionRecs(rect, rl_rect(q.ct2^)) { return true }
	}
	return false
}

map_walk :: proc(w: ^World) {
	area := w.map_area
	if area == nil || area.z <= 0 || area.w <= 0 { return }

	half := MAP_PLAYER_SIZE / 2
	size := [2]f32{area.z, area.w}

	dir: [2]f32
	if raylib.IsKeyDown(.W) || raylib.IsKeyDown(.UP)    { dir.y -= 1 }
	if raylib.IsKeyDown(.S) || raylib.IsKeyDown(.DOWN)  { dir.y += 1 }
	if raylib.IsKeyDown(.A) || raylib.IsKeyDown(.LEFT)  { dir.x -= 1 }
	if raylib.IsKeyDown(.D) || raylib.IsKeyDown(.RIGHT) { dir.x += 1 }
	moving := dir != {}
	if dir.x != 0 && dir.y != 0 { dir *= 0.70710678 }
	step := dir * (MAP_PLAYER_SPEED * min(w.dt, 0.05))

	// Move one axis at a time so the player slides along walls. If the player
	// somehow starts inside something (window resized), let them walk out.
	pos := w.map_pos * size
	stuck := map_blocked(w, map_player_rect(area^, pos))
	for axis in 0 ..< 2 {
		next := pos
		next[axis] = clamp(next[axis] + step[axis], half, size[axis] - half)
		if stuck || !map_blocked(w, map_player_rect(area^, next)) {
			pos = next
		}
	}
	w.map_pos = pos / size

	// Drive the player entity (Layout for next frame, Area so there is no lag).
	rect := map_player_rect(area^, pos)
	for q in ecs.store_query3(w.store, ^Map_Player, ^Layout, ^Area) {
		q.ct2.rect = {(pos.x - half) / size.x, (pos.y - half) / size.y, MAP_PLAYER_SIZE / size.x, MAP_PLAYER_SIZE / size.y}
		q.ct3^ = Area{rect.x, rect.y, rect.width, rect.height}
	}

	// Walk animation: play while moving, pick the row for the facing direction.
	for q in ecs.store_query2(w.store, ^Map_Player, ^Sprite) {
		sp := q.ct2
		sp.playing = moving
		if moving && PLAYER_DIRECTIONAL {
			switch {
			case abs(dir.x) > abs(dir.y): sp.row = PLAYER_ROWS[2] if dir.x > 0 else PLAYER_ROWS[1]
			case dir.y > 0:               sp.row = PLAYER_ROWS[0]
			case:                         sp.row = PLAYER_ROWS[3]
			}
		}
	}

	// Which spot (if any) is the player next to? Closest wins.
	reach := raylib.Rectangle{rect.x - MAP_REACH, rect.y - MAP_REACH, rect.width + 2 * MAP_REACH, rect.height + 2 * MAP_REACH}
	cx, cy := rect.x + rect.width / 2, rect.y + rect.height / 2
	best: Maybe(Map_Spot)
	best_d := f32(1e30)
	for q in ecs.store_query2(w.store, ^Map_Spot, ^Area) {
		a := q.ct2^
		if !raylib.CheckCollisionRecs(reach, rl_rect(a)) { continue }
		dx, dy := a.x + a.z / 2 - cx, a.y + a.w / 2 - cy
		if d := dx * dx + dy * dy; d < best_d {
			best_d = d
			best = q.ct1^
		}
	}
	w.map_near = best
}

map_interact :: proc(w: ^World) {
	near, ok := w.map_near.?
	if !ok || !raylib.IsKeyPressed(.E) { return }
	switch near.kind {
	case .Library:
		domain.bus_emit(&w.bus, domain.Scene_Change_Requested{.Deck})
	case .Character:
		// The Date screen reads the focused character, so focus them first.
		// If the deck is too small the rules reject the date and say why.
		domain.bus_emit(&w.bus, domain.Focus_Character_Requested{near.who})
		domain.bus_emit(&w.bus, domain.Date_Start_Requested{near.who})
	}
}
