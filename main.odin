package main

import "core:fmt"
import "core:mem"
import "core:os"
import str "core:strings"

RAVEN_STD_BUFSIZE :: 256
RAVEN_TOK_BUFSIZE :: 64
RAVEN_TOK_DELIM :: " \t\r\n\a"

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	// Starting shell forever loop here.
	raven_shell_loop()
}


raven_shell_loop :: proc() {
	line: string
	args: []string
	status: bool = true

	for status {
		fmt.printf("> ")
		line = raven_read_line()
		args = raven_split_line(line)
		status = raven_exec(args)
	}
}

raven_read_line :: proc() -> string {
	// TODO: Make this realloc or something on big big read
	// May have to write a os.read myself?
	buf := make([]byte, 256)
	n, err := os.read(os.stdin, buf[:])
	if err < 0 {
		fmt.printf("INVALID READ LINE\n")
		return ""
	}

	s := str.clone_from(buf)
	fmt.println("You typed: ", s)
	delete(buf)
	return s
}

raven_split_line :: proc(line: string) -> []string {
	tokens, err := str.fields_proc(line, raven_delim_split)
	if err != nil {
		panic("Seem to have goofed here - STR FIELDS PROC")
	}

	return tokens
}

raven_delim_split :: proc(r: rune) -> bool {return str.contains_rune(RAVEN_TOK_DELIM, r)}

raven_exec :: proc(args: []string) -> bool {
	if len(args) < 1 {
		return false
	}

	for i in 0 ..< len(args) {
		if str.compare("cd", args[i]) == 0 {
			if i + 1 < len(args) do raven_cd(args[i + 1])
		}
		if str.compare("ls", args[i]) == 0 {
			raven_ls(args[i])
		}
		if str.compare("help", args[i]) == 0 {
			raven_help()
		}
		if str.compare("exit", args[i]) == 0 {
			raven_exit()
			return false
		}
		if str.compare("run", args[i]) == 0 {
			raven_launch(args)
		}
	}
	return true
}
