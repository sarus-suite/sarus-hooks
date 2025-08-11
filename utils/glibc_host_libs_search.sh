#!/bin/bash

# glibc library names
LIBS=(
    "libSegFault"
    "librt"
    "libnss_dns"
    "libanl"
    "libresolv"
    "libnsl"
    "libBrokenLocale"
    "ld-linux-x86-64"
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

# directories to search
SEARCH_DIRS=("/lib64" "/lib" "/usr/lib" "/usr/lib64")

echo "Library locations found:"
echo "========================"

for lib in "${LIBS[@]}"; do
    found=false
    for dir in "${SEARCH_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            if [ "$lib" = "ld-linux-x86-64" ]; then
				# Special case: ld-linux-x86-64 is the dynamic linker
                result=$(find "$dir" -name "${lib}.so*" -maxdepth 1 2>/dev/null | head -1)
            else
                # For most libraries, look for exact .so file
                result=$(find "$dir" -name "${lib}.so" -maxdepth 1 2>/dev/null | head -1)

                # If no match, try to find the canonical versioned file
                if [ -z "$result" ]; then
                    # This will get files like libc.so.6, libm.so.6, etc.
                    result=$(find "$dir" -type f -name "${lib}.so.[0-9]*" -maxdepth 1 2>/dev/null | head -1)
                fi
            fi

            # Resolve symlinks to get the actual file path
            if [ -n "$result" ]; then
                resolved_path=$(readlink -f "$result" 2>/dev/null)
                if [ -n "$resolved_path" ] && [ -f "$resolved_path" ]; then
                    echo "$lib: $resolved_path"
                else
                    echo "$lib: $result"
                fi
                found=true
                break
            fi
        fi
    done

    if [ "$found" = false ]; then
        echo "$lib: NOT FOUND"
    fi
done
