# glibc Hook for Sarus-suite

This OCI hook allows the injection of host glibc libraries into containers, replacing older version to ensure ABI compatibility. This is useful when running applications that depend on newer glibc than what is available in the container.

## How It Works

* The Hook enters the container mount namespace
* Compares glibc version (replacing only if the container version is older)
* Checks ABI compatibility via soname matching
* Binds-mount compatible host libraries or adds missing ones to the container filesystem

## Configuration

### Environement Variables

The hook is configured passing the host information via environment variables:

| Variable        | Description                             |
|-----------------|-----------------------------------------|
| `LDD_PATH`      | Path to `ldd` on host                   |
| `LDCONFIG_PATH` | Path to `ldconfig` on host              |
| `READELF_PATH`  | Path to `readelf` on host               |
| `GLIBC_LIBS`    | Colon-separated list of host glibc libs |

### Enabling the Hook

The hook uses an annotation to enable for a container:

~~~
{
    "version": "1.0.0",
    "hook": {
        "path": "/opt/sarus/bin/glibc_hook",
        "env": [
            "LDD_PATH=/usr/bin/ldd",
            "LDCONFIG_PATH=/sbin/ldconfig",
            "READELF_PATH=/usr/bin/readelf",
            "GLIBC_LIBS=/lib64/libSegFault.so:/lib64/librt.so.1:/lib64/libnss_dns.so.2:/lib64/libanl.so.1:/lib64/libresolv.so.2:/lib64/libnsl.so.1:/lib64/libBrokenLocale.so.1:/lib64/ld-linux-x86-64.so.2:/lib64/libnss_hesiod.so.2:/lib64/libutil.so.1:/lib64/libnss_files.so.2:/lib64/libnss_compat.so.2:/lib64/libnss_db.so.2:/lib64/libm.so.6:/lib64/libcrypt.so.1:/lib64/libc.so.6:/lib64/libpthread.so.0:/lib64/libdl.so.2:/lib64/libmvec.so.1:/lib64/libc.so.6:/lib64/libthread_db.so.1"
        ]
    },
    "when": {
        "annotations": {
            "^com.hooks.glibc.enabled$": "^true$"
        }
    },
    "stages": ["createContainer"]
}
~~~

