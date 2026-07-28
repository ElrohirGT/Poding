package main

import "core:math"
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
				id = uint(idx),
				static = true,
				dimensions = dimensions,
			})
		})
	}

	// Padel
	ecs.spawn_with(store, []any {
		ecs.new_comp(Transform{
			position = Vec2{f32(cfg.ScreenWidth / 2 - cfg.PadelWidth / 2), f32(cfg.ScreenHeight) * 0.9}
		}),
		ecs.new_comp(RectangleRender{
			dimensions = Vec2{f32(cfg.PadelWidth), f32(cfg.PadelHeight)},
			color = cfg.PadelColor,
		})
	})

	// Ball
	ecs.spawn_with(store, []any {
		ecs.new_comp(Transform{
			position = Vec2{150.0 + f32(cfg.BlockWidth) + cfg.BallRadius + 50.0, 150+f32(cfg.BlockHeight) / 2},
			velocity = Vec2{0, -75},
		}),
		ecs.new_comp(CircleRender{
			offset = Vec2{math.sin(math.PI / f32(4)) * cfg.BallRadius, -math.cos(math.PI/f32(4))*cfg.BallRadius},
			radius = cfg.BallRadius,
			color = cfg.BallColor,
		}),
		ecs.new_comp(SquareCollider{
			id = 10,
			static = false,
			dimensions = Vec2{cfg.BallRadius*2, cfg.BallRadius*2}
		})
	})
}


