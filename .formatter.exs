# Used by "mix format"
locals_without_parens = [attr: 2, attr: 3, slot: 1, slot: 2, slot: 3]

[
  line_length: 120,
  inputs: ["{mix,.formatter}.exs", "{config,lib,test,spec_gen,screenshots}/**/*.{ex,exs}"],
  locals_without_parens: locals_without_parens,
  # Projects that use `import_deps: [:mjml_eex]` can write attr/slot without parens
  export: [locals_without_parens: locals_without_parens]
]
