package ecs

new_comp :: proc(v: $T) -> any {
	ref := new_clone(v)
	box := new(^T)
	box^ = ref
	return any{data = box, id = typeid_of(^T)}
}
