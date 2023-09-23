package raven

import "core:bufio"
import "core:bytes"
import "core:fmt"
import "core:io"
import "core:mem"
import "core:os"
import str "core:strings"

RAVEN_STD_BUFSIZE :: 256
RAVEN_TOK_BUFSIZE :: 64
RAVEN_TOK_DELIM :: " \t\r\n\a"

Cli_Input :: struct {
	// TODO: Test using a struct for input mapping?
	line:   string,
	tokens: [dynamic]string,
}

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


// Ideas...
// Could do a stack based read in - pop and work backwards kind of deal? if whitespace etc.?

raven_shell_loop :: proc() {
	line: string
	args: []string
	status: bool = true
	// Step one: Get a basic version that can run simple commands
	// 1.2: - Make sure it respects " and ' 
	// Step two: Improve basic flow
	// Step three: Build out functionality + ability to run arbritary programs
	// 4: History?
	// 5: Respecting Basic Prompts?
	// 6: Check performance?
	for status {
		fmt.printf("> ")
		line = raven_read_line()
		defer delete(line)
		args = raven_split_line(line)
		defer {
			for a in args {
				delete(a)
			}
			delete(args)
		}
		status = raven_exec(args)
	}
	fmt.println("Done")
}

raven_read_line :: proc() -> string {
	buffer: bufio.Reader
	total_buffer: bytes.Buffer
	reader: io.Reader
	stdin_stream := os.stream_from_handle(os.stdin)
	buf := make([]byte, 128)
	defer delete(buf)

	bufio.reader_init(&buffer, stdin_stream)
	pos: int
	n, err := bufio.reader_read(&buffer, buf)

	if err != nil {
		fmt.println("Unable to read from stdin")
		return ""
	}
	bytes.buffer_init(&total_buffer, buf[:n])
	pos = n
	for {
		if total_buffer.buf[pos - 1] != '\n' {
			n, err = bufio.reader_read(&buffer, buf)
			if err != nil {
				fmt.println("Unable to read from stdin")
				return ""
			}
			bytes.buffer_write(&total_buffer, buf[:n])
			pos += n
		} else {
			break
		}
	}

	cutset: []byte = {'\r', '\n'}
	nb := bytes.trim_right(total_buffer.buf[:], cutset)
	bufio.reader_destroy(&buffer)
	// bytes.buffer_destroy(&total_buffer) // The delete of the string handles the buffer inside here :>

	return string(nb)
}

raven_split_line :: proc(line: string) -> []string {
	tokens := make([dynamic]string)

	pre_token: str.Builder
	str.builder_init_none(&pre_token)
	escape_next: bool = false

	token: str.Builder
	str.builder_init_none(&token)

	i: int = 0
	for i < len(line) {
		c := rune(line[i])
		if line[i] == '"' {
			str.write_rune(&token, c)
			i += 1
			for line[i] != '"' && i < len(line) {
				str.write_rune(&token, rune(line[i]))
				i += 1
			}
			if line[i] != '"' {
				fmt.println("raven: Unclosed ', \", ")
				return {}
			}

		}
		if str.is_space(rune(line[i])) {
			append(&tokens, str.clone(str.to_string(token)))
			str.builder_destroy(&token)
			str.builder_init_none(&token)
			i += 1
			continue
		}

		// If nothing else - write the character.
		str.write_rune(&token, c)
		i += 1
	}
	append(&tokens, str.clone(str.to_string(token)))
	str.builder_destroy(&token)

	return tokens[:]
}

_raven_split :: proc(r: rune) -> bool {return str.contains_rune(" ", r)}

raven_delim_split :: proc(r: rune) -> bool {return str.contains_rune(RAVEN_TOK_DELIM, r)}

raven_exec :: proc(args: []string) -> bool {
	if len(args) < 1 {
		return false
	}

	for i in 0 ..< len(args) {
		exec := raven_builtin_fn[args[i]]
		if exec != nil {
			fmt.println("Running builtin")
			exec(args)
			break
		} else {
			fmt.println("Unknown Builtin - Running LAUNCH!")
			fmt.println("Unimplemented")
			break
		}
		if str.compare("run", args[i]) == 0 {
			raven_launch(args)
		}
	}

	return true
}
