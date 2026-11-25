package ecs

import "core:slice"

Scene :: struct {
	ids: [dynamic]EntityId,
	entities: [dynamic][]any
}

scene_init :: proc() -> ^Scene {
	return new(Scene)
}

scene_add :: proc(sc: ^Scene, components: []any) {
	append(&sc.entities, slice.clone(components))
}

scene_spawn :: proc(sc: ^Scene, st: ^Store) {
	for comps in sc.entities {
		id := store_spawn_with(st, comps)
		append(&sc.ids, id)
	}
}

scene_despawn :: proc(sc: ^Scene, st: ^Store) {
	for ent in sc.ids {
		store_remove_entity(st, ent)
	}
	clear(&sc.ids)
}

scene_deinit :: proc(sc: ^Scene, st: ^Store) {
	scene_despawn(sc, st)
	for ent in sc.entities {
		delete(ent)
	}
	delete(sc.entities)
	delete(sc.ids)
	free(sc)
}
