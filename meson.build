project('mincer', ['vala', 'c'])

deps = []
deps += dependency('gstreamer-1.0')
deps += dependency('gtk+-3.0')

executable('mincer', 'mincer.vala',
	dependencies : deps
)
