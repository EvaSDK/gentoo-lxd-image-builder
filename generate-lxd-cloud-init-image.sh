#!/bin/bash
#
# Copyright (C) 2018 Gilles Dartiguelongue
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

set -e

echo "Generating LXD image for ${PACKER_BUILD_NAME}"

case ${IMAGE_ARCH} in
	amd64) LXD_ARCH="x86_64";;
	*) LXD_ARCH=${IMAGE_ARCH};;
esac

cd output-${PACKER_BUILD_NAME}

cat > metadata.yaml <<EOF
architecture: ${LXD_ARCH}
creation_date: ${IMAGE_CREATION_TS}
properties:
  description: Gentoo current ${IMAGE_ARCH} (${IMAGE_VARIANT}) (${IMAGE_CREATION_LABEL})
  os: Gentoo
  release: current
  architecture: ${IMAGE_ARCH}
  variant: ${IMAGE_VARIANT}
  serial: ${IMAGE_CREATION_LABEL}
templates:
  /var/lib/cloud/seed/nocloud-net/meta-data:
    when:
      - create
      - copy
    template: cloud-init-meta.tpl
  /var/lib/cloud/seed/nocloud-net/network-config:
    when:
      - create
      - copy
    template: cloud-init-network.tpl
  /var/lib/cloud/seed/nocloud-net/user-data:
    when:
      - create
      - copy
    template: cloud-init-user.tpl
    properties:
      default: |
        #cloud-config
        {}
  /var/lib/cloud/seed/nocloud-net/vendor-data:
    when:
      - create
      - copy
    template: cloud-init-vendor.tpl
    properties:
      default: |
        #cloud-config
        {}
EOF

mkdir templates || true

# /etc/hostname is for systemd systems, need a specific image
# /etc/hosts is managed by cloud-init
# /etc/conf.d/hostname is managed by cloud-init

cat > templates/cloud-init-meta.tpl <<EOF
#cloud-config
instance-id: {{ container.name }}
local-hostname: {{ container.name }}
{{ config_get("user.meta-data", "") }}
EOF

cat > templates/cloud-init-network.tpl <<EOF
{% if config_get("user.network-config", "") == "" %}version: 1
config:
  - type: physical
    name: eth0
    subnets:
      - type: {% if config_get("user.network_mode", "") == "link-local" %}manual{% else %}dhcp{% endif %}
        control: auto{% else %}{{ config_get("user.network-config", "") }}{% endif %}
EOF

cat > templates/cloud-init-user.tpl <<EOF
{{ config_get("user.user-data", properties.default) }}
EOF

cat > templates/cloud-init-vendor.tpl <<EOF
{{ config_get("user.vendor-data", properties.default) }}
EOF

tar xf rootfs.tar.gz
tar -cf - metadata.yaml templates/ rootfs/ | xz -czf -T 0 - > ${PACKER_BUILD_NAME}-${IMAGE_ARCH}-${IMAGE_VARIANT}.tar.xz
# > ${PACKER_BUILD_NAME}-${IMAGE_ARCH}-${IMAGE_VARIANT}.tar

# Clean up intermediate files
rm lxc-config || true
rm metadata.yaml || true
rm -r templates || true
rm -r rootfs || true
