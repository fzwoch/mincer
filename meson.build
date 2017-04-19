project('mincer', ['vala', 'c'])

deps = []
deps += dependency('gstreamer-1.0')
deps += dependency('gtk+-3.0')
deps += meson.get_compiler('c').find_library('m')

executable('mincer', 'mincer.vala',
	dependencies : deps,
	install : true
)

install_data('mincer.desktop', install_dir : 'share/applications')
install_data('mincer.glade', 'mincer.svg', install_dir : 'share/mincer')
