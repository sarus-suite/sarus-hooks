#!/bin/bash

# Load spack environment at terminal startup
cat <<EOF >> /root/.bashrc
. /opt/spack-environment/activate.sh
EOF