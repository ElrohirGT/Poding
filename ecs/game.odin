package main

import "ecs"

main :: proc() {
	store := ecs.init_store(5)
	ecs.register_component(store, "position")
}
