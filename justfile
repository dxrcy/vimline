SRC   := "src"
ENTRY := SRC + "/main.zig"

run *args:
	@zig run {{ENTRY}} -- {{args}}

