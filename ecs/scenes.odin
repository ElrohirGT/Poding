package main

import "core:fmt"
import "ecs"

block_collision_scene :: proc(cfg: ^GameConfig, store: ^ecs.Store) {
	blocks := []Vec2{
		{150.0, 150.0},
		{250.0, 50.0},
		{350.0, 150.0},
		{250.0, 250.0},
	}

	// Blocks
	for b,idx in blocks {
		ecs.spawn_with(store, []any{
			ecs.new_comp(Transform{
				position = b,
				velocity = Vec2{0,0},
			}),
			ecs.new_comp(RectangleRender{
				dimensions = Vec2{f32(cfg.BlockWidth), f32(cfg.BlockHeight)},
				color = cfg.BlockColors[idx % len(cfg.BlockColors)],
			})
		})
	}

	fmt.printfln("ST1:\n\t%#v", store)

	// Padel
	ecs.spawn_with(store, []any {
		ecs.new_comp(Transform{
			position = Vec2{f32(cfg.ScreenWidth / 2 - cfg.PadelWidth / 2), f32(cfg.ScreenHeight) * 0.9}
			})
	})
	fmt.printfln("ST2:\n%#v", store)

	// Ball
	ecs.spawn_with(store, []any {
		ecs.new_comp(ecs.Tag("Ball")),
		ecs.new_comp(Transform{
			position = Vec2{150.0 + f32(cfg.BlockWidth) + cfg.BallRadius + 50.0, 150+f32(cfg.BlockHeight) / 2},
			velocity = Vec2{0, -75},
		}),
		ecs.new_comp(CircleRender{
			radius = cfg.BallRadius,
			color = cfg.BallColor,
		})
	})
	fmt.printfln("ST3:\n%#v", store)
}


