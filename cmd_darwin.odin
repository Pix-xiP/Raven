package raven
// +darwin

import _c "core:c"
import "core:fmt"
import intr "core:intrinsics"
import "core:strings"
import "core:os"
import "core:slice"

SYS_CHDIR: uintptr : 12


ERANGE: Errno : 34 // Results too large

E_NONE: Errno : 0 // NO ERROR BBY
EPERM: Errno : 1 // Operation not permitted 
ENOENT: Errno : 2 // No such file or directory 
ESRCH: Errno : 3 // No such process 
EINTR: Errno : 4 // Interrupted system call 
EIO: Errno : 5 // Input/output error 
ENXIO: Errno : 6 // Device not configured 
E2BIG: Errno : 7 // Argument list too long 
ENOEXEC: Errno : 8 // Exec format error 
EBADF: Errno : 9 // Bad file descriptor 
ECHILD: Errno : 10 // No child processes 
EDEADLK: Errno : 11 // Resource deadlock avoided 
// 11 was EAGAIN
ENOMEM: Errno : 12 // Cannot allocate memory 
EACCES: Errno : 13 // Permission denied 
EFAULT: Errno : 14 // Bad address 
ENOTBLK: Errno : 15 // Block device required 
EBUSY: Errno : 16 // Device / Resource busy 
EEXIST: Errno : 17 // File exists 
EXDEV: Errno : 18 // Cross-device link 
ENODEV: Errno : 19 // Operation not supported by device 
ENOTDIR: Errno : 20 // Not a directory 
EISDIR: Errno : 21 // Is a directory 
EINVAL: Errno : 22 // Invalid argument 
ENFILE: Errno : 23 // Too many open files in system 
EMFILE: Errno : 24 // Too many open files 
ENOTTY: Errno : 25 // Inappropriate ioctl for device 
ETXTBSY: Errno : 26 // Text file busy 
EFBIG: Errno : 27 // File too large 
ENOSPC: Errno : 28 // No space left on device 
ESPIPE: Errno : 29 // Illegal seek 
EROFS: Errno : 30 // Read-only file system 
EMLINK: Errno : 31 // Too many links 
EPIPE: Errno : 32 // Broken pipe 


// OS_Stat :: struct {
// 	device_id:            i32, // ID of device containing file
// 	mode:                 u16, // Mode of the file
// 	nlink:                u16, // Number of hard links
// 	serial:               u64, // File serial number
// 	uid:                  u32, // User ID of the file's owner
// 	gid:                  u32, // Group ID of the file's group
// 	rdev:                 i32, // Device ID, if device
// 	last_access:          Unix_File_Time, // Time of last access
// 	modified:             Unix_File_Time, // Time of last modification
// 	status_change:        Unix_File_Time, // Time of last status change
// 	created:              Unix_File_Time, // Time of creation
// 	size:                 i64, // Size of the file, in bytes
// 	blocks:               i64, // Number of blocks allocated for the file
// 	block_size:           i32, // Optimal blocksize for I/O
// 	flags:                u32, // User-defined flags for the file
// 	gen_num:              u32, // File generation number ..?
// 	_spare:               i32, // RESERVED
// 	_reserve1, _reserve2: i64, // RESERVED
// }

// mov 2 utils
_get_errno :: proc(res: int) -> Errno {
	if res < 0 && res > -4096 {
		return Errno(-res)
	}
	return 0
}

_raven_cd :: proc(args: []string) -> Errno {
	cstr := strings.clone_to_cstring(args[1], context.temp_allocator)
	val := intr.syscall(uintptr(SYSCALL.chdir), uintptr(rawptr(cstr)))
	if val != 0 {
		if Errno(val) == ENOENT do fmt.printf("No such directory: %v\n", args[1])
		if Errno(val) == EACCES do fmt.printf("Permission Denied\n")
		return Errno(val)
	}
	return E_NONE
}

_raven_exit :: proc(args: []string) -> Errno {
	err := intr.syscall(uintptr(SYSCALL.exit))
	if err != 0 {
		return Errno(err)
	}
	return E_NONE
}

