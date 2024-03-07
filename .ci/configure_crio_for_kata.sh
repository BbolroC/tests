#!/bin/bash
#
# Copyright (c) 2017-2018 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0
#

set -o errexit
set -o nounset
set -o pipefail

source /etc/os-release || source /usr/lib/os-release

PREFIX="${PREFIX:-/opt/kata}"
crio_config_dir="/etc/crio/crio.conf.d"

echo "Configure runtimes map for RuntimeClass feature with drop-in configs"

sudo tee "$crio_config_dir/00-default-capabilities" > /dev/null <<EOF
[crio]
storage_option = [
    "overlay.skip_mount_home=true",
]
[crio.runtime]
default_capabilities = [
       "CHOWN",
       "DAC_OVERRIDE",
       "FSETID",
       "FOWNER",
       "SETGID",
       "SETUID",
       "SETPCAP",
       "NET_BIND_SERVICE",
       "KILL",
       "SYS_CHROOT",
]
EOF

sudo tee "$crio_config_dir/99-runtimes" > /dev/null <<EOF
[crio.runtime.runtimes.kata]
runtime_path = "/usr/local/bin/containerd-shim-kata-v2"
runtime_root = "/run/vc"
runtime_type = "vm"
runtime_config_path = "${PREFIX}/share/defaults/kata-containers/configuration.toml"
privileged_without_host_devices = true

[crio.runtime.runtimes.runc]
runtime_path = "/usr/local/bin/crio-runc"
runtime_type = "oci"
runtime_root = "/run/runc"
EOF
