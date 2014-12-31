Mincer
======

The poor man's streaming app for OS X.

Mincer is a simple RTMP broadcast application for OS X. It can be used to stream to public live broadcasting sites like Twitch, Hitbox, Ustream or YouTube. Mincer is released under the GNU General Public License.

Download binaries at Google+

<div><a href="//plus.google.com/u/0/106302080469674598966?prsrc=3" rel="publisher" target="_top" style="text-decoration:none;"><img src="//ssl.gstatic.com/images/icons/gplus-64.png" alt="Google+" style="border:0;width:64px;height:64px;"/>
</a></div>

Prerequisites
-------------

For building the application you require at least the following:

* Xcode command line tools (https://developer.apple.com)
* GStreamer 1.4.x (http://gstreamer.freedesktop.org)

Xcode command line tools can be installed from the terminal:

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
    $ make
