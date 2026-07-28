package main

import "vendor:raylib"
import "toml"

GameConfig :: struct {
	ScreenWidth: i32,
	ScreenHeight: i32,
	FpsCap: i32,

	BackgroundColor: raylib.Color,

	BlockWidth: i32,
	BlockHeight: i32,
	BlockColors: []raylib.Color,

	PadelWidth: i32,
	PadelHeight: i32,
	PadelColor: raylib.Color,
	PadelVelocity: i32,

	BallRadius: i32,
	BallColor: raylib.Color,
}

parse_file :: proc(filename: string) -> ^GameConfig {
	cfg := new(GameConfig)

	table, err := toml.parse_file(filename)
	if toml.print_error(err){
		panic("")
	}

	uerr := toml.unmarshal_table(cfg, table)
	if uerr != .None {
		panic("Failed to marshall game config!")
	}

	return cfg
}
