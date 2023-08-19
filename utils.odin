package raven

Errno :: distinct i32

ShellError :: enum Errno {
	None    = 0, // SYSCALL?
	Eperm   = 1,
	Enoent  = 2,
	EAccess = 13,
}
