// Ruby bindings for CodSpeed's instrument-hooks, measuring a block in-process.
#include <ruby.h>
#include <unistd.h>

#include "core.h"

static InstrumentHooks *hooks;

// Root frame of the benchmark flame graph: everything measured runs inside it.
__attribute__((noinline)) static VALUE __codspeed_root_frame__measure(VALUE _) {
  return rb_yield(Qnil);
}

static VALUE stop_measuring(VALUE uri) {
  callgrind_stop_instrumentation();
  if (instrument_hooks_stop_benchmark(hooks) != 0)
    rb_warn("CodSpeed: failed to stop the benchmark");
  if (instrument_hooks_set_executed_benchmark(hooks, getpid(), StringValueCStr(uri)) != 0)
    rb_warn("CodSpeed: failed to report the executed benchmark");
  return Qnil;
}

// CodSpeed.measure(uri) { ... }: measure the block once as the benchmark at uri.
static VALUE codspeed_measure(VALUE self, VALUE uri) {
  rb_need_block();
  StringValueCStr(uri);
  if (instrument_hooks_start_benchmark(hooks) != 0)
    rb_raise(rb_eRuntimeError, "CodSpeed: failed to start the benchmark");
  // Toggle callgrind here, rather than in start_benchmark, to measure as little harness as possible.
  callgrind_start_instrumentation();
  return rb_ensure(__codspeed_root_frame__measure, Qnil, stop_measuring, uri);
}

// CodSpeed.instrumented?: whether the process runs under the CodSpeed runner.
static VALUE codspeed_instrumented_p(VALUE self) {
  return instrument_hooks_is_instrumented(hooks) ? Qtrue : Qfalse;
}

// CodSpeed.setup(integration, version, skipped_objects): register the harness with the runner.
static VALUE codspeed_setup(VALUE self, VALUE integration, VALUE version, VALUE skipped_objects) {
  if (instrument_hooks_set_integration(hooks, StringValueCStr(integration), StringValueCStr(version)) != 0)
    rb_warn("CodSpeed: failed to register the integration");
  // Attribute interpreter costs to the root frame, as pytest-codspeed does for libpython.
  for (long i = 0; i < RARRAY_LEN(skipped_objects); i++) {
    VALUE path = rb_ary_entry(skipped_objects, i);
    instrument_hooks_callgrind_add_obj_skip(StringValueCStr(path));
  }
  return Qnil;
}

void Init_codspeed(void) {
  hooks = instrument_hooks_init();
  if (!hooks) rb_raise(rb_eRuntimeError, "CodSpeed: failed to initialise instrument-hooks");
  instrument_hooks_set_feature(FEATURE_DISABLE_CALLGRIND_MARKERS, true);

  VALUE codspeed = rb_define_module("CodSpeed");
  rb_define_module_function(codspeed, "measure", codspeed_measure, 1);
  rb_define_module_function(codspeed, "instrumented?", codspeed_instrumented_p, 0);
  rb_define_module_function(codspeed, "setup", codspeed_setup, 3);
}
