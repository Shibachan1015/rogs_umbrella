# Dialyzer warnings to ignore
# Format: {warning_type, {file, line}, message} or regex patterns
#
# Example:
# {~r/Function .* has no local return/, "lib/some_file.ex", 123}
# {:pattern_match, "lib/some_file.ex", 45}
#
# See: https://hexdocs.pm/dialyxir/readme.html#elixir-term-format
[
  # Phoenix/LiveView generated code often triggers false positives
  # Add specific ignores here as needed

  # Compile-time constant: @dev_bypass_enabled is set at compile time
  # When false, the 'false' branch of the if statement is never taken
  ~r/lib\/rogs_identity\/plug.ex:58/
]
