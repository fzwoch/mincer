Mincer
======

The poor man's streaming app for OS X.

Mincer is a simple RTMP broadcast application for OS X. It can be used to stream to public live broadcasting sites like Twitch, Hitbox, Ustream or YouTube. Mincer is released under the GNU General Public License.

Download binaries at <a href="https://plus.google.com/106302080469674598966" rel="publisher">Google+</a>.

Prerequisites
-------------

For building the application you require at least the following:

* Xcode (https://developer.apple.com)
* RSVG (https://developer.gnome.org/rsvg)
* GStreamer 1.4.x development files (http://gstreamer.freedesktop.org)

Xcode can be installed direcly from the Apple App Store. Once installed you also have to install the Xcode command line tools:

    $ xcode-select --install

The recommended way to install 3rd party libraries and tools on your system is using a packet manager:

* Macports (http://macports.org)
* Fink (http://finkproject.org)
* Homebrew (http://brew.sh)

Consult the manual of your packet manager of choice on how to install the required libraries and tools.

Build instructions
------------------

    $ git clone https://github.com/fzwoch/mincer.git
    $ cd mincer
    $ make clean all
