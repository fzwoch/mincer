Mincer
======

The poor man's streaming app for OS X.

Mincer is a simple RTMP broadcast application for OS X. It can be used to stream to public live broadcasting sites like Twitch, Hitbox, Ustream or YouTube. Mincer is released under the GNU General Public License.

Download binaries at <a href="https://plus.google.com/106302080469674598966" rel="publisher">Google+</a>.

Build instructions
------------------

For compiling the application you require at least he following:

* XCode (https://developer.apple.com) + command line tools
* CMake (http://cmake.org)
* GStreamer 1.x development files (http://gstreamer.freedesktop.org)

The recommended way to install these libraries and tools on your system is via a 3rd party packet manager. I personally use Macports (http://macports.org) but there are also alternatives - most commonly Fink (http://finkproject.org) or Homebrew (http://brew.sh).

If using Macports you can install the required packages with the following command. You will have to adapt the command to other package managers if you have selected a different one.

    $ sudo port install cmake rtmpdump gstreamer1 gstreamer1-gst-plugins-base gstreamer1-gst-plugins-good gstreamer1-gst-plugins-bad gstreamer1-gst-plugins-ugly

Depending on whether these packages get build from source or just binary versions get installed this may take some time. Once set up you are ready to compile the application:

    $ git clone https://github.com/fzwoch/mincer.git
    $ mkdir build
    $ cd build
    $ cmake ../mincer
    $ make clean install

The current directory should now contain an application bundle ready to deploy on any machine with the same major version of OS X.
