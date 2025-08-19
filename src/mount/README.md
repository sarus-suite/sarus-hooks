# mount Hook for Sarus Suite

A small OCI hook that bind-mounts host files / directories /devices into the container without modifying the container image. 

## How It Works

* Read mount definitions from the configuration
* Perform bind mounts into the bundle before the container process starts

## Configuration

### Environment Variables

The hook is configured passing the host LDCONFIG path via environment variable:

| Variable        | Description                             |
|-----------------|-----------------------------------------|
| `LDCONFIG_PATH` | Path to `ldconfig` on host              |

### Enabling the Hook

When registered, the hook always runs.

~~~
{
  "version": "1.0.0",
  "hook": {
    "path": "/scratch/local/podman-hooks/bin/mount_hook",
    "args": ["mount_hook",
      "--mount=type=bind,src=${HOME},dst=/mnt/hostbind,readonly"
    ],
    "env": [
      "LDCONFIG_PATH=/sbin/ldconfig"
    ]
  },
  "when": {
    "always": true
  },
  "stages": ["createContainer"]
}
~~~
