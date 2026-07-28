package ecs

new_comp :: proc(v: $T) -> any {
	ref := new_clone(v)
	box := new(^T)
	box^ = ref
	return any{data = box, id = typeid_of(^T)}
}

q2_type :: proc($CT1: typeid, $CT2: typeid) -> struct {cp1: CT1, cp2: CT2} {
	return struct{cp1: CT1, cp2: CT2}
}
