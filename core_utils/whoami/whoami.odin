package coreutils

import "core:fmt"
import "core:intrinsics"
import "core:os"
import "core:sys/unix"

Uid :: distinct int
Gid :: distinct int

Passwd :: struct {
	pw_name:   string, // Username
	pw_passwd: string, // Hashed passprhase, if shadow database not in use
	pw_uid:    Uid, // User ID
	pw_gid:    Gid, // Group ID
	pw_gecos:  string, // Real Name
	pw_dir:    string, // Home dir
	pw_shell:  string, // Shell program
}

geteuid :: proc() -> (Uid, bool) {
	uid := intrinsics.syscall(unix.SYS_geteuid)
	if int(uid) == -1 do return Uid(-1), false
	return Uid(uid), true
}

getpwuid :: proc(uid: Uid) -> (Passwd, bool) {

	return {}, true
}

whoami :: proc() {
	pw: Passwd
	uid: Uid
	ok: bool


	uid, ok = geteuid()
	fmt.println("User UID:", uid)
	if !ok do os.exit(1)
	pw, ok = getpwuid(uid)
	if !ok {
		fmt.fprintf(os.stderr, "Cannot find name for user ID %v", uid)
		os.exit(1)
	}
	fmt.println(pw.pw_name)
}

main :: proc() {
	whoami()
}
