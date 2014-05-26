#
# mincer
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

CFLAGS  = -Wall -O2 $(shell pkg-config --cflags gstreamer-1.0)
LDFLAGS = $(shell pkg-config --libs gstreamer-1.0) -Wl,-headerpad_max_install_names -framework Cocoa -framework Coreaudio

APP = Mincer.app/Contents/MacOS/mincer
OBJ = mincer.o
ICN = Mincer.app/Contents/Resources/mincer.icns
DMG = Mincer.dmg

GST = \
	libgstcoreelements.so \
	libgstaudiotestsrc.so \
	libgstosxaudio.so \
	libgstadder.so \
	libgstaudioconvert.so \
	libgstaudioresample.so \
	libgstvideoparsersbad.so \
	libgstaudioparsers.so \
	libgstvideoconvert.so \
	libgstx264.so \
	libgstflv.so \
	libgstisomp4.so \
	libgstrtmp.so \
	libgstosxdesktopsrc.so \
	libgstosxvideoscale.so \
	libgstosxaacencode.so

all: $(DMG)
	@echo " DONE"

$(APP): $(OBJ) $(ICN) $(addprefix Mincer.app/Contents/Frameworks/gstreamer-1.0/, $(GST))
	@echo " LD $@"
	@$(CC) $< $(LDFLAGS) -o $@
	@for dylib in `otool -L $@ | grep /opt/local/lib | cut -d ' ' -f 1`; do \
		if [ ! -f Mincer.app/Contents/Frameworks/`basename $$dylib` ]; then \
			echo " CP Mincer.app/Contents/Frameworks/`basename $$dylib`"; \
			cp $$dylib Mincer.app/Contents/Frameworks/`basename $$dylib`; \
		fi; \
		install_name_tool -change $$dylib @loader_path/../Frameworks/`basename $$dylib` $@; \
	done
	@for dylib in `ls Mincer.app/Contents/Frameworks/*.dylib`; do \
		for lib in `otool -L $$dylib | grep /opt/local/lib | cut -d ' ' -f 1`; do \
			if [ ! -f Mincer.app/Contents/Frameworks/`basename $$lib` ]; then \
				echo " CP Mincer.app/Contents/Frameworks/`basename $$lib`"; \
				cp $$lib Mincer.app/Contents/Frameworks/`basename $$lib`; \
			fi; \
			install_name_tool -change $$lib @loader_path/../Frameworks/`basename $$lib` $$dylib; \
		done \
	done

$(DMG): $(APP)
	@echo " DMG $@"
	@hdiutil create -quiet -ov $@ -srcfolder Mincer.app

%.icns:../../../%.iconset
	@echo " IC $@"
	@iconutil -c icns -o $@ $< 2>/dev/null

Mincer.app/Contents/Frameworks/gstreamer-1.0/%.so:/opt/local/lib/gstreamer-1.0/%.so
	@echo " CP $@"
	@cp $< $@
	@for dylib in `otool -L $@ | grep /opt/local/lib | cut -d ' ' -f 1`; do \
		if [ ! -f Mincer.app/Contents/Frameworks/`basename $$dylib` ]; then \
			echo " CP Mincer.app/Contents/Frameworks/`basename $$dylib`"; \
			cp $$dylib Mincer.app/Contents/Frameworks/`basename $$dylib`; \
		fi; \
		install_name_tool -change $$dylib @loader_path/../`basename $$dylib` $@; \
	done

lib%.so:../../../../%.m
	@echo " CC $@"
	@$(CC) -Wall -O2 -shared $< $(shell pkg-config --cflags --libs gstreamer-audio-1.0) -o $@ -framework Cocoa -framework AudioToolBox
	@for dylib in `otool -L $@ | grep /opt/local/lib | cut -d ' ' -f 1`; do \
		if [ ! -f Mincer.app/Contents/Frameworks/`basename $$dylib` ]; then \
			echo " CP Mincer.app/Contents/Frameworks/`basename $$dylib`"; \
			cp $$dylib Mincer.app/Contents/Frameworks/`basename $$dylib`; \
		fi; \
		install_name_tool -change $$dylib @loader_path/../`basename $$dylib` $@; \
	done

clean:
	@echo " CLEAN"
	@rm -f $(APP) $(OBJ) $(ICN) $(DMG) Mincer.app/Contents/Frameworks/*.dylib Mincer.app/Contents/Frameworks/gstreamer-1.0/*.so

%.o:%.m
	@echo " CC $@"
	@$(CC) $(CFLAGS) -c -o $@ $<
