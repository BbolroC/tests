#!/bin/bash
#
# Copyright (c) 2017-2020 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0
#

set -o errexit
set -o nounset
set -o pipefail

cidir=$(dirname "$0")
tag="${1:-""}"
source /etc/os-release || source /usr/lib/os-release
source "${cidir}/lib.sh"
KATA_BUILD_KERNEL_TYPE="${KATA_BUILD_KERNEL_TYPE:-vanilla}"
KATA_BUILD_QEMU_TYPE="${KATA_BUILD_QEMU_TYPE:-vanilla}"
KATA_HYPERVISOR="${KATA_HYPERVISOR:-qemu}"
experimental_qemu="${experimental_qemu:-false}"
TEE_TYPE="${TEE_TYPE:-}"
arch=$("${cidir}"/kata-arch.sh -d)

if [ -n "${TEE_TYPE}" ]; then
	echo "Install with TEE type: ${TEE_TYPE}"
fi

if [ "${TEE_TYPE:-}" == "tdx" ]; then
	KATA_BUILD_KERNEL_TYPE="${KATA_BUILD_KERNEL_TYPE:-tdx}"
	KATA_BUILD_QEMU_TYPE="${KATA_BUILD_QEMU_TYPE:-tdx}"
fi

if [ "${TEE_TYPE:-}" == "sev" ]; then
	KATA_BUILD_KERNEL_TYPE=sev
fi

if [ "${TEE_TYPE:-}" == "snp" ]; then
	KATA_BUILD_KERNEL_TYPE=snp
	KATA_BUILD_QEMU_TYPE="${KATA_BUILD_QEMU_TYPE:-snp}"
fi

if [ "${KATA_HYPERVISOR:-}" == "dragonball" ]; then
	KATA_BUILD_KERNEL_TYPE=dragonball
fi

echo "Install Kata Containers Image"
echo "rust image is default for Kata 2.0"
"${cidir}/install_kata_image.sh" "${tag}"

echo "Install Kata Containers Kernel"
"${cidir}/install_kata_kernel.sh" -t "${KATA_BUILD_KERNEL_TYPE}"

if [ "${TEE_TYPE:-}" == "se" ]; then
	# Set an environment variable HKD_PATH
	[ -f "${CI_HKD_PATH}" ] || die "Host key document for SE image build not found"

	export HKD_PATH="host-key-document"
	local_hkd_path="${katacontainers_repo_dir}/${HKD_PATH}"
	mkdir -p "${local_hkd_path}"
	cp "${CI_HKD_PATH}" "${local_hkd_path}"

	build_static_artifact_and_install "se-image"
fi

install_qemu(){
	echo "Installing qemu"
	if [ "$experimental_qemu" == "true" ]; then
		echo "Install experimental Qemu"
		"${cidir}/install_qemu_experimental.sh"
	else
		"${cidir}/install_qemu.sh" -t "${KATA_BUILD_QEMU_TYPE}"
	fi
}

echo "Install runtime"
"${cidir}/install_runtime.sh" "${tag}"

case "${KATA_HYPERVISOR}" in
	"cloud-hypervisor")
		"${cidir}/install_cloud_hypervisor.sh"
		echo "Installing virtiofsd"
		"${cidir}/install_virtiofsd.sh"
		if [ "${TEE_TYPE:-}" == "tdx" ]; then
			"${cidir}/install_td_shim.sh"
		fi
		;;
	"firecracker")
		"${cidir}/install_firecracker.sh"
		;;
	"qemu")
		install_qemu
		echo "Installing virtiofsd"
		"${cidir}/install_virtiofsd.sh"
		if [ "${TEE_TYPE}" == "tdx" ]; then
			"${cidir}/install_tdvf.sh"
		elif [ "${TEE_TYPE:-}" == "sev" ] || [ "${TEE_TYPE:-}" == "snp" ]; then
			"${cidir}/install_ovmf_sev.sh"
		fi
		;;
	"dragonball")
		echo "Kata Hypervisor is dragonball"
		;;
	*)
		die "${KATA_HYPERVISOR} not supported for CI install"
		;;
esac

kata-runtime kata-env
echo "Kata config:"
cat $(kata-runtime kata-env  --json | jq .Runtime.Config.Path -r)
