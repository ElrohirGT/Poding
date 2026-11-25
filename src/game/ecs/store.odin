package ecs

import "core:slice"
import "core:fmt"
import "core:testing"

EntityId :: uint

Store :: struct{
	ids: [dynamic]EntityId,
	entities: map[typeid][dynamic]any,
	next_id: EntityId, // monotonically increasing; ids are never reused
}

store_init :: proc(init_components: int) -> ^Store {
	st := new(Store)
	st.ids = make([dynamic]EntityId)
	st.entities = make(map[typeid][dynamic]any)
	return st
}

store_deinit :: proc(st: ^Store) {
	for _, components in st.entities {
		for comp in components {
			comp_free(comp)
		}
		delete(components)
	}
	delete(st.ids)
	delete(st.entities)
	free(st)
}

store_register_component :: proc(st: ^Store, $ComponentId: typeid) {
	entities := [dynamic]any{}
	st.entities[ComponentId] = entities
}

store_spawn_with :: proc(st: ^Store, components: []any) -> EntityId {
	entity_id := st.next_id
	st.next_id += 1
	for comp_id, _ in st.entities {
		value: any
		for comp in components {
			if comp_id == comp.id {
				value = comp
				break
			}
		}

		collection := st.entities[comp_id]
		append(&collection, value)
		st.entities[comp_id] = collection
	}

	append(&st.ids, entity_id)

	return entity_id
}

store_remove_entity :: proc(st: ^Store, id: EntityId) {
	entity_idx := -1
	for value, idx in st.ids {
		if value == id {
			entity_idx = idx
			unordered_remove(&st.ids, idx)
			break
		}
	}

	if entity_idx == -1 {
		panic("Entity not found!")
	}

	for t_id, &components in st.entities {
		comp_free(components[entity_idx])
		unordered_remove(&components, entity_idx)
	}
}

// Like store_query1, but also returns the owning entity id.
store_query1_ids :: proc(st: ^Store, $CT1: typeid) -> []struct{id: EntityId, c: CT1} {
	col := st.entities[CT1]
	result := make([dynamic]struct{id: EntityId, c: CT1}, 0, len(col), context.temp_allocator)
	for component_value, idx in col {
		if component_value != nil {
			append(&result, struct{id: EntityId, c: CT1}{id = st.ids[idx], c = component_value.(CT1)})
		}
	}
	return result[:]
}

store_query1 :: proc(st: ^Store, $CT1: typeid) -> []CT1 {
	result := make([dynamic]CT1, 0, len(st.entities[CT1]), context.temp_allocator)
	for component_value, idx in st.entities[CT1] {
		if component_value != nil {
			append(&result, component_value.(CT1))
		}
	}
	return result[:]
}

store_query2 :: proc(st: ^Store, $CT1: typeid, $CT2: typeid) -> []struct{ct1: CT1, ct2: CT2} {
	st1, found := st.entities[CT1]
	if !found {
		return nil
	}

	result := make([dynamic]struct{ct1: CT1, ct2: CT2}, 0, len(st.entities[CT1]), context.temp_allocator)
	for cp1, entity_id in st1 {
		if cp1 == nil {
			continue
		}

		st2, found := st.entities[CT2]
		if !found {
			continue
		}
		cp2 := st2[entity_id]
		if cp2 != nil && cp1 != nil {
			append(&result, struct{ct1: CT1, ct2: CT2}{
				ct1 = cp1.(CT1),
				ct2 = cp2.(CT2)
			})
		}
	}
	return result[:]
}

store_query3 :: proc(st: ^Store, $CT1: typeid, $CT2: typeid, $CT3: typeid) -> []struct{ct1: CT1, ct2: CT2, ct3: CT3} {
	st1, f1 := st.entities[CT1]
	st2, f2 := st.entities[CT2]
	st3, f3 := st.entities[CT3]
	if !f1 || !f2 || !f3 {
		return nil
	}

	result := make([dynamic]struct{ct1: CT1, ct2: CT2, ct3: CT3}, 0, len(st1), context.temp_allocator)
	for cp1, idx in st1 {
		cp2 := st2[idx]
		cp3 := st3[idx]
		if cp1 != nil && cp2 != nil && cp3 != nil {
			append(&result, struct{ct1: CT1, ct2: CT2, ct3: CT3}{
				ct1 = cp1.(CT1),
				ct2 = cp2.(CT2),
				ct3 = cp3.(CT3),
			})
		}
	}
	return result[:]
}

