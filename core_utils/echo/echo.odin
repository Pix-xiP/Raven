package coreutils

import "core:fmt"
import "core:os"
import sv "../system_vars"
import str "core:strings"

PROGRAM_NAME :: "echo"
PROGRAM_VERSION :: "0.1.0"
EXIT_SUCCESS :: 0


usage :: proc(status: int) {
	if status != EXIT_SUCCESS {
		fmt.fprintf(os.stderr, "Try :%s --help for more information\n", PROGRAM_NAME)
	} else {
		fmt.printf(
			`
Usage: %s [SHORT-OPTION]... [STRING]...
   or: %s LONG_OPTION`,
			PROGRAM_NAME,
			PROGRAM_NAME,
		)
		fmt.printf(
			`
Echo the STRING(s) to standard output.

  -n          do not output the trailing newline
    `,
		)
		fmt.printf(
			`
  -e          enable interpretation of backstlash escapes (default)
  -E          diseable interpretation of backslash escapes
  `,
		)
		fmt.printf("%s\n", sv.HELP_OPTION_DESC)
		fmt.printf("%s\n", sv.VERSION_OPTION_DESC)
		fmt.printf(`
By default the following sequences are recognised:
`)
		fmt.printf(
			`
  \\      backslash
  \a      alert (BEL)
  \b      backspace
  \c      produce no further output
  \e      escape 
  \f      form feed
  \n      new line
  \r      carriage return
  \t      horizontal tab
  \v      vertical tab
  \0NNN   byte with octal value NNN (1 to 3 digits)
  \xHH    byte with hexadecimal value HH (1 to 2 digits)
`,
		)
		fmt.printf(sv.USAGE_BUILTIN_WARNING, PROGRAM_NAME)
	}
}

show_version :: proc(status: int) {
	fmt.printf(`
"%s" Version: %s 
Written in Odin by Pix
  `, PROGRAM_NAME, PROGRAM_VERSION)

	os.exit(status)
}

// Converts hex char to int
hextobin :: proc(c: rune) -> int {
	switch (c) {
	case 'a', 'A':
		return 10
	case 'b', 'B':
		return 11
	case 'c', 'C':
		return 12
	case 'd', 'D':
		return 13
	case 'e', 'E':
		return 14
	case 'f', 'F':
		return 15
	case:
		return int(c - '0')
	}
}

echo :: proc() {
	display_return: bool = true
	argc := len(os.args)
	argv := os.args[1:]
	just_echo: bool = false
	when ODIN_DEBUG {
		fmt.println(os.args)
		fmt.println(os.args[1:])
	}
	// Check for quick kills
	if argc == 2 {
		if str.contains(argv[0], "--help") do usage(EXIT_SUCCESS)
		if str.contains(argv[0], "--version") do show_version(EXIT_SUCCESS)
	}

	/* If it appears that we are handling options, then make sure that
   * all of the options specified are actually valid.  Otherwise, the
   * string should just be echoed.  */
	for arg in argv {
		if arg[0] != '-' do break
		if str.contains(arg, "-e") || str.contains(arg, "-E") do just_echo = true
		if just_echo do break
		if str.contains(arg, "-n") do display_return = false
	}

	for arg in argv {
		fmt.printf("%s", arg)
		fmt.printf(" ")
	}
	if display_return do fmt.printf("\n")
}
// This is the v9 stuff.. Maybe a future TODO
// sb = str.builder_make()
// do_escape: bool = false
// for arg in argv {
// 	for c, i in arg {
// 		fmt.println(c, i)
// 		switch c {
// 		case '\a':
// 			str.write_rune(&sb, '\a')
// 		case '\b':
// 			str.write_rune(&sb, '\b')
// 		case '\n':
// 			fmt.println("NEWLINE")
// 			str.write_rune(&sb, c)
//
// 		}
// 		if do_escape {
// 			do_escape = false
// 			switch (c) {
// 			case 'a':
// 				fmt.println("A")
// 			case 'n':
// 				fmt.println("Found new line")
// 				str.write_rune(&sb, '\n')
// 			case:
// 				str.write_encoded_rune(&sb, c, false)
// 			}
//
// 		} else if c == '\\' && len(arg) > i + 1 {
// 			fmt.println("Found escaped character!")
// 			do_escape = true // If its escaped, set true
// 			continue // Now jump to the next character and switch case
// 		} else {
// 			str.write_encoded_rune(&sb, c, false)
// 		}
// 	}
// 	str.write_encoded_rune(&sb, ' ', false)
// }
// }

main :: proc() {
	echo()
}
