#!/bin/sh
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

build() {
	for idx in $(seq 0 $(jq 'length - 1' < variants.json))
	do
		if [ -n "$1" -a "$idx" != "$1" ]
		then
			echo "Skipping record $idx"
			continue
		fi
		echo "Processing record $idx"
		arch=$(jq -r ".[$idx].arch" < variants.json)
		variant=$(jq -r ".[$idx].variant" < variants.json)

		ret=$(lxc image ls --format=json |\
			jq "any ( .[] | .properties |\
				select(.architecture == \"${arch}\" and .variant == \"${variant}\") |\
					.serial ; startswith(\"$(date +%Y%m%d)\") \
					)")
		if [ "${ret}" == "true" ]
		then
			echo "Image for ${arch}/${variant} already generated today, skipping."
			continue
		fi

		echo "Building ${arch}/${variant}..."
		LC_ALL=en_US.utf8 packer build -var arch=${arch} -var variant=${variant} gentoo-lxc-build-cloud-init.json

		aliases=$(jq -r '.['$idx'].aliases | map("--alias " + .) | join(" ")' < variants.json)
		lxc image import ${aliases} ./output-gentoo/gentoo-${arch}-${variant}.tar.xz
	done
}

list() {
	for idx in $(seq 0 $(jq 'length - 1' < variants.json))
	do
		arch=$(jq -r ".[$idx].arch" < variants.json)
		variant=$(jq -r ".[$idx].variant" < variants.json)
		echo "$idx - $arch - $variant"
	done
}

case $1 in
	build) shift; build $@ ;;
	list) list;;
esac
