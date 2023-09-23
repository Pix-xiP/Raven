package coreutils 

import _c "core:c"
import "core:fmt"
import "core:os"
import "core:os/os2"
import get "shared:getopts"

PROGRAM_NAME :: "cp"

AUTHOR :: "Pix"

EXIT_SUCCESS :: 0
EXIT_FAILURE :: 1


Dir_Attr :: struct {
	st:           os.OS_Stat,
	restore_mode: bool,
	slash_offset: i64,
	next:         ^Dir_Attr,
}

CHAR_MAX :: 127 // Signed char max.
long_opts :: enum {
	ATTRIBUTES_ONLY_OPTION = CHAR_MAX + 1,
	COPY_CONTENTS_OPTION,
	DEBUG_OPTION,
	NO_PRESERVE_ATTRIBUTES_OPTION,
	PARENTS_OPTION,
	PRESERVE_ATTRIBUTES_OPTION,
	REFLINK_OPTION,
	SPARSE_OPTION,
	STRIP_TRAILING_SLASHES_OPTION,
	UNLINK_DEST_BEFORE_OPENING,
}

// True if kernel is SELinux enabled
selinux_enabled: bool

// If true, the command "cp x/e_file e_dir" uses "e_dir/x/e_file"
// as its destination instead of the usual "e_dir/e_file"
parents_option: bool = false

// Remove any trailing slashes from each SOURCE arguement
remove_trailing_slashes: bool

// "" instead of nullptr
sparse_type_string: []string = {"", "never", "auto", "always"}

spare_types :: enum {
	SPARE_UNUSED,
	SPARSE_NEVER,
	SPARSE_AUTO,
	SPARSE_ALWAYS,
}


// TODO: BUnch of long opts and other stuff need to be implemented from above line
// about 150 - 80 in cp.c 

usage :: proc(status: i32) {

	if status != EXIT_SUCCESS do fmt.printf("Try 'cp --help' for more information")
	else {
		fmt.printf(
			`
Usage: %s [OPTION]... [-T] SOURCE DEST 
   or: %s [OPTION]... SOURCE... DIRECTORY
   or: %s [OPTION]... -t DIRECTORY SOURCE...`, PROGRAM_NAME, PROGRAM_NAME, PROGRAM_NAME
		)
    fmt.printf(`
Copy SOURCE to DEST, or multiple SOURCE(s) to DIRECTORY`
    )
    
    fmt.printf(`
Mandatory arguments to long options are mandatory for short options too.
`)

    fmt.printf(`
  -a, --archive                same as -dR --preserve=all
      --attributes-only        don't copy the file data, just the attributes
      --backup[=CONTROL]       make a backup of each existing destination file
  
  -b                           like --backup but does not accept an arguement
      --copy-contents          copy contents of special files when recursive
  -d                           same as --no-dereference --preserve=lniks
    `)
  fmt.printf(`
      --debug                  explain how a file is copied.  Implies -v
  -f, --force                  if an existing destination file cannot be
                                 opened, remove it and try again (this option
                                 is ignored when the -n option is also used)
  -i, --interactive            prompt before overwrite (overrides a previous -n
                                 option)
  -H                           follow command-line symbolic links in SOURCE
  -l, --link                   hard link files instead of copying
  -L, --dereference            always follow symbolic links in SOURCE
    fputs(_("\
  -n, --no-clobber             do not overwrite an existing file (overrides a
                                 -u or previous -i option). See also --update
  -P, --no-dereference         never follow symbolic links in SOURCE
  -p                           same as --preserve=mode,ownership,timestamps
      --preserve[=ATTR_LIST]   preserve the specified attributes
      --no-preserve=ATTR_LIST  don't preserve the specified attributes
      --parents                use full source file name under DIRECTORY
    fputs(_("\
  -R, -r, --recursive          copy directories recursively
      --reflink[=WHEN]         control clone/CoW copies. See below
      --remove-destination     remove each existing destination file before
                                 attempting to open it (contrast with --force)
      --sparse=WHEN            control creation of sparse files. See below
      --strip-trailing-slashes  remove any trailing slashes from each SOURCE
                                 argument
  -s, --symbolic-link          make symbolic links instead of copying
  -S, --suffix=SUFFIX          override the usual backup suffix
  -t, --target-directory=DIRECTORY  copy all SOURCE arguments into DIRECTORY
  -T, --no-target-directory    treat DEST as a normal file
  --update[=UPDATE]            control which existing files are updated;
                                 UPDATE={all,none,older(default)}.  See below
  -u                           equivalent to --update[=older]
  -v, --verbose                explain what is being done
  -x, --one-file-system        stay on this file system
  -Z                           set SELinux security context of destination
                                 file to default type
      --context[=CTX]          like -Z, or if CTX is specified then set the
                                 SELinux or SMACK security context to CTX
    `)
    fmt.printf(HELP_OPTION_DESC)
    fmt.printf(VERSION_OPTION_DESC)

    // TODO: Print rest of USAGE here when its ready.
	}
}

