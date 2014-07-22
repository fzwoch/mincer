Mincer
======

The poor man's streaming app for OS X.

Mincer is a simple RTMP broadcast application for OS X. It can be used to stream to public live broadcasting sites like Twitch, Hitbox, Ustream or YouTube. Mincer is released under the GNU General Public License.

Download binaries at <a href="https://plus.google.com/106302080469674598966" rel="publisher">Google+</a>.

Build instructions
------------------

For compiling the application you require at least the following:

* XCode (https://developer.apple.com)
* ImageMagick (http://imagemagick.org)
* GStreamer 1.4.x development files (http://gstreamer.freedesktop.org)

XCode can be directly installed from the App Store. Once installed you also have to install the XCode command line tools. Type this in your terminal:

    $ xcode-select --install

The recommended way to install 3rd party libraries and tools on your system is via a packet manager. Recommended are one of these:

* Macports (http://macports.org)
* Fink (http://finkproject.org)
* Homebrew (http://brew.sh)

It is up to you to figure out how to install the required libraries depending on which packet manager you selected. It can be a bit tricky and therefore is out of scope of this manual. Once set up you are ready to compile the application:

    $ git clone https://github.com/fzwoch/mincer.git
    $ cd mincer
    $ make clean all

The current directory should now contain an application bundle ready to deploy on any machine with the same major version of OS X.
