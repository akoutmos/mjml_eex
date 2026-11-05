// Dev-only: records what MJML's own validator reports for each validation fixture,
// for `mix mjml_eex.gen.spec`. Runs the parser and validator the same way
// `mjml --validate` does.
//
// Usage: node spec_gen/validate.js <fixtures dir> <output json path>

'use strict'

const fs = require('fs')
const path = require('path')
const parse = require('mjml-parser-xml')
const { components, initializeType, assignComponents } = require('mjml-core')
const validate = require('mjml-validator')
const { dependencies, assignDependencies } = require('mjml-validator')
const preset = require('mjml-preset-core')

// Register the core components and their dependencies, like the mjml package does
const presetCore = preset.default || preset
assignComponents(components, presetCore.components)
assignDependencies(dependencies, presetCore.dependencies)

const [dir, output] = process.argv.slice(2)
if (!dir || !output) {
  process.stderr.write('usage: node spec_gen/validate.js <fixtures dir> <output json path>\n')
  process.exit(1)
}

const results = {
  generated_by: 'spec_gen/validate.js (mix mjml_eex.gen.spec)',
  mjml_version: require('mjml-core/package.json').version,
  fixtures: {},
}

for (const file of fs.readdirSync(dir).filter((f) => f.endsWith('.mjml')).sort()) {
  const source = fs.readFileSync(path.join(dir, file), 'utf8')

  try {
    const json = (parse.default || parse)(source, { components, filePath: '.', actualPath: file })
    const errors = (validate.default || validate)(json, { components, dependencies, initializeType })
    results.fixtures[file] = errors.map(({ line, tagName, message }) => ({ line, tag: tagName, message }))
  } catch (error) {
    results.fixtures[file] = { exception: error.message }
  }
}

fs.writeFileSync(output, JSON.stringify(results, null, 2) + '\n')
