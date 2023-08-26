package raven

import "core:fmt"
import "core:os"
// import "core:os/os2"
import "core:sys/unix"
import "core:strings"
import "core:slice"
import _c "core:c"


// This for launch - should move to LIBC using systems IE darwin/linux
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
	"echo" = raven_echo,
	// "."     = raven_dotcmd,
	// "eval"  = raven_eval,
	// "false" = raven_false,
	// "set"   = raven_set,
}


// breakcmd  -s break -s continue
// cdcmd   -u cd chdir
// commandcmd  -u command
// dotcmd    -s .
//   echocmd   echo
// evalcmd   -ns eval
// execcmd   -s exec
// exitcmd   -s exit
// exportcmd -as export -as readonly
// falsecmd  -u false
// getoptscmd  -u getopts
// hashcmd   -u hash
// jobscmd   -u jobs
// localcmd  -as local
// printfcmd printf
// pwdcmd    -u pwd
// readcmd   -u read
// returncmd -s return
// setcmd    -s set
// shiftcmd  -s shift
// timescmd  -s times
// trapcmd   -s trap
// truecmd   -s : -u true
// typecmd   -u type
// umaskcmd  -u umask
// unaliascmd  -u unalias
// unsetcmd  -s unset
// waitcmd   -u wait
// aliascmd  -au alias
// #ifdef HAVE_GETRLIMIT
// ulimitcmd -u ulimit
// #endif
//   testcmd   test [
//   killcmd   -u kill

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

raven_echo :: proc(args: []string) -> bool {
	_raven_echo(args)
	return true
}

raven_launch :: proc(args: []string) -> bool {
	return true
	// fmt.println("Attempting to launch:", args)
	// status: _c.int
	// pid, err := os.fork()
	// if err != os.ERROR_NONE {
	// 	fmt.eprintln("ERROR CREATING FORK x(")
	// }
	// if (pid == 0) {
	// 	// Child Process
	// 	fmt.println("OS Exit as Child")
	// 	if (os.execvp(args[0], args) == -1) {
	// 		fmt.eprintln("Forking process error")
	// 	}
	// 	os.exit(1)
	// } else if (pid < 0) {
	// 	fmt.eprintln("Forking error happenend")
	// } else {
	// 	// Parent Process
	// 	for _WIFEXITED(status) <= 0 && _WIFSIGNALED(status) <= 0 {
	// 		fmt.println("Looping...")
	// 		wpid := _unix_waitpid(_c.int(pid), &status, WUNTRACED)
	// 		fmt.println("WPID: ", wpid)
	// 	}
	// }
	//
	// return false
}
