package main

import "core:strings"
import "core:fmt"
import "vendor:raylib"
import lua "vendor:lua/5.4"

GameConfig :: struct {
	ScreenWidth: int,
	ScreenHeight: int,
	FpsCap: int,

	BackgroundColor: raylib.Color,

	BlockWidth: int,
	BlockHeight: int,
	BlockColors: []raylib.Color,

	PadelWidth: int,
	PadelHeight: int,
	PadelColor: raylib.Color,
	PadelVelocity: int,

	BallRadius: int,
	BallColor: raylib.Color,
}

parse_file :: proc(file: string) -> (^GameConfig, string) {
	L: ^lua.State = lua.L_newstate()
	defer lua.close(L)

	res, err := strings.clone_to_cstring(file)
	if err != nil {
		return nil, "Failed to clone file to strings"
	}
	status := lua.L_loadfile(L, res)
	if status != .OK {
		return nil, "Failed to LOAD config source file!"
	}

	call_status := lua.pcall(L, 0,0,0)
	if lua.Status(call_status) != .OK {
		return nil, "Failed to RUN config source file!"
	}

	cfg := new(GameConfig)
	if parse_lua_int(L, &cfg.ScreenWidth, "ScreenWidth") != .OK {
		return cfg, "Failed to parse `ScreenWidth`"
	}
	if parse_lua_int(L, &cfg.ScreenHeight, "ScreenHeight") != .OK {
		return cfg, "Failed to parse `ScreenHeight`"
	}
	if parse_lua_int(L, &cfg.FpsCap, "FpsCap") != .OK {
		return cfg, "Failed to parse `FpsCap`"
	}

	return cfg, ""
}

ParseLuaVarResult :: enum {
	OK,
	FAILED,
}

parse_lua_int :: proc(L: ^lua.State, var: ^int, name: string) -> ParseLuaVarResult {
	cname, err := strings.clone_to_cstring(name)
	if err != nil {
		fmt.printfln("ERROR: Failed to parse %s: failed to clone to cstring", name)
		return .FAILED
	}

	stack := lua.getglobal(L, cname)
	if stack != i32(lua.TNUMBER) {
		fmt.printfln("ERROR: Failed to parse %s: the variable is not of type number!", name)
		return .FAILED
	}

	n := lua.tonumber(L, -1)
	var^ = int(n)
	return .OK
}