@(test)
test_scenes :: proc(t: ^testing.T) {
	store := store_init(5)
	defer store_deinit(store)
	defer free_all(context.temp_allocator)

	MovementComponent :: struct {
		x: f32,
		y: f32,
	}
	store_register_component(store, ^MovementComponent)

	scene_a := scene_init()
	defer scene_deinit(scene_a, store)

	scene_add(scene_a, []any {
		new_comp(MovementComponent{0,5}),
	})
	scene_add(scene_a, []any {
		new_comp(MovementComponent{3,4}),
	})
	testing.expect_value(t, len(scene_a.entities), 2)

	scene_b := scene_init()
	defer scene_deinit(scene_b, store)

	scene_add(scene_b, []any {
		new_comp(MovementComponent{10, 15}),
	})
	scene_add(scene_b, []any {
		new_comp(MovementComponent{2,3}),
	})
	testing.expect_value(t, len(scene_b.entities), 2)

	scene_spawn(scene_a, store)
	testing.expect_value(t, len(store.entities[typeid_of(^MovementComponent)]), 2)

	cmps := store_query1(store, ^MovementComponent)
	testing.expect_value(t, len(cmps), 2)
}

@(test)
test_ids_unique_after_remove :: proc(t: ^testing.T) {
	store := store_init(5)
	defer store_deinit(store)
	defer free_all(context.temp_allocator)

	C :: struct { v: int }
	store_register_component(store, ^C)

	a := store_spawn_with(store, []any{new_comp(C{1})})
	b := store_spawn_with(store, []any{new_comp(C{2})})
	c := store_spawn_with(store, []any{new_comp(C{3})})
	store_remove_entity(store, a)
	d := store_spawn_with(store, []any{new_comp(C{4})})

	testing.expect(t, d != b && d != c && d != a, "spawned id must not collide with live or removed ids")

	found := store_query1_ids(store, ^C)
	testing.expect_value(t, len(found), 3)
	for f in found {
		switch f.c.v {
		case 2: testing.expect_value(t, f.id, b)
		case 3: testing.expect_value(t, f.id, c)
		case 4: testing.expect_value(t, f.id, d)
		case: testing.fail_now(t, "unexpected component")
		}
	}
}

@(test)
test_query3 :: proc(t: ^testing.T) {
	store := store_init(5)
	defer store_deinit(store)
	defer free_all(context.temp_allocator)

	A :: struct { v: int }
	B :: struct { v: int }
	C :: struct { v: int }
	store_register_component(store, ^A)
	store_register_component(store, ^B)
	store_register_component(store, ^C)

	store_spawn_with(store, []any{new_comp(A{1}), new_comp(B{2}), new_comp(C{3})})
	store_spawn_with(store, []any{new_comp(A{4}), new_comp(B{5})})
	res := store_query3(store, ^A, ^B, ^C)
	testing.expect_value(t, len(res), 1)
	testing.expect_value(t, res[0].ct3.v, 3)
}

@(test)
test_despawn_then_deinit :: proc(t: ^testing.T) {
	store := store_init(5)
	defer store_deinit(store)
	defer free_all(context.temp_allocator)

	C :: struct { v: int }
	store_register_component(store, ^C)

	sc := scene_init()
	scene_add(sc, []any{new_comp(C{1})})
	scene_add(sc, []any{new_comp(C{2})})
	scene_spawn(sc, store)
	scene_despawn(sc, store)
	testing.expect_value(t, len(store.ids), 0)
	scene_deinit(sc, store) // must not panic with "Entity not found!"
}

@(test)
test_main :: proc(t: ^testing.T) {
	store := store_init(5)
	defer store_deinit(store)
	defer free_all(context.temp_allocator)	// Free all temporary allocations done by
																					// store queries

	MovementComponent :: struct {
		x: f32,
		y: f32,
	}
	store_register_component(store, ^MovementComponent)

	VelocityComponent :: struct {
		x: f32,
		y: f32,
	}
	store_register_component(store, ^VelocityComponent)

	entidy_id := store_spawn_with(store, []any{
		new_comp(MovementComponent{0,5}),
		new_comp(VelocityComponent{0,0}),
	})
	testing.expect(t, 0 == entidy_id, fmt.aprintfln("%d != 0\n%#v", entidy_id, store, allocator=context.temp_allocator))
	entidy_id = store_spawn_with(store, []any{
		new_comp(MovementComponent{0,5}),
		new_comp(VelocityComponent{5,4}),
	})
	testing.expect(t, 1 == entidy_id, fmt.aprintfln("%d != 0\n%#v", entidy_id, store, allocator=context.temp_allocator))
	entidy_id = store_spawn_with(store, []any{
		new_comp(MovementComponent{0,5}),
	})
	testing.expect(t, 2 == entidy_id, fmt.aprintfln("%d != 0\n%#v", entidy_id, store, allocator=context.temp_allocator))

	cmps := store_query1(store, ^MovementComponent)

	testing.expect(t, 3 == len(cmps), fmt.aprintfln("%d != 3\n%#v",  len(cmps), store, allocator=context.temp_allocator))

	entities := store_query2(store, ^VelocityComponent, ^MovementComponent)
	testing.expect(t, 2 == len(entities), fmt.aprintfln("%d != 2\n%#v", len(entities), store, allocator=context.temp_allocator))

	ent := entities[1]
	a := ent.ct1.x
	testing.expect_value(t, a, 5)
	b := ent.ct1.y
	testing.expect_value(t, b, 4)
}
