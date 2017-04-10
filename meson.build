project('mincer', ['vala', 'c'])

deps = []
deps += dependency('gstreamer-1.0')
deps += dependency('gtk+-3.0')
deps += dependency('libpulse')
deps += dependency('x11')

executable('mincer', 'mincer.vala',
	dependencies : deps
)
