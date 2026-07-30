package main

import "core:fmt"
import "ecs"
import "vendor:microui"
import "vendor:raylib"

dbg_entities :: proc(ctx: ^microui.Context, store: ^ecs.Store) {
	if (microui.begin_window(ctx, "Debug", microui.Rect{650, 50, 300, 240})) {
		defer microui.end_window(ctx)

		if (microui.header(ctx, "Entities", {.EXPANDED}) == {.ACTIVE}) {
			for cp_id, entities in store {
				if (microui.begin_treenode(ctx, fmt.aprintf("\t%#v", cp_id, allocator=context.temp_allocator), {.CLOSED}) == {.ACTIVE}) {
					defer microui.end_treenode(ctx)

					for cp in entities {
						microui.label(ctx, fmt.aprintf("\t%v", cp, allocator=context.temp_allocator))
					}
				}
			}
		}
	}
}

dbg_collisions :: proc(ctx: ^microui.Context, entities: []struct{ct1: ^SquareCollider, ct2: ^Transform}) {
	non_static := make([dynamic]struct{ct1: ^SquareCollider, ct2: ^Transform}, 0, len(entities))
	for ent1 in entities {
		if !ent1.ct1.static {
			append(&non_static, ent1)
		}
	}

	if microui.begin_window(ctx, "Dynamic entities", microui.Rect{100, 400, 800, 250}) {
		defer microui.end_window(ctx)

		for ent in non_static {
			title := fmt.aprintf("\t%d: %s - %v - %v: %d", ent.ct1.id, ent.ct1.tag, ent.ct2.position, ent.ct1.collision_direction, ent.ct1.collision_with, allocator=context.temp_allocator)
			if microui.begin_treenode(ctx, title, {.EXPANDED}) == {.ACTIVE}{
				defer microui.end_treenode(ctx)

				for other in entities {
					if other.ct1.id == ent.ct1.id { // Avoid self collision
						continue
					}

					opts: microui.Options
					if other.ct1.id == 4 {
						opts = {.EXPANDED}
					}
					subtitle := fmt.aprintf("\t%d: %s - %v", other.ct1.id, other.ct1.tag, other.ct2.position, allocator=context.temp_allocator)
					if microui.begin_treenode(ctx, subtitle, opts ) == {.ACTIVE}{
						defer microui.end_treenode(ctx)
						is_touching_block(ctx, ent, other)
					}
				}
			}
		}
	}
}

draw_debug_circle :: proc(pos: Vec2) {
	color := raylib.PINK
	color[3] = 50
	raylib.DrawCircle(i32(pos.x), i32(pos.y), 5, color)
}
