#
# Mincer
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

cmake_minimum_required(VERSION 2.6)
project(Mincer)

find_library(COCOA_LIBRARY Cocoa)
find_library(COREAUDIO_LIBRARY CoreAudio)
find_library(AUDIOTOOLBOX_LIBRARY AudioToolBox)

find_package(PkgConfig REQUIRED)

pkg_check_modules(GSTREAMER REQUIRED gstreamer-1.0)
pkg_check_modules(GSTREAMER_BASE REQUIRED gstreamer-base-1.0)
pkg_check_modules(GSTREAMER_AUDIO REQUIRED gstreamer-audio-1.0)

include_directories(${GSTREAMER_INCLUDE_DIRS})
link_directories(${GSTREAMER_LIBRARY_DIRS})

add_executable(Mincer MACOSX_BUNDLE mincer.m mincer.icns)
target_link_libraries(Mincer ${COCOA_LIBRARY} ${COREAUDIO_LIBRARY} ${GSTREAMER_LIBRARIES})

add_library(gstosxdesktopsrc MODULE gstosxdesktopsrc.m)
target_link_libraries(gstosxdesktopsrc ${COCOA_LIBRARY} ${GSTREAMER_BASE_LIBRARIES})

add_library(gstosxvideoscale MODULE gstosxvideoscale.m)
target_link_libraries(gstosxvideoscale ${COCOA_LIBRARY} ${GSTREAMER_BASE_LIBRARIES})

add_library(gstosxaacencode MODULE gstosxaacencode.m)
target_link_libraries(gstosxaacencode ${COCOA_LIBRARY} ${AUDIOTOOLBOX_LIBRARY} ${GSTREAMER_AUDIO_LIBRARIES})

set_target_properties(gstosxdesktopsrc gstosxvideoscale gstosxaacencode PROPERTIES LIBRARY_OUTPUT_DIRECTORY Mincer.app/Contents/MacOS/gstreamer-1.0)

set(MACOSX_BUNDLE_ICON_FILE mincer)
set(MACOSX_BUNDLE_BUNDLE_NAME Mincer)
set(MACOSX_BUNDLE_BUNDLE_VERSION 0.1.2)
set(MACOSX_BUNDLE_COPYRIGHT "© 2013-2014 Florian Zwoch")
set(MACOSX_BUNDLE_GUI_IDENTIFIER zwoch.florian.mincer)

set_source_files_properties(mincer.icns PROPERTIES MACOSX_PACKAGE_LOCATION Resources)

set(PLUGINS
	libgstcoreelements.so
	libgstaudiotestsrc.so
	libgstosxaudio.so
	libgstadder.so
	libgstaudioconvert.so
	libgstaudioresample.so
	libgstvideoparsersbad.so
	libgstaudioparsers.so
	libgstvideoconvert.so
	libgstx264.so
	libgstflv.so
	libgstisomp4.so
	libgstrtmp.so)

foreach(PLUGIN ${PLUGINS})
	install(FILES "${GSTREAMER_LIBRARY_DIRS}/gstreamer-1.0/${PLUGIN}" DESTINATION "${CMAKE_BINARY_DIR}/Mincer.app/Contents/MacOS/gstreamer-1.0")
endforeach(PLUGIN)

install(CODE "
	file(GLOB PLUGINS \"Mincer.app/Contents/MacOS/gstreamer-1.0/*.so\")
	include(BundleUtilities)
	fixup_bundle(\"${CMAKE_BINARY_DIR}/Mincer.app\" \"\${PLUGINS}\" \"\")
")
