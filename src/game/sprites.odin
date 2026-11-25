package main

import "core:strings"
import "ecs"
import "vendor:raylib"

// Sprite sheets: textures are loaded lazily by path and cached in w.textures
// (also on failure, so a missing file is reported once, not every frame).
// Rendering stays read-only: it only looks textures up; loading happens here.

sprite_texture :: proc(w: ^World, path: string) {
	if path == "" || path in w.textures { return }
	tex := raylib.LoadTexture(strings.clone_to_cstring(path, context.temp_allocator))
	if tex.id != 0 {
		raylib.SetTextureFilter(tex, .POINT) // crisp pixel art
	}
	w.textures[path] = tex
}

// Current cell in the row for a sprite's clock.
sprite_frame :: proc(sp: ^Sprite) -> i32 {
	if sp.frames <= 1 || sp.fps <= 0 { return 0 }
	return i32(sp.time * sp.fps) % sp.frames
}

// Loads what is needed and advances the clocks of playing sprites.
sprite_animate :: proc(w: ^World) {
	for sp in ecs.store_query1(w.store, ^Sprite) {
		sprite_texture(w, sp.path)
		if sp.playing {
			sp.time += w.dt
		} else {
			sp.time = 0
		}
	}
}
