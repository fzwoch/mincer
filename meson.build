project('mincer', ['vala', 'c'])

executable('mincer', 'mincer.vala',
	dependencies : [
		dependency('gstreamer-1.0'),
		dependency('gtk+-3.0'),
		dependency('colord'),
		meson.get_compiler('c').find_library('m'),
		meson.get_compiler('vala').find_library('posix')
	],
	c_args : '-D_GNU_SOURCE',
	install : true
)

install_data('mincer.desktop', install_dir : 'share/applications')
install_data('mincer.glade', 'mincer.svg', install_dir : 'share/mincer')
