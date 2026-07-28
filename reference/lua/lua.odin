package main

import "core:fmt"
import "core:testing"
import "core:c"
import lua "vendor:lua/5.4"

LUA_SOURCE :: `
message = "find me"
value = 1234
arr = {1,2,3}
`

@(test)
lua_tutorial :: proc(t: ^testing.T) {
    L: ^lua.State = lua.L_newstate()
    defer lua.close(L)

    status: lua.Status = lua.L_loadstring(L, LUA_SOURCE)
    testing.expect(t, status == .OK, "Error loading source")

    call_status: c.int = lua.pcall(L, 0, 0, 0)
    testing.expect(t, lua.Status(call_status) == .OK, "Error running source")

    stack := lua.getglobal(L, "arr") // The stack only has one variable
    testing.expect(t, stack == i32(lua.TTABLE), "Cannot find variable")

		lua.rawgeti(L, -1, 2)
		n := lua.tonumber(L, -1)
		testing.expect(t, n == 2, fmt.aprintf("n == 2 (%f == 2)", n))

    lua.settop(L, 0) // Clear the stack
    testing.expect(t, lua.gettop(L) == 0, "Cannot clear stack")
}
