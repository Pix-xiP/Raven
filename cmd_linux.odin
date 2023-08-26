package raven
// +linux

import "core:os"
import "core:fmt"
import "core:os/os2"
import "core:sys/unix"
import intr "core:intrinsics"
import "core:slice"
import str "core:strings"
import uni "core:unicode"
import "core:strconv"


E_NONE: Errno : 0 // NO ERROR BBY
EPERM: Errno : 1
ENOENT: Errno : 2
EINVAL: Errno : 22

// Change the current working directory
_raven_cd :: proc(args: []string) -> Errno {
	if len(args) < 1 {
		fmt.println("raven: expected filepath to 'cd' into")
		return EINVAL
	} else {
		if os2.chdir(args[1]) != nil {
			fmt.println("Change Dir seems to have failed x(")
			fmt.println(args[1])
		}
	}
	return E_NONE
}

// List the current directory
//
// TODO: Print out Perms, user, size and last modified.
// │ r-rwxr-xr-x  1 pix  pix  609K Aug 24 23:16 Raven
// │  -rw-r--r--  1 pix  pix   136 Aug 21 22:43 utils.odin
_raven_ls :: proc(args: []string) -> Errno {
	d: os.Handle
	derr: os.Errno
	path: string
	defer delete(path)

	if len(args) == 1 {
		path = os.get_current_directory()
		d, derr = os.open(path, os.O_RDONLY)
	} else {
		path, derr = os.absolute_path_from_relative(args[1])
		d, derr = os.open(args[1], os.O_RDONLY)

	}

	if derr != 0 {
		fmt.eprintln("DERROR!")
		return Errno(derr)
	}

	defer os.close(d)

	fi, ferr := os.fstat(d)
	if ferr != 0 {
		fmt.eprintln("FERROR")
		return Errno(derr)
	}
	if !fi.is_dir {
		return E_NONE // Need to LS a dir for more.
	}
	defer os.file_info_delete(fi)

	// Have handle can now use dir_linux?
	files, fer := os.read_dir(d, -1)
	fmt.println("Directory:", path)
	for fi in files {
		fmt.println("|--", fi.name)
	}
	defer {
		for fi in files {
			os.file_info_delete(fi)
		}
		delete(files)
	}

	return E_NONE
}

NSIG :: 64

signals :: enum int {
	NONE    = 0,
	SIGHUP  = 1, /* hangup */
	SIGINT  = 2, /* interrupt */
	SIGQUIT = 3, /* quit */
	SIGILL  = 4, /* illegal instruction (not reset when caught) */
	SIGTRAP = 5, /* trace trap (not reset when caught) */
	SIGABRT = 6, /* abort() */
	SIGIOT  = SIGABRT, /* compatibility */
	SIGEMT  = 7, /* EMT instruction */
	SIGFPE  = 8, /* floating point exception */
	SIGKILL = 9, /* kill (cannot be caught or ignored) */
	SIGBUS  = 10, /* bus error */
	SIGSEGV = 11, /* segmentation violation */
	SIGSYS  = 12, /* bad argument to system call */
	SIGPIPE = 13, /* write on a pipe with no one to read it */
	SIGALRM = 14, /* alarm clock */
	SIGTERM = 15, /* software termination signal from kill */
}

// raven_builtin_fn: map[string]proc(_: []string) -> bool = {
___signal_names: map[string]signals = {
	"SIGHUP"  = signals.SIGHUP,
	"SIGINT"  = signals.SIGINT,
	"SIGQUIT" = signals.SIGQUIT,
	"SIGILL"  = signals.SIGILL,
	"SIGTRAP" = signals.SIGTRAP,
	"SIGABRT" = signals.SIGABRT,
	"SIGIOT"  = signals.SIGABRT,
	"SIGEMT"  = signals.SIGEMT,
	"SIGFPE"  = signals.SIGFPE,
	"SIGKILL" = signals.SIGKILL,
	"SIGBUS"  = signals.SIGBUS,
	"SIGSEGV" = signals.SIGSEGV,
	"SIGSYS"  = signals.SIGSYS,
	"SIGPIPE" = signals.SIGPIPE,
	"SIGALRM" = signals.SIGALRM,
	"SIGTERM" = signals.SIGTERM,
}

signal_names: map[int]string = {
	1  = "SIGHUP",
	2  = "SIGINT",
	3  = "SIGQUIT",
	4  = "SIGILL",
	5  = "SIGTRAP",
	6  = "SIGABRT",
	7  = "SIGEMT",
	8  = "SIGFPE",
	9  = "SIGKILL",
	10 = "SIGBUS",
	11 = "SIGSEGV",
	12 = "SIGSYS",
	13 = "SIGPIPE",
	14 = "SIGALRM",
	15 = "SIGTERM",
}

strcasecmp :: proc(s1: string, s2: string) -> bool {
	l1 := str.to_lower(s1)
	l2 := str.to_lower(s2)
	defer delete(l1)
	defer delete(l2)
	if str.compare(l1, l2) == 0 do return true
	return false
}
// TODO: Kill needs to be fnished but I am tride.
decode_signum :: proc(sigstr: string) -> int {
	signo: int = -1
	if uni.is_digit(rune(sigstr[0])) {
		signo = strconv.atoi(sigstr)
		if signo >= NSIG do signo = -1
	}
	return signo
}

decode_signal :: proc(sig: string, minsig: int) -> int {
	signo: int

	signo = decode_signum(sig)
	if signo >= 0 do return signo
	for i in minsig ..< NSIG {
		signo = i

		if strcasecmp(sig, signal_names[signo]) == false do return signo

	}

	return -1
}

_raven_kill :: proc(args: []string) -> Errno {
	if len(args) <= 1 {
		fmt.printf(
			"Usage: kill [-s sigspec | -signum | sigspec] [pid | job]... or\nkill -l [exitstatus]\n",
		)
		return EINVAL
	}

	idx: i16 = 1
	signo: int = -1
	if args[idx][0] == '-' {
		signo = decode_signal(args[idx], 1)
		if signo < 0 {
			fmt.println("nextopt here")
		}
	}

	return E_NONE
}

_raven_echo :: proc(args: []string) -> Errno {
	fmt.println(args) // TODO: Lmao.. not like this

	return E_NONE
}

// Quit the shell
_raven_exit :: proc(args: []string) -> Errno {
	err := intr.syscall(unix.SYS_exit)
	if err != 0 {
		return Errno(err)
	}
	return E_NONE
}
