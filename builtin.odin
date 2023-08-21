package raven

import "core:fmt"
import "core:os"
// import "core:os/os2"
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

// raven_cd :: proc(path: string) -> int {
// 	if len(path) < 1 {
// 		fmt.println("raven: expected filepath to 'cd' into")
// 	} else {
// 		if os2.chdir(path) != nil {
// 			fmt.println("Change Dir seems to have failed x(")
// 			fmt.println(path)
// 		}
// 	}
// 	return 1
// }

raven_builtin_fn: map[string]proc(_: []string) -> bool = {
	"cd"   = raven_cd,
	"ls"   = raven_ls,
	"exit" = raven_exit,
	"help" = raven_help,
}

raven_cd :: proc(args: []string) -> bool {
	err := _raven_cd(args)
	if err != E_NONE {
		// fmt.println("Shell Error: ", err)
	}
	return true
}

raven_ls :: proc(args: []string) -> bool {
	_raven_ls(args)
	return true
	// fmt.println("Listing Directories")
	// cwd := os.get_current_directory()
	// dir, derr := os.open(cwd, os.O_RDONLY)
	// if derr != 0 {return false}
	// defer os.close(dir)
	//
	// f_info, ferr := os.fstat(dir)
	// defer os.file_info_delete(f_info)
	// if ferr != 0 {return false}
	// f_info_arr, _ := os.read_dir(dir, -1) // -1 is the startign max capacity of dynamic array
	//
	// slice.sort_by(f_info_arr, proc(a, b: os.File_Info) -> bool {
	// 	return a.name < b.name
	// })
	// defer {
	// 	for f in f_info_arr {
	// 		os.file_info_delete(f)
	// 	}
	// 	delete(f_info_arr)
	// }
	//
	// for f in f_info_arr {
	// 	fmt.println(f.name)
	// }
	//
	// return true
}

// Lmao even.
raven_help :: proc(args: []string) -> bool {
	fmt.println("Raven shell by Pix")
	fmt.println("Builtins: 'cd', 'ls', 'help', 'exit'")
	return true
}

raven_exit :: proc(args: []string) -> bool {
	_raven_exit(args)
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
// raven_builtins_fn :: proc {
// 	raven_cd,
// 	raven_ls,
// 	raven_exit,
// 	raven_help,
// }
