package main

import "core:math/rand"
import "ecs"
import "domain"
import "vendor:raylib"

Input :: struct {
	mouse:    [2]f32,
	pressed:  bool, // left button went down this frame
	released: bool, // left button went up this frame
	down:     bool,
}

World :: struct {
	store:     ^ecs.Store,
	bus:       domain.Bus,
	state:     domain.State,
	battle:    domain.Battle,
	input:     Input,
	dt:        f32,
	screen:    Area,
	rng:       rand.Generator,
	active:    ^ecs.Scene,
	active_id: domain.Scene_Id,
	hud:       ^ecs.Scene, // persistent presentation: lives outside any screen

	// set by scene builders; nil when not in that scene
	stage:         ^Area, // Shop reveal stage
	reveal_active: bool,
}

System :: proc(w: ^World)

Scene_Def :: struct {
	build:   proc(w: ^World) -> ^ecs.Scene,
	systems: []System,
}

SCENES := [domain.Scene_Id]Scene_Def{
	.Home = {build = home_build},
	.Shop = {build = shop_build, systems = []System{reveal_spawner, reveal}},
	.Date = {build = date_build, systems = []System{hand_view, result_spawner}},
	.Deck = {build = deck_build},
}

// Runs every frame, in this order. scene_manager is first so nothing holds
// stale pointers into a scene that was just torn down.
PIPELINE := []System{
	input_poll,
	scene_manager,
	hit_test,
	gate,
	button,
	economy,
	tap_rules,
	focus_rules,
	shop_rules,
	probe_rules,
	date_start_rules,
	play_card_rules,
	end_turn_rules,
	deck_rules,
	navigation_flow,
	layout,
	tween,
	toast,
	lifetime,
}

world_init :: proc(store: ^ecs.Store) -> ^World {
	w := new(World) // heap: UI nodes keep pointers into w.screen
	w.store = store
	domain.bus_init(&w.bus)
	w.rng = context.random_generator
	// Starting collection: enough commons for a first legal deck. With a
	// 5-copy limit per common and a 24-card minimum, at least five distinct
	// commons are needed (these give 28 usable cards).
	w.state.collection[.Compliment]  = 6
	w.state.collection[.Smile]       = 6
	w.state.collection[.Ask_Question] = 5
	w.state.collection[.Listen]      = 5
	w.state.collection[.Share_Story] = 4
	w.state.collection[.Light_Tease] = 4
	// Start each character with a legal deck; the Deck screen edits it.
	for who in domain.Character_Id {
		domain.auto_deck(&w.state, who)
	}
	return w
}

world_deinit :: proc(w: ^World) {
	if w.active != nil { ecs.scene_deinit(w.active, w.store) }
	if w.hud != nil    { ecs.scene_deinit(w.hud, w.store) }
	domain.bus_deinit(&w.bus)
	free(w)
}

run_frame :: proc(w: ^World, dt: f32) {
	w.dt = dt
	domain.bus_swap(&w.bus)
	for sys in PIPELINE {
		sys(w)
	}
	if w.active != nil {
		for sys in SCENES[w.active_id].systems {
			sys(w)
		}
	}
	render_all(w)
}

// ---------------------------------------------------------------- spawning

// Spawn an entity owned by the current screen: removed when the screen changes.
spawn_scoped :: proc(w: ^World, comps: ..any) -> ecs.EntityId {
	all := make([dynamic]any, 0, len(comps) + 1, context.temp_allocator)
	append(&all, ..comps)
	append(&all, ecs.new_comp(Scoped{scene = w.active_id}))
	return ecs.store_spawn_with(w.store, all[:])
}

// ---------------------------------------------------------------- scene manager

scene_manager :: proc(w: ^World) {
	for req in domain.bus_read(&w.bus, domain.Scene_Change_Requested) {
		// 1. system-spawned entities of the old screen
		for e in ecs.store_query1_ids(w.store, ^Scoped) {
			ecs.store_remove_entity(w.store, e.id)
		}
		// 2. the old screen's own entities
		if w.active != nil {
			ecs.scene_deinit(w.active, w.store)
			w.active = nil
		}
		w.stage = nil
		w.reveal_active = false

		w.active_id = req.to
		w.active = SCENES[req.to].build(w)
		ecs.scene_spawn(w.active, w.store)
		domain.bus_emit(&w.bus, domain.Scene_Changed{req.to})
	}
}

// ---------------------------------------------------------------- input

input_poll :: proc(w: ^World) {
	w.input.mouse    = raylib.GetMousePosition()
	w.input.pressed  = raylib.IsMouseButtonPressed(.LEFT)
	w.input.released = raylib.IsMouseButtonReleased(.LEFT)
	w.input.down     = raylib.IsMouseButtonDown(.LEFT)
}
