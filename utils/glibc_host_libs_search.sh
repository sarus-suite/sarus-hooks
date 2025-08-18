#!/bin/bash

ldconfig_bin="${LDCONFIG_BIN:-/sbin/ldconfig}"

# glibc library names
LIBS=(
    "libSegFault"
    "librt"
    "libnss_dns"
    "libanl"
    "libresolv"
    "libnsl"
    "libBrokenLocale"
    "ld-linux"
    "libnss_hesiod"
    "libutil"
    "libnss_files"
    "libnss_compat"
    "libnss_db"
    "libm"
    "libcrypt"
    "libc"
    "libpthread"
    "libdl"
    "libmvec"
    "libthread_db"
)

# lets check if a lib is the actual elf file
check_lib() {
  local p="$1"
  local final

  # missing entry
  if [[ -z "$p" || "$p" == "NOT FOUND" ]]; then
    echo "MISSING"
    return 1
  fi

  final="$(readlink -f -- "$p" 2>/dev/null || printf '%s' "$p")"

  # binary ELF head check for 0x7F 'E' 'L' 'F'
  if ! head -c4 -- "$final" 2>/dev/null \
      | od -An -t x1 2>/dev/null \
      | awk '{print $1$2$3$4}' \
      | grep -qi '^7f454c46$'; then
    # possibly a linker script... or some other file
    if grep -qE '^(GROUP|INPUT)\s*\(' "$final" 2>/dev/null; then
      echo "LINKER_SCRIPT"
    else
      echo "NOT_ELF"
    fi
    return 1
  fi

  # must be a shared object
  if ! readelf -h -- "$final" 2>/dev/null | grep -q 'Type:[[:space:]]*DYN'; then
    echo "NOT_SHARED_OBJECT"
    return 1
  fi

  # expect SONAME
  if ! readelf -d -- "$final" 2>/dev/null | grep -q 'SONAME'; then
    echo "NO_SONAME"
    return 1
  fi

  # check for some dynamic symbols
  if ! readelf --dyn-syms -W -- "$final" 2>/dev/null \
       | awk 'NR>3{has=1; exit} END{exit !has}'; then
    echo "NO_DYNSYMS"
    return 1
  fi

  # we made it and it looks fine
  echo "OK"
  return 0
}


# cache ldconfig 
ldcache="$("$ldconfig_bin" -p 2>/dev/null || true)"
if [[ -z "$ldcache" ]]; then
	echo "ERROR: failed to run $ldconfig_bin" >&2
	exit 1
fi

# resolve arch for ld-linux
uname_m="$(uname -m 2>/dev/null || echo "")"
case "$uname_m" in
	x86_64)            ld_arch="x86-64"   ;;
	aarch64|arm64)     ld_arch="aarch64"  ;;
esac

for base in "${LIBS[@]}"; do
	path=""

	# special case
	if [[ "$base" == "ld-linux" ]] ; then 
		base="ld-linux-$ld_arch"
	fi

    pattern="^[[:space:]]*${base//\./\\.}\\.so"
    path=$(echo "$ldcache" \
		| grep -m1 -E "$pattern" \
		| awk -F'=> ' 'NF>1{print $2; exit}')

	if [[ -n "$path" ]]; then
		real="$(readlink -f $path 2>/dev/null || echo $path)"
		status="$(check_lib $real)"
		echo "$base: $real [$status]"
	else
		echo "$base: NOT FOUND"
	fi
done

