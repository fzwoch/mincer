--
-- Mincer
--
-- Copyright (C) 2013-2015 Florian Zwoch <fzwoch@gmail.com>
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program. If not, see <http://www.gnu.org/licenses/>.
--

workspace "mincer"
	configurations { "debug", "release" }

	filter "configurations:debug"
		flags "symbols"

	filter "configurations:release"
		optimize "full"
		defines "NDEBUG"

	project "mincer"
		kind "ConsoleApp"
		language "C"
		files "*.m"
		includedirs "/Library/Frameworks/GStreamer.framework/Headers"
		linkoptions "-L/Library/Frameworks/GStreamer.framework/Libraries"

		links {
			"Cocoa.framework",
			"AVFoundation.framework",
			"CoreAudio.framework",
			"gstreamer-1.0",
			"glib-2.0",
			"gobject-2.0"
		}

		postbuildcommands {
			-- clean
			"{DELETE} -r Mincer.app",
			"{DELETE} mincer.zip",

			-- create directory structure
			"{MKDIR} Mincer.app/Contents/MacOS",
			"{MKDIR} Mincer.app/Contents/Resources",
			"{MKDIR} Mincer.app/Contents/Frameworks/gstreamer-1.0",

			-- FIXME: copy debug/release
			-- copy application
			"{COPY} bin/release/mincer Mincer.app/Contents/MacOS",

			-- create icon file
			"iconutil -c icns mincer.iconset -o Mincer.app/Contents/Resources/mincer.icns",

			-- create Info.plist
			"/usr/libexec/PlistBuddy -c 'Add :CFBundleName string Mincer' Mincer.app/Contents/Info.plist",
			"/usr/libexec/PlistBuddy -c 'Add :CFBundleExecutable string mincer' Mincer.app/Contents/Info.plist",
			"/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string mincer.icns' Mincer.app/Contents/Info.plist",
			"/usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string zwoch.florian.mincer' Mincer.app/Contents/Info.plist",
			"/usr/libexec/PlistBuddy -c 'Add :CFBundleVersion string 0.2.0' Mincer.app/Contents/Info.plist",
			"/usr/libexec/PlistBuddy -c 'Add :NSHighResolutionCapable bool YES' Mincer.app/Contents/Info.plist",
			"/usr/libexec/PlistBuddy -c 'Add :NSHumanReadableCopyright string © 2013-2015 Florian Zwoch' Mincer.app/Contents/Info.plist",

			-- copy GStreamer plugins
			"{COPY} /Library/Frameworks/GStreamer.framework/Libraries/gstreamer-1.0/libgstapplemedia.so Mincer.app/Contents/Frameworks/gstreamer-1.0",
			"{COPY} /Library/Frameworks/GStreamer.framework/Libraries/gstreamer-1.0/libgstaudioconvert.so Mincer.app/Contents/Frameworks/gstreamer-1.0",
			"{COPY} /Library/Frameworks/GStreamer.framework/Libraries/gstreamer-1.0/libgstaudiomixer.so Mincer.app/Contents/Frameworks/gstreamer-1.0",
			"{COPY} /Library/Frameworks/GStreamer.framework/Libraries/gstreamer-1.0/libgstaudioparsers.so Mincer.app/Contents/Frameworks/gstreamer-1.0",
			"{COPY} /Library/Frameworks/GStreamer.framework/Libraries/gstreamer-1.0/libgstaudioresample.so Mincer.app/Contents/Frameworks/gstreamer-1.0",
			"{COPY} /Library/Frameworks/GStreamer.framework/Libraries/gstreamer-1.0/libgstaudiotestsrc.so Mincer.app/Contents/Frameworks/gstreamer-1.0",
			"{COPY} /Library/Frameworks/GStreamer.framework/Libraries/gstreamer-1.0/libgstcoreelements.so Mincer.app/Contents/Frameworks/gstreamer-1.0",
			"{COPY} /Library/Frameworks/GStreamer.framework/Libraries/gstreamer-1.0/libgstdecklink.so Mincer.app/Contents/Frameworks/gstreamer-1.0",
			"{COPY} /Library/Frameworks/GStreamer.framework/Libraries/gstreamer-1.0/libgstflv.so Mincer.app/Contents/Frameworks/gstreamer-1.0",
			"{COPY} /Library/Frameworks/GStreamer.framework/Libraries/gstreamer-1.0/libgstisomp4.so Mincer.app/Contents/Frameworks/gstreamer-1.0",
			"{COPY} /Library/Frameworks/GStreamer.framework/Libraries/gstreamer-1.0/libgstlame.so Mincer.app/Contents/Frameworks/gstreamer-1.0",
			"{COPY} /Library/Frameworks/GStreamer.framework/Libraries/gstreamer-1.0/libgstosxaudio.so Mincer.app/Contents/Frameworks/gstreamer-1.0",
			"{COPY} /Library/Frameworks/GStreamer.framework/Libraries/gstreamer-1.0/libgstrtmp.so Mincer.app/Contents/Frameworks/gstreamer-1.0",
			"{COPY} /Library/Frameworks/GStreamer.framework/Libraries/gstreamer-1.0/libgstvideoconvert.so Mincer.app/Contents/Frameworks/gstreamer-1.0",
			"{COPY} /Library/Frameworks/GStreamer.framework/Libraries/gstreamer-1.0/libgstvideoparsersbad.so Mincer.app/Contents/Frameworks/gstreamer-1.0",
			"{COPY} /Library/Frameworks/GStreamer.framework/Libraries/gstreamer-1.0/libgstvideoscale.so Mincer.app/Contents/Frameworks/gstreamer-1.0",
			"{COPY} /Library/Frameworks/GStreamer.framework/Libraries/gstreamer-1.0/libgstvoaacenc.so Mincer.app/Contents/Frameworks/gstreamer-1.0",
			"{COPY} /Library/Frameworks/GStreamer.framework/Libraries/gstreamer-1.0/libgstvolume.so Mincer.app/Contents/Frameworks/gstreamer-1.0",
			"{COPY} /Library/Frameworks/GStreamer.framework/Libraries/gstreamer-1.0/libgstx264.so Mincer.app/Contents/Frameworks/gstreamer-1.0",

			"chmod 644 Mincer.app/Contents/Frameworks/gstreamer-1.0/*.so",

			-- fix bundle
			"sh fixbundle.sh Mincer.app `ls Mincer.app/Contents/Frameworks/gstreamer-1.0/*.so`",

			-- create zip
			"ditto -c -k --keepParent --arch x86_64 Mincer.app mincer.zip"
		}
