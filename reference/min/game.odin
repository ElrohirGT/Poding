package main

import "core:fmt"
import "core:strings"
import "vendor:raylib"
import lua "vendor:lua/5.4"


main :: proc() {
	cfg, err := parse_file("cfg.lua")
	if err != "" {
		fmt.printfln("ERROR: %s", err)
		return
	}
	fmt.printfln("CFG: %#v", cfg)
}

GameConfig :: struct {
	BackgroundColor: raylib.Color,
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
	if parse_lua_raylib_color(L, &cfg.BackgroundColor, "BackgroundColor") != .OK {
		return cfg, "Failed to parse `BackgroundColor`"
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

parse_lua_raylib_color :: proc(L: ^lua.State, var: ^raylib.Color, name: string) -> ParseLuaVarResult {
	cname, err := strings.clone_to_cstring(name)
	if err != nil {
		fmt.printfln("ERROR: Failed to parse %s: failed to clone to cstring", name)
		return .FAILED
	}

	stack := lua.getglobal(L, cname)
	if stack != i32(lua.TTABLE) {
		fmt.printfln("ERROR: Failed to parse %s: the variable is not of type table!", name)
		return .FAILED
	}

	status := ParseLuaVarResult.OK
	r,g,b,a: u8
	lua.rawgeti(L, -1, 1)
	r, status = lua_process_number_to_byte(lua.tonumber(L, -1))
	if status != .OK {
		fmt.printfln("ERROR: Faield to parse `r` for `%s`", name)
		return status
	}

	lua.rawgeti(L, -1, 2)
	g, status = lua_process_number_to_byte(lua.tonumber(L, -1))
	if status != .OK {
		fmt.printfln("ERROR: Faield to parse `g` for `%s`", name)
		return status
	}

	lua.rawgeti(L, -1, 3)
	b, status = lua_process_number_to_byte(lua.tonumber(L, -1))
	if status != .OK {
		fmt.printfln("ERROR: Faield to parse `b` for `%s`", name)
		return status
	}

	lua.rawgeti(L, -1, 4)
	a, status = lua_process_number_to_byte(lua.tonumber(L, -1))
	if status != .OK {
		fmt.printfln("ERROR: Faield to parse `a` for `%s`", name)
		return status
	}

	var^ = raylib.Color{r,g,b,a}
	return status
}

lua_process_number_to_byte :: proc(n: lua.Number) -> (u8, ParseLuaVarResult) {
	if n < 0 {
		fmt.printfln("ERROR: converting lua number to byte, %d is less than 0!", n)
		return 0, .FAILED
	}

	if n > 255 {
		fmt.printfln("ERROR: converting lua number to byte, %d is greater thatn 255!", n)
		return 0, .FAILED
	}

	return cast(u8)n, .OK
}
