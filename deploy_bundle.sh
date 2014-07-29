#!/bin/sh
#
# deploy_bundle.sh
#
# Copyright (C) 2013-2014 Florian Zwoch <fzwoch@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#

if [ $# -lt 2 ]; then
	echo "usage: $0 <Bundle.app> <Bundle.app/Contents/MacOS/application> [..]"
	exit 1
fi

bundle=$1

function copy_deps {
	for dep in $(otool -L $1 | grep local | awk '{print $1}'); do
		if [ ! -f $bundle/Contents/Frameworks/$(basename $dep) ]; then
			echo " CP $bundle/Contents/Frameworks/$(basename $dep)"
			cp $dep $bundle/Contents/Frameworks/$(basename $dep)
			chmod 644 $bundle/Contents/Frameworks/$(basename $dep)
			copy_deps $bundle/Contents/Frameworks/$(basename $dep)
		fi
	done
}

function fix_symbols {
	echo " FX $1"
	for dep in $(otool -L $1 | grep local | awk '{print $1}'); do
		install_name_tool -change $dep @executable_path/../Frameworks/$(basename $dep) $1
	done
}

for bin in ${@:2}; do
	copy_deps $bin
done

for bin in ${@:2} $bundle/Contents/Frameworks/*.dylib; do
	fix_symbols $bin
done
