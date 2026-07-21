package ecs

import "core:fmt"
import "core:strings"
import "core:log"
import "core:testing"

EntityId :: int


Store :: map[typeid][dynamic]any

init_store :: proc(init_components: int) -> ^Store {
	st := new(Store)
	return st
}

deinit_store :: proc(st: ^Store) {
	delete(st^)
	free(st)
}

register_component :: proc(st: ^Store, $ComponentId: typeid) {
	entities := [dynamic]any{}
	st[ComponentId] = entities
}

spawn_with :: proc(st: ^Store, components: []any) -> EntityId {
	entity_id := 0
	for comp in components {
		for comp_id, components in st {
			if entity_id == 0 {
				entity_id = len(components)
			} 
			assert(entity_id == len(components))

			value: any
			if comp_id == comp.id {
				value = comp
			}

			collection, found := st[comp.id]
			if !found {
				collection = make([dynamic]any, len(components), len(components)+1)
			}
			append(&collection, comp)
			st^[comp.id] = collection
		}
	}
	return entity_id
}

query_1 :: proc(st: ^Store, $CT1: typeid) -> []CT1 {
	result := make([dynamic]CT1, 0, len(st[CT1]))
	for component_value, idx in st[CT1] {
		if component_value != nil {
			append(&result, component_value.(CT1))
		}
	}
	return result[:]
}

query_2 :: proc(st: ^Store, $CT1: typeid, $CT2: typeid) -> []struct{ct1: CT1, ct2: CT2} {
	st1, found := st[CT1]
	if !found {
		return []struct{ct1: CT1, ct2: CT2}
	}

	for cp1, entity_id in st1 {

	}
}


@(test)
test_main :: proc(t: ^testing.T) {
	store := init_store(5)
	defer deinit_store(store)

	MovementComponent :: struct {
		x: f32,
		y: f32,
	}

	register_component(store, MovementComponent)
	entidy_id := spawn_with(store, []any{MovementComponent{0,5}})
	entidy_id = spawn_with(store, []any{MovementComponent{0,5}})
	entidy_id = spawn_with(store, []any{MovementComponent{0,5}})

	cmps := query_1(store, MovementComponent)
	defer delete(cmps)

	testing.expect(t, 3 == len(cmps), fmt.aprintfln("%d != 3\n%#v",  len(cmps), store, allocator=context.temp_allocator))
}
