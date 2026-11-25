package ecs

new_comp :: proc(v: $T) -> any {
	a, _ := new_comp_ref(v)
	return a
}

// Like new_comp, but also returns the component pointer so scene builders can
// wire up links (e.g. `parent`) before the entity is spawned.
new_comp_ref :: proc(v: $T) -> (any, ^T) {
	ref := new_clone(v)
	box := new(^T)
	box^ = ref
	return any{data = box, id = typeid_of(^T)}, ref
}

// Frees one boxed component created by new_comp / new_comp_ref.
@(private)
comp_free :: proc(comp: any) {
	if comp == nil {
		return
	}
	inner := (^rawptr)(comp.data)^ // pointer stored inside the box
	free(inner)                    // the component payload
	free(comp.data)                // the box itself
}