_raven_ls :: proc(args: []string) -> Errno {
	page_size := 4096 // get_page_size() // 4096 probs
	buf := make([dynamic]u8, page_size)
	for {
		cwd := os._unix_getcwd(cstring(raw_data(buf)), _c.size_t(len(buf))) // Figure out thsi
		if cwd != nil {
			// return string(cwd) // Don't return - break and set to var

			dir, derr := os.open(string(cwd), os.O_RDONLY)
			if derr != 0 {return Errno(derr)}
			defer os.close(dir)

			f_info, ferr := os.fstat(dir)
			defer os.file_info_delete(f_info)
			if ferr != 0 {return Errno(ferr)}
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
		}
		if Errno(os.get_last_error()) != ERANGE {
			delete(buf)
			return ERANGE // return ShellError ( ERANGE EQUIV)
		}
		resize(&buf, len(buf) * page_size)
	}
}

DARWIN_MAXPATHLEN :: 1024
DIR :: distinct rawptr // DIR *

// https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/getdirentries.2.html
Dirent :: struct {
	ino:    u64, // Inode number
	off:    u64, // Offset to next Dirent 
	reclen: u16, // length of this dirent 
	namlen: u16, // len of this dirents name? // This might need to be flipped with below
	type:   u8, // File type
	name:   [DARWIN_MAXPATHLEN]byte, // Null terminated filename?
}

// Probably return Errno, string
// _get_cwd :: proc(pt: string, size: i64) {
// 	dp: ^Dirent
// 	dir: DIR
//
//   first: i32
//   ept: ^u8 // Probably a u8 array with multi pointer
//   bpt: ^u8 // as above
//   c: byte
//   ptsize: i32
//   save_errno: i32
//   fd: i32 // File Descriptor?
//   errno: Errno
// 	// dev_t dev;
// 	// ino_t ino;
// 	// struct stat s;
// 	// dev_t root_dev;
// 	// ino_t root_ino;
//
// 	/*
// 	 * If no buffer specified by the user, allocate one as necessary.
// 	 * If a buffer is specified, the size has to be non-zero.  The path
// 	 * is built from the end of the buffer backwards.
// 	 */
//   if len(pt) <= 0 {
//     ptsize = 0
//     if size <= 0 {
//       errno = EINVAL
//       return nil
//       // return (NULL)
//     }
//     if size == 1 {
//       errno = ERANGE
//       return nil
//       // return (NULL)
//     }
//     ept = pt + size // ???
//   } else {
//     pt = make([]u8, size) // This is the path bby
//     ept = pt + ptsize // ???
//   }
//
//   if _get_cwd(pt, ept - pt) == nil {
//
//   }
//
//   if dir != nil ? _fstat(_dirfd(dir), &s) : lstat(".", &s)) {
//
//   }
//
// 	if (__getcwd(pt, ept - pt) == 0) {
// 		if (*pt != '/') {
// 			bpt = pt;
// 			ept = pt + strlen(pt) - 1;
// 			while (bpt < ept) {
// 				c = *bpt;
// 				*bpt++ = *ept;
// 				*ept-- = c;
// 			}
// 		}
// 		return (pt);
// 	}
// 	bpt = ept - 1;
// 	*bpt = '\0';
//
// 	/* Save root values, so know when to stop. */
// 	if (stat("/", &s))
// 		goto err;
// 	root_dev = s.st_dev;
// 	root_ino = s.st_ino;
//
// 	errno = 0;			/* XXX readdir has no error return. */
//
// 	for (first = 1;; first = 0) {
// 		/* Stat the current level. */
// 		if (dir != NULL ? _fstat(_dirfd(dir), &s) : lstat(".", &s))
// 			goto err;
//
// 		/* Save current node values. */
// 		ino = s.st_ino;
// 		dev = s.st_dev;
//
// 		/* Check for reaching root. */
// 		if (root_dev == dev && root_ino == ino) {
// 			*--bpt = '/';
// 			/*
// 			 * It's unclear that it's a requirement to copy the
// 			 * path to the beginning of the buffer, but it's always
// 			 * been that way and stuff would probably break.
// 			 */
// 			bcopy(bpt, pt, ept - bpt);
// 			if (dir)
// 				(void) closedir(dir);
// 			return (pt);
// 		}
//
// 		/* Open and stat parent directory. */
// 		fd = _openat(dir != NULL ? _dirfd(dir) : AT_FDCWD,
// 				"..", O_RDONLY | O_CLOEXEC);
// 		if (fd == -1)
// 			goto err;
// 		if (dir)
// 			(void) closedir(dir);
// 		if (!(dir = fdopendir(fd)) || _fstat(_dirfd(dir), &s)) {
// 			_close(fd);
// 			goto err;
// 		}
//
// 		/*
// 		 * If it's a mount point, have to stat each element because
// 		 * the inode number in the directory is for the entry in the
// 		 * parent directory, not the inode number of the mounted file.
// 		 */
// 		save_errno = 0;
// 		if (s.st_dev == dev) {
// 			for (;;) {
// 				if (!(dp = readdir(dir)))
// 					goto notfound;
// 				if (dp->d_fileno == ino)
// 					break;
// 			}
// 		} else
// 			for (;;) {
// 				if (!(dp = readdir(dir)))
// 					goto notfound;
// 				if (ISDOT(dp))
// 					continue;
//
// 				/* Save the first error for later. */
// 				if (fstatat(_dirfd(dir), dp->d_name, &s,
// 				    AT_SYMLINK_NOFOLLOW)) {
// 					if (!save_errno)
// 						save_errno = errno;
// 					errno = 0;
// 					continue;
// 				}
// 				if (s.st_dev == dev && s.st_ino == ino)
// 					break;
// 			}
//
// 		/*
// 		 * Check for length of the current name, preceding slash,
// 		 * leading slash.
// 		 */
// 		while (bpt - pt < dp->d_namlen + (first ? 1 : 2)) {
// 			size_t len, off;
//
// 			if (!ptsize) {
// 				errno = ERANGE;
// 				goto err;
// 			}
// 			off = bpt - pt;
// 			len = ept - bpt;
// 			if ((pt = reallocf(pt, ptsize *= 2)) == NULL)
// 				goto err;
// 			bpt = pt + off;
// 			ept = pt + ptsize;
// 			bcopy(bpt, ept - len, len);
// 			bpt = ept - len;
// 		}
// 		if (!first)
// 			*--bpt = '/';
// 		bpt -= dp->d_namlen;
// 		bcopy(dp->d_name, bpt, dp->d_namlen);
// 	}
//
// notfound:
// 	/*
// 	 * If readdir set errno, use it, not any saved error; otherwise,
// 	 * didn't find the current directory in its parent directory, set
// 	 * errno to ENOENT.
// 	 */
// 	if (!errno)
// 		errno = save_errno ? save_errno : ENOENT;
// 	/* FALLTHROUGH */
// err:
// 	save_errno = errno;
//
// 	if (ptsize)
// 		free(pt);
// 	if (dir)
// 		(void) closedir(dir);
//
//
//
//
//
//
//
//
// }

