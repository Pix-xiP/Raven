package main

import "core:fmt"
import "core:os"
import "core:os/os2"
import "core:sys/unix"
import "core:strings"
import "core:slice"
import _c "core:c"

foreign import libc "system:c"

foreign libc {
	@(link_name = "waitpid")
	_unix_waitpid :: proc(pid: _c.int, status: ^_c.int, opts: _c.int) -> _c.int ---
	@(link_name = "WIFEXITED")
	_WIFEXITED :: proc(status: _c.int) -> _c.int ---
	@(link_name = "WIFSIGNALED")
	_WIFSIGNALED :: proc(status: _c.int) -> _c.int ---
}

WUNTRACED :: 0x01

raven_cd :: proc(path: string) -> int {
	if len(path) < 1 {
		fmt.println("raven: expected filepath to 'cd' into")
	} else {
		if os2.chdir(path) != nil {
			fmt.println("Change Dir seems to have failed x(")
			fmt.println(path)
		}
	}
	return 1
}

raven_ls :: proc(path: string) -> bool {
	fmt.println("Listing Directories")

	// buf := make([dynamic]u8, 4096) // Page Size Standard?
	// #no_bounds_check res := unix.sys_getcwd(&buf[0], uint(len(buf)))
	// if res >= 0 { 	// Meaning no errors, or we found something.
	// This is the current directory
	// vars := strings.string_from_null_terminated_ptr(&buf[0], len(buf))
	// fmt.println(vars)
	// } else {
	//		return false
	// }
	// cwd, err := os2.getwd(context.allocator)
	cwd := os.get_current_directory()
	dir, derr := os.open(cwd, os.O_RDONLY)
	if derr != 0 {return false}
	defer os.close(dir)

	f_info, ferr := os.fstat(dir)
	defer os.file_info_delete(f_info)
	if ferr != 0 {return false}
	f_info_arr, _ := os.read_dir(dir, -1) // -1 is the startign max capacity of dynamic array

	slice.sort_by(f_info_arr, proc(a, b: os.File_Info) -> bool {
		return a.name < b.name
	})
	defer {
		for f in f_info_arr {
			os.file_info_delete(f)
		}
		delete(f_info_arr)
	}

	for f in f_info_arr {
		fmt.println(f.name)
	}


	return true
}

// Lmao even.
raven_help :: proc() -> bool {
	fmt.println("Raven shell by Pix")
	fmt.println("Builtins: 'cd', 'ls', 'help', 'exit'")
	return true
}

raven_exit :: proc() -> bool {
	return false // This will kill cause of exec return, but could probably do a thread mem pass
}

raven_launch :: proc(args: []string) -> bool {
	fmt.println("Attempting to launch:", args)
	status: _c.int
	pid, err := os.fork()
	if err != os.ERROR_NONE {
		fmt.eprintln("ERROR CREATING FORK x(")
	}
	if (pid == 0) {
		// Child Process
		fmt.println("OS Exit as Child")
		if (os.execvp(args[0], args) == -1) {
			fmt.eprintln("Forking process error")
		}
		os.exit(1)
	} else if (pid < 0) {
		fmt.eprintln("Forking error happenend")
	} else {
		// Parent Process
		for _WIFEXITED(status) <= 0 && _WIFSIGNALED(status) <= 0 {
			fmt.println("Looping...")
			wpid := _unix_waitpid(_c.int(pid), &status, WUNTRACED)
			fmt.println("WPID: ", wpid)
		}
	}

	return false
}

/*raven_builtins_str : []string : ["cd", "help", "ls", "exit"]

raven_builtins_fn :: proc {
	raven_cd,
	raven_ls,
	raven_exit,
	raven_help,
}
*/
