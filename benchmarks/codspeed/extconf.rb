# frozen_string_literal: true

# Builds the CodSpeed extension from instrument-hooks' single-file distribution.
require 'mkmf'

instrument_hooks = File.join(__dir__, 'instrument-hooks')
abort "Missing #{instrument_hooks}: run `git submodule update --init`" unless File.exist?(File.join(instrument_hooks, 'dist', 'core.c'))

# rubocop:disable Style/GlobalVars
$INCFLAGS << " -I#{File.join(instrument_hooks, 'includes')}"
$VPATH << File.join(instrument_hooks, 'dist')
$srcs = %w[codspeed.c core.c]
# Silence warnings from the generated core.c, as instrument-hooks recommends.
$CFLAGS << ' -Wno-maybe-uninitialized -Wno-unused-variable -Wno-unused-parameter ' \
           '-Wno-unused-but-set-variable -Wno-type-limits -Wno-format -Wno-old-style-definition'
# rubocop:enable Style/GlobalVars

create_makefile('codspeed')