// {
// 	fmt.println("Listing Directories")
//
// 	// buf := make([dynamic]u8, 4096) // Page Size Standard?
// 	// #no_bounds_check res := unix.sys_getcwd(&buf[0], uint(len(buf)))
// 	// if res >= 0 { 	// Meaning no errors, or we found something.
// 	// This is the current directory
// 	// vars := strings.string_from_null_terminated_ptr(&buf[0], len(buf))
// 	// fmt.println(vars)
// 	// } else {
// 	//		return false
// 	// }
// 	// cwd, err := os2.getwd(context.allocator)
// 	cwd := os.get_current_directory()
// 	dir, derr := os.open(cwd, os.O_RDONLY)
// 	if derr != 0 {return false}
// 	defer os.close(dir)
//
// 	f_info, ferr := os.fstat(dir)
// 	defer os.file_info_delete(f_info)
// 	if ferr != 0 {return false}
// 	f_info_arr, _ := os.read_dir(dir, -1) // -1 is the startign max capacity of dynamic array
//
// 	slice.sort_by(f_info_arr, proc(a, b: os.File_Info) -> bool {
// 		return a.name < b.name
// 	})
// 	defer {
// 		for f in f_info_arr {
// 			os.file_info_delete(f)
// 		}
// 		delete(f_info_arr)
// 	}
//
// 	for f in f_info_arr {
// 		fmt.println(f.name)
// 	}
// }


SYSCALL :: enum uintptr {
	/* 0 syscall */
	exit      = 1,
	fork      = 2,
	read      = 3,
	write     = 4,
	open      = 5,
	close     = 6,
	wait4     = 7,
	/* 8  old creat */
	link      = 9,
	unlink    = 10,
	/* 11  old execv */
	chdir     = 12,
	fchdir    = 13,
	mknod     = 14,
	chmod     = 15,
	chown     = 16,
	/* 17  old break */
	getfsstat = 18,
	/* 19  old lseek */
	getpid    = 20,
	/* 21  old mount */
	/* 22  old umount */
	setuid    = 23,
	getuid    = 24,
	geteuid   = 25,
	sendfile  = 337,
	stat64    = 338,
	fstat64   = 339,
	lstat64   = 349,
}
