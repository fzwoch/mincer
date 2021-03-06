--
-- Mincer
--
-- Copyright (C) 2013-2016 Florian Zwoch <fzwoch@gmail.com>
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

solution "mincer"
	configurations { "release", "debug" }

	filter "configurations:release"
		defines "NDEBUG"
		optimize "full"

	filter "configurations:debug"
		symbols "on"

	filter "system:macosx"
		toolset "clang"
		buildoptions "-x objective-c++"

	project "mincer"
		kind "WindowedApp"
		language "C++"
		files { "src/*.cpp", "src/*.h" }
		includedirs "include"

		local version = "0.2.3"
		defines { "MINCER_VERSION=" .. "\"" .. (version) .. "\"" }

		filter { "system:macosx", "configurations:release" }
			postbuildcommands "strip -x %{cfg.buildtarget.abspath}"

		filter "system:macosx"
			buildoptions "`wx-config --static --cflags`"
			linkoptions "`wx-config --static --libs`"

			includedirs "/Library/Frameworks/GStreamer.framework/Headers"
			linkoptions { os.matchfiles("/Library/Frameworks/GStreamer.framework/Libraries/**.a") }

			links "AudioUnit.framework"
			links "AVFoundation.framework"
			links "Cocoa.framework"
			links "CoreAudio.framework"
			links "CoreMedia.framework"
			links "CoreVideo.framework"
			links "IOSurface.framework"
			links "OpenGL.framework"
			links "QuartzCore.framework"
			links "QTKit.framework"
			links "VideoToolBox.framework"
			links "resolv"

			linkoptions "-mmacosx-version-min=10.9"
			buildoptions "-mmacosx-version-min=10.9"

			postbuildcommands {
				"{DELETE} -r Mincer.app",
				"{DELETE} mincer_macos.zip",
				"{MKDIR} Mincer.app/Contents/MacOS",
				"{MKDIR} Mincer.app/Contents/Resources",
				"{COPY} %{cfg.buildtarget.abspath} Mincer.app/Contents/MacOS/mincer",
				"iconutil -c icns mincer.iconset -o Mincer.app/Contents/Resources/mincer.icns",

				"/usr/libexec/PlistBuddy -c 'Add :CFBundleName string Mincer' Mincer.app/Contents/Info.plist",
				"/usr/libexec/PlistBuddy -c 'Add :CFBundleExecutable string mincer' Mincer.app/Contents/Info.plist",
				"/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string mincer.icns' Mincer.app/Contents/Info.plist",
				"/usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string zwoch.florian.mincer' Mincer.app/Contents/Info.plist",
				"/usr/libexec/PlistBuddy -c 'Add :CFBundleShortVersionString string " .. (version) .."' Mincer.app/Contents/Info.plist",
				"/usr/libexec/PlistBuddy -c 'Add :NSHighResolutionCapable bool YES' Mincer.app/Contents/Info.plist",
				"/usr/libexec/PlistBuddy -c 'Add :NSHumanReadableCopyright string © 2013-2016 Florian Zwoch' Mincer.app/Contents/Info.plist",

				"ditto -c -k --keepParent --arch x86_64 Mincer.app mincer_macos.zip"
			}

		filter "system:windows"
			buildoptions "`wx-config --cflags`"
			linkoptions "`wx-config --libs`"

			buildoptions "`pkg-config --cflags gstreamer-1.0`"
			linkoptions "`pkg-config --libs gstreamer-1.0`"

			includedirs "/mingw64/include/wx-3.0"

			prebuildcommands {
				"echo '#include \"wx/msw/wx.rc\"' > mincer.rc",
				"echo 'APPICON ICON \"mincer.ico\"' >> mincer.rc"
			}
			files "mincer.rc"

			links "d3d9"

		filter "system:linux"
			buildoptions "`wx-config --cflags`"
			linkoptions "`wx-config --libs`"

			buildoptions "`pkg-config --cflags gstreamer-1.0 x11 libpulse`"
			linkoptions "`pkg-config --libs gstreamer-1.0 x11 libpulse`"
