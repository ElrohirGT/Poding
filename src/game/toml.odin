package main

import "vendor:raylib"
import "toml"

GameConfig :: struct {
	ScreenWidth: i32,
	ScreenHeight: i32,
	FpsCap: i32,

	GameRectangle: [4]i32,

	BackgroundColor: raylib.Color,
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
