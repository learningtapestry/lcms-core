# frozen_string_literal: true

# Type-check baseline scoped to the renderer-plugin contract types only.
# Expanding this to wider lib/ checking is intentionally deferred — the
# contract surface is what most benefits from typing today (it's the
# extension point plugins must satisfy).
#
# Plugin signatures are auto-discovered via the lib/plugins/*/sig glob,
# so plugins can ship their own sig/ trees without Steepfile changes.
#
# Run: bundle exec steep check
#
D = Steep::Diagnostic

target :lib do
  signature "sig", "lib/plugins/*/sig"

  check "lib/exporters/pdf/render_options.rb"
  check "lib/exporters/pdf/renderers/base.rb"
  check "lib/exporters/pdf/renderers/grover.rb"
  check "lib/exporters/pdf/renderer_registry.rb"
  check "lib/plugin_system/registry.rb"

  configure_code_diagnostics do |hash|
    # Constants supplied by the consumer of PluginSystem::Registry (the
    # protocol contract is duck-typed by design — see ADR-0001 §3.3).
    # Steep cannot see these from inside the mixin since they live on the
    # extending module, not the mixin itself.
    hash[D::Ruby::UnknownConstant] = :information

    # The `Grover` constant is a third-party gem without RBS signatures.
    # Could be addressed with a vendor stub if/when wider gem typing is
    # tackled — out of scope for this baseline.

    # Empty collections used as defaults in `RenderOptions::DEFAULTS` and
    # `CAPABILITY_FOR_ACCESSIBILITY[:none]`. Their element types are
    # constrained by the surrounding Hash/Array RBS, not by the literal.
    hash[D::Ruby::UnannotatedEmptyCollection] = :information
  end
end
