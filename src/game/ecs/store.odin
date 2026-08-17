package ecs

import "core:fmt"
import "core:testing"

EntityId :: int

Store :: map[typeid][dynamic]any

store_init :: proc(init_components: int) -> ^Store {
	st := new(Store)
	return st
}

store_deinit :: proc(st: ^Store) {
	for _, components in st {
		for comp in components {
			if comp != nil {
				inner := (^rawptr)(comp.data)^ // read the pointer stored inside `box` (i.e. `ref`)
				free(inner)                    // free the component payload from new_clone
				free(comp.data)                // free the box itself
			}
		}
		delete(components)
	}
	delete(st^)
	free(st)
}

store_register_component :: proc(st: ^Store, $ComponentId: typeid) {
	entities := [dynamic]any{}
	st[ComponentId] = entities
}

store_spawn_with :: proc(st: ^Store, components: []any) -> EntityId {
	entity_id := 0
	for comp_id, cmps in st {
		if entity_id == 0 {
			entity_id = len(cmps)
		}

		value: any
		for comp in components {
			if comp_id == comp.id {
				value = comp
				break
			}
		}

		collection := st[comp_id]
		append(&collection, value)
		st^[comp_id] = collection
	}

	return entity_id
}

store_remove_entity :: proc(st: ^Store, id: uint) {
	for t_id, &components in st {
		unordered_remove(&components, id)
	}
}

store_query1 :: proc(st: ^Store, $CT1: typeid) -> []CT1 {
	result := make([dynamic]CT1, 0, len(st[CT1]), context.temp_allocator)
	for component_value, idx in st[CT1] {
		if component_value != nil {
			append(&result, component_value.(CT1))
		}
	}
	return result[:]
}

store_query2 :: proc(st: ^Store, $CT1: typeid, $CT2: typeid) -> []struct{ct1: CT1, ct2: CT2} {
	st1, found := st[CT1]
	if !found {
		return nil
	}

	result := make([dynamic]struct{ct1: CT1, ct2: CT2}, 0, len(st[CT1]), context.temp_allocator)
	for cp1, entity_id in st1 {
		if cp1 == nil {
			continue
		}

		st2, found := st[CT2]
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