// Opaque Struct?
Selabel_Handle :: struct {}

Dereference_Symlink :: enum {
  DEREF_UNDEFINED = 1,
  // Copy the symbolic link itself.   -P 
  DEREF_NEVER,
  // If the symbolic link is a command line ar, then copy 
  // its referent. Otherwise copy the symbolic link itself    -H
  DEREF_COMMAND_LINE_ARGUMENTS,
  //Copy the referent of the symbolic link.   -L 
  DEREF_ALWAYS,
}

Sparse_Type :: enum {
  UNUSED,
  // Never create holes in dest:
  NEVER,
  // This is the default: Use a crude (sometimes inaccurate) heurisitc to 
  // determine if SOURCE has holes. If so, try to create holes in DEST.
  AUTO,
  // For every sufficiensy long sequence of bytes in SOURCE, try to create a 
  // corresponding hole in DEST. THere is a performance penalty here because CP 
  // has to search for hole in SRC. BUt if the holes are big enough, the penalty
  // can be offset by the decrease in the amount of data written to the file system.
  ALWAYS,
}

Interactive :: enum {
  ALWAYS_YES = 1,
  ALWAYS_NO, // Skip and fail 
  ALWAYS_SKIP, // Skip and ignore
  ASK_USER,
  UNSPECIFIED
}

Reflink_Type :: enum {
  // Do a standard copy 
  NEVER, 
  // Try a COW copy and fall back to a standard copy; this is default.
  AUTO,
  // Require a COW copy and fail if not available
  ALWAYS,
}

Backup_Type :: enum {

}

// Mode_T -> Usually represented as an int, packed bits - this could be an 
// ideal use case for a integer bitset?


cp_options :: struct {

  backup_type: Backup_Type,
  // How to handle symlinks in the source:
  dereference: Dereference_Symlink,
  // This value is used to determine whether to prompt before removing 
  // each existing destination file. It works differently depending on 
  // whether move_mode is set. - See comments in copy.odin
  interactive: Interactive, 
  // Control creation of sparse files.
  sparse_mode: Sparse_Type,
  // Set the mode of the destination file to exactly this value if SET_MODE is nonzero
  mode: Mode_t,
  // If true, copy all files except (directories and, if not dereferencing them,
  // symbolic links,) as if they were regular files.
  copy_as_regular: bool,
  // If true, remove each existing destination nondirectory before trying to open it.
  unlink_dest_before_opening: bool,
  // If true, first try to open each existing destination non dircetory, then if open 
  // fails unlink and try again. This option must be set for 'cp -f', in case the dest 
  // file exists when the open is attempted. It is irrelevant to 'mv' since any dest 
// is sure to be removed before the open.
  unlink_dest_after_failed_open: bool,
  // If true, create hard links instead of copying files, create destination ddirectories as usual
  hard_link: bool, 
  // If MOVE_MODE, first try to rename, if that fails and NO_COPY, fail instead of copying.
  move_mode, no_copy: bool,
  // If true, install(1) is the caller.
  install_mode: bool,
  // Whether this process has appropriate privileges to chown a file whose owner is 
  // not the effective user ID 
  chown_privileges: bool,
  // Whether this process has appropriate privileges to do the following operations on a 
  // file even when it is owned by some other user: set the file's atime, mtime, mode, or 
  // ACL; remove or rename an entry in the file even though it is a sticky directory, or 
  // to mount on the file.
  owner_privileges: bool,
  // If true, when copying recursively, skip any subdirectories that are on different 
  // file systems from the one we started on.
  one_file_system: bool,
  // If true, attempt to give the copies the original files' permissions, owner, group and ts.
  preserve_ownership, preserve_mode, preserve_timestamps: bool,
  explicit_no_preserve_mode: bool,
  // If non-null, attempt to set specified security context 
  set_security_context: ^Selabel_Handle,
  // Enabled for mv, and for cp by the --preserve=links option. If true, attempt to 
  // preserve in the destination files any logical hard links between the source files. 
  // If used with cp's --no-dereference option, and copying two hard-linked files, the 
  // two corresponding destination files will also be hard linked. If used with cp's 
  // --dereference (-L) option, then, as that option implies, hard links are *not* 
  // preserved.  However, when copying a file F and a symlink S to F, the resulting S 
  // and F in the destination directory will be hard links to the same file (a copy of F).
  preserve_links: bool,
  // Optionally don't copy the data, either with CoW reflink files or explicitly with the 
  // --attributes-only option 
  data_copy_required: bool,
  // If true, and any of the aove (for preserve) file attributes cannot be aplied to a 
  // destination file, treat it as a failure and return nonzero immediately. E.g. for cp -p 
  // this must be true, for mv it must be false.
  require_preserve: bool,
  // If true, attempt to preserve the SELinux security context too. Set this only if the 
  // kernel is SELinux enabled.
  preserve_security_context: bool,
  // Useful only when preserve_context is true. If true, a failed attempt to preserve 
  // file's security context propagates failure "out" to the caller, along with full 
  // diagnostics. If false, a failure to preserve file's security context does not change 
  // the invoking application's exit status, but may output diagnostics. For example, with 
  // 'cp --preserve=context' this flag is "true", while with 'cp --preserve=all' or 'cp -a',
  // it is "false".
  require_preserve_context: bool,
  // If true, attempt to preserve extended attributes using libattr. Ignored if coreutils 
  // are compiled without xattr support.
  preserve_xattr: bool,
  // Useful only when preserve_xattr is true. If true, a failed attempt to preserve 
  // file's extended attributes propagates failure "out" to the caller, along with 
  // full diagnostics. If false, a failure to preserve file's extended attributes does not
  // change the invoking application's exit status, but may output diagnostics.
  // For example, with 'cp --preserve=xattr' this flag is "true", while with 
  // 'cp --preserve=all' or 'cp -a', it is "false".
  require_preserve_xattr: bool,
  // This allows us to output warnings in cases 2 and 4 below,
  //   while being quiet for case 1 (when reduce_diagnostics is true).
  //     1. cp -a                       try to copy xattrs with no errors
  //     2. cp --preserve=all           copy xattrs with all but ENOTSUP warnings
  //     3. cp --preserve=xattr,context copy xattrs with all errors
  //     4. mv                          copy xattrs with all but ENOTSUP warnings
  reduce_diagnostics: bool,
  // If true, copy directories recursively and copy special files as themselves rather 
  // than copying their contents.
  recursive: bool,
  // If true, set file mode to value of MODE.  Otherwise, set it based on current 
  // umask modified by UMASK_KILL.
  set_mode: bool,
  //If true, create symbolic links instead of copying files. Create destination 
  // directories as usual
  symbolic_link: bool,
  // If true, do not copy a nondirectory that has an existing destination with the
  // same or newer modification time.
  update: bool,
  // If true, display the names of the files before copying them.
  verbose: bool,
  // If true, display details of how files were copied.
  debug: bool,
  // If true, stdin is a tty.
  stdin_tty: bool,
  // If true, open a dangling destination symlink when not in move_mode. Otherwise, 
  // copy_reg gives a diagnostic (it refuses to write through such a symlink) and 
  // returns false.
  open_dangling_dest_symlink: bool,
  // If true, this is the last filed to be copied.  mv uses this to avoid some 
  // unnecessary work.
  last_file: bool,
  // Zero if the source has already been renamed to the destination; a positive errno 
  // number if this failed with the given errno; -1 if no attempt has been made to rename. 
  // Always -1, except for mv.
  rename_errno: int,
  // Control creation of COW files.
  reflink_mode: Reflink_Type,

  dest_info: ^Hash_Table,
  src_info: ^Hash_Table,
  
}

