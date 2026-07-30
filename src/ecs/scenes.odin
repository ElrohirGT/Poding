package main

import "ecs"

block_collision_scene :: proc(cfg: ^GameConfig, store: ^ecs.Store) {
	blocks := []Vec2{
		{150.0, 150.0},
		{250.0, 50.0},
		{350.0, 150.0},
		{250.0, 250.0},
	}

	collider_id: uint = 0

	// Blocks
	for b,idx in blocks {
		collider_id+=1
		dimensions := Vec2{f32(cfg.BlockWidth), f32(cfg.BlockHeight)}
		ecs.spawn_with(store, []any{
			ecs.new_comp(Transform{
				position = b,
				velocity = Vec2{0,0},
			}),
			ecs.new_comp(RectangleRender{
				dimensions = dimensions,
				color = cfg.BlockColors[idx % len(cfg.BlockColors)],
			}),
			ecs.new_comp(SquareCollider{
				id = collider_id,
				tag = "Block",
				static = true,
				dimensions = dimensions,
			})
		})
	}

	// Padel
	collider_id += 1
	ecs.spawn_with(store, []any {
		ecs.new_comp(Transform{
			position = Vec2{f32(cfg.ScreenWidth / 2 - cfg.PadelWidth / 2), f32(cfg.ScreenHeight) * 0.9}
		}),
		ecs.new_comp(RectangleRender{
			dimensions = Vec2{f32(cfg.PadelWidth), f32(cfg.PadelHeight)},
			color = cfg.PadelColor,
		}),
		ecs.new_comp(SquareCollider{
			id = collider_id,
			tag = "Padel",
			static = true,
			dimensions = Vec2{f32(cfg.PadelWidth), f32(cfg.PadelHeight)},
		})
	})

	// Ball
	collider_id+=1
	ecs.spawn_with(store, []any {
		ecs.new_comp(Transform{
			position = Vec2{150.0 + f32(cfg.BlockWidth) + cfg.BallRadius + 50.0, 150+f32(cfg.BlockHeight) / 2},
			velocity = Vec2{70, 45},
		}),
		ecs.new_comp(CircleRender{
			offset = Vec2{cfg.BallRadius, cfg.BallRadius},
			radius = cfg.BallRadius,
			color = cfg.BallColor,
		}),
		ecs.new_comp(SquareCollider{
			id = collider_id,
			tag = "Ball",
			static = false,
			dimensions = Vec2{cfg.BallRadius*2, cfg.BallRadius*2}
		})
	})
}


