package main

import "ecs"
import "domain"
import "vendor:raylib"

// `Area` ([4]f32: x, y, width(.z), height(.w)) doubles as the resolved screen
// rectangle of any UI entity. It is declared in systems.odin.

// Resolves to an Area as fractions of `parent`.
Layout :: struct {
	parent: ^Area,
	rect:   [4]f32, // x, y, w, h as fractions of the parent
}

Interactive :: struct {
	enabled, hovered, pressed, clicked: bool,
}

// Data: what to emit on click, not what it does. A nil event is a disabled
// placeholder button.
Button :: struct {
	on_click: domain.Event,
	text:     string,
	selected: bool,
	z:        u8,
}

Panel :: struct {
	color: raylib.Color,
	z:     u8,
}

Bind :: enum u8 {
	None,
	Coins,
	Income,
	Insight,
	Collection_Progress,
	Focus_Name,
	Affinity_Text,
	Notebook_Row, // arg = Approach
	Pack_Cost,    // arg = Pack_Id
	Probe_Cost,
	Turn_Text,
	Energy_Text,
	Next_Move_Text,
	Draw_Count,
	Discard_Count,
	Interest_Text,
	Dialogue,
	Deck_Title,
	Deck_Rules,
	Deck_Status,
	Deck_Card_Info,  // arg = Card_Id
	Deck_Card_Count, // arg = Card_Id
	Map_Prompt,      // what the player can do where they stand on the Home map
}

Label :: struct {
	text:  string, // used when bind == .None
	bind:  Bind,
	arg:   int,
	size:  i32,
	color: raylib.Color,
	z:     u8,
}

Progress_Bind :: enum u8 { Affinity, Interest }

Progress :: struct {
	bind:  Progress_Bind,
	color: raylib.Color,
	z:     u8,
}

Hand_Slot :: struct { index: u8 }

Card_View :: struct {
	card:    domain.Card_Id,
	hint:    domain.Hint,
	visible: bool,
	face_up: bool,  // reveal cards: face-up once flip >= 0.5
	flip:    f32,   // 0..1
	hovered: bool,
	is_new:  bool,
}

// Marks cards spawned by the pack reveal so a new pack can clear the old ones.
Revealed :: struct {}

// Keep on the SAME entity as its target.
Tween :: struct {
	target:        ^f32,
	from, to:      f32,
	t, dur:        f32, // t < 0 is a start delay
}

Lifetime :: struct { remaining, total: f32 }

Toast :: struct {
	buf: [64]u8,
	n:   u8,
}

// Entities spawned by systems (not by the scene builder) are tagged so the
// scene manager can remove them when the screen changes.
Scoped :: struct { scene: domain.Scene_Id }

// A sprite-sheet animation drawn into the entity's Area (instead of a Panel).
// The sheet is a grid of frame_w x frame_h cells: `row` picks the strip, the
// first `frames` cells of that row are the animation. `padding` is the gap
// between cells and `margin` the border around the sheet (both default to 0).
Sprite :: struct {
	path:             string,        // image path, relative to the working dir
	frame_w, frame_h: i32,           // size of one cell in the sheet, in pixels
	padding:          i32,           // empty pixels between neighbouring cells (columns and rows)
	margin:           i32,           // empty pixels around the whole sheet, before the first cell
	frames:           i32,           // cells used in the row
	row:              i32,
	fps:              f32,
	playing:          bool,          // false = hold the first frame
	time:             f32,
	fallback:         raylib.Color,  // drawn as a box when the image is missing
}

// ---- Home map

// The walkable character on the Home map. Its Layout is driven by World.map_pos.
Map_Player :: struct {}

Map_Spot_Kind :: enum u8 { Library, Character }

// Something on the map the player can walk up to (and is blocked by).
Map_Spot :: struct {
	kind: Map_Spot_Kind,
	who:  domain.Character_Id, // used when kind == .Character
}

register_components :: proc(st: ^ecs.Store) {
	ecs.store_register_component(st, ^Area)
	ecs.store_register_component(st, ^Layout)
	ecs.store_register_component(st, ^Interactive)
	ecs.store_register_component(st, ^Button)
	ecs.store_register_component(st, ^Panel)
	ecs.store_register_component(st, ^Label)
	ecs.store_register_component(st, ^Progress)
	ecs.store_register_component(st, ^Hand_Slot)
	ecs.store_register_component(st, ^Card_View)
	ecs.store_register_component(st, ^Revealed)
	ecs.store_register_component(st, ^Tween)
	ecs.store_register_component(st, ^Lifetime)
	ecs.store_register_component(st, ^Toast)
	ecs.store_register_component(st, ^Scoped)
	ecs.store_register_component(st, ^Sprite)
	ecs.store_register_component(st, ^Map_Player)
	ecs.store_register_component(st, ^Map_Spot)
}
