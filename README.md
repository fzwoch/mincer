Mincer
======

The poor man's streaming app for OS X.

Mincer is a simple RTMP broadcast application for OS X. It can be used to stream to public live broadcasting sites like Twitch, Hitbox, Ustream or YouTube. Mincer is released under the GNU General Public License.

Download binaries at <a href="https://plus.google.com/106302080469674598966?rel=publisher" rel="publisher">Google+</a>.

Prerequisites
-------------

For building the application you require:

* Xcode command line tools (https://developer.apple.com)
* GStreamer 1.6 (http://gstreamer.freedesktop.org)
* Premake 5.0 (http://premake.github.io)

Xcode command line tools can be installed from the terminal:

    $ xcode-select --install

Build instructions
------------------

    $ git clone https://github.com/fzwoch/mincer.git
    $ cd mincer
    $ premake5 gmake
    $ make config=release
