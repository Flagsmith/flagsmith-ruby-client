# frozen_string_literal: true

# Builds the CodSpeed extension from instrument-hooks' single-file distribution.
require 'mkmf'

instrument_hooks = File.join(__dir__, 'instrument-hooks')
abort "Missing #{instrument_hooks}: run `git submodule update --init`" unless File.exist?(File.join(instrument_hooks, 'dist', 'core.c'))

# rubocop:disable Style/GlobalVars
$INCFLAGS << " -I#{File.join(instrument_hooks, 'includes')}"
$VPATH << File.join(instrument_hooks, 'dist')
$srcs = %w[codspeed.c core.c]
# Compile as C11 like pytest-codspeed: GCC 15 defaults to C23, which breaks zig.h's noreturn.
$CFLAGS << ' -std=gnu11'
# Silence warnings from the generated core.c, as instrument-hooks recommends.
$CFLAGS << %w[
  -Wno-maybe-uninitialized -Wno-unused-variable -Wno-unused-parameter -Wno-unused-but-set-variable
  -Wno-type-limits -Wno-format -Wno-format-security -Wno-old-style-definition -Wno-unterminated-string-initialization
].join(' ').prepend(' ')
# rubocop:enable Style/GlobalVars

create_makefile('codspeed')