Hash_Table :: struct {} // TODO:

cp_option_init :: proc(x: ^cp_options) {
  x.copy_as_regular = true 
  x.dereference = .DEREF_UNDEFINED
  x.unlink_dest_before_opening = false 
  x.unlink_dest_after_failed_open = false
  x.hard_link = false
  x.interactive = .UNSPECIFIED
  x.move_mode = false
  x.install_mode = false 
  x.one_file_system = false 
  x.reflink_mode = .AUTO
  x.preserve_ownership = false 
  x.preserve_links = false;
  x.preserve_mode = false;
  x.preserve_timestamps = false;
  x.explicit_no_preserve_mode = false;
  x.preserve_security_context = false; // -a or --preserve=context
  x.require_preserve_context = false;  // --preserve=context
  x.set_security_context = nil
  x.preserve_xattr = false;
  x.reduce_diagnostics = false;
  x.require_preserve_xattr = false;

  x.data_copy_required = true;
  x.require_preserve = false;
  x.recursive = false;
  x.sparse_mode = .AUTO;
  x.symbolic_link = false;
  x.set_mode = false;
  x.mode = 0;

  x.stdin_tty = false; // Not used 
  x.update = false;
  x.verbose = false;
  x.open_dangling_dest_symlink = false
  x.dest_info = nil
  x.src_info = nil;
}


cp :: proc(args: []string) {

  make_backups: bool = false 

  x: cp_options

  cp_option_init(&x)
  opts := get.init_opts()
  { // Add arguments // Long opts here.
    using get.optarg_opt 
  
  }

  // get.getopt_long(args, &opts)
  // for opt in opts.opts {
  //   switch opt.name {
  //   case "a":
  //   case:
  //     fmt.println("Oh know!")
  //   }
  // }

   

  // Allocate space for remembering copied and created files.
  // cp_hash_init()
  //
  // // Begin Copy:
  // ok := do_copy(argc - optind, argv + optind, target_directory, no_target_directory, &x)
  // get.deinit_opts(&opts)
  // os.exit(ok ? 0 : 1)
}
