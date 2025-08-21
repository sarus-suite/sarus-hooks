# ldcache Hook for Sarus Suite

During the creation of a container (createContainer stage), this hook enters the container rootfs and runs 'ldconfig -v .' so the container on-disk cache ('/etc/ld.so.cache') is refreshed using the libraries already installed in the image. This hook is minimal and safe to operate: no extra mounts or edits beyond the normal operation of 'ldconfig'.

