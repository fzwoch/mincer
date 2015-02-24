#
# Mincer
#
# Copyright (C) 2013-2015 Florian Zwoch <fzwoch@gmail.com>
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

PLUGINS_FILES = \
	libgstvideoscale.so \
	libgstfaac.so \
	libgstvideorate.so \
	libgstapplemedia.so \
	libgstcoreelements.so \
	libgstaudiotestsrc.so \
	libgstosxaudio.so \
	libgstvolume.so \
	libgstaudiomixer.so \
	libgstaudioconvert.so \
	libgstaudioresample.so \
	libgstvideoparsersbad.so \
	libgstaudioparsers.so \
	libgstvideoconvert.so \
	libgstx264.so \
	libgstflv.so \
	libgstisomp4.so \
	libgstrtmp.so

PLUGINS_DIR=$(dir $(shell gst-inspect-1.0 coreelements | grep Filename | awk '{print $$2}'))
PLUGINS=$(addprefix Mincer.app/Contents/Frameworks/gstreamer-1.0/, $(PLUGINS_FILES))

LDFLAGS+=-headerpad_max_install_names

all: Mincer.app

Mincer.app: Mincer.app/Contents/MacOS/mincer Mincer.app/Contents/Resources/mincer.icns Mincer.app/Contents/Info.plist $(PLUGINS)
	@echo " FX $@"
	@sh fixbundle.sh $@ $(PLUGINS)

Mincer.app/Contents/Resources/mincer.icns: mincer.iconset/icon_512x512.png
	@echo " IC $@"
	@mkdir -p $(dir $@)
	@iconutil -c icns $(dir $<) -o $@ &> /dev/null

Mincer.app/Contents/Info.plist:
	@echo " PL $@"
	@mkdir -p $(dir $@)
	@/usr/libexec/PlistBuddy -c 'Add :CFBundleName string "Mincer"' $@ > /dev/null
	@/usr/libexec/PlistBuddy -c 'Add :CFBundleExecutable string "mincer"' $@
	@/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string "mincer.icns"' $@
	@/usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string "zwoch.florian.mincer"' $@
	@/usr/libexec/PlistBuddy -c 'Add :CFBundleVersion string "0.1.8"' $@
	@/usr/libexec/PlistBuddy -c 'Add :NSHighResolutionCapable bool YES' $@
	@/usr/libexec/PlistBuddy -c 'Add :NSHumanReadableCopyright string "© 2013-2015 Florian Zwoch"' $@

Mincer.app/Contents/MacOS/mincer: mincer.m
	@echo " CC $@"
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) $(LDFLAGS) $(shell pkg-config --cflags --libs gstreamer-1.0) -framework Cocoa -framework CoreAudio -framework AVFoundation $< -o $@

Mincer.app/Contents/Frameworks/gstreamer-1.0/libgstosxdesktopsrc.so: gstosxdesktopsrc.m
	@echo " CC $@"
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) $(LDFLAGS) -shared $(shell pkg-config --cflags --libs gstreamer-base-1.0) -framework AppKit $< -o $@
	@chmod 644 $@

Mincer.app/Contents/Frameworks/gstreamer-1.0/%.so: $(PLUGINS_DIR)/%.so
	@echo " CP $@"
	@mkdir -p $(dir $@)
	@cp $< $@
	@chmod 644 $@

package: Mincer.app
	@echo " ZP mincer.zip"
	@ditto -c -k --keepParent --arch x86_64 $< mincer.zip

clean:
	@echo " CLEAN"
	@rm -rf Mincer.app mincer.zip
