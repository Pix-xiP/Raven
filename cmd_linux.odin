package raven
// +linux


_raven_cd :: proc(args: []string) -> Errno {
	if len(path) < 1 {
		fmt.println("raven: expected filepath to 'cd' into")
		return EINVAL
	} else {
		if os2.chdir(path) != nil {
			fmt.println("Change Dir seems to have failed x(")
			fmt.println(path)
		}
	}
	return E_NONE
}
