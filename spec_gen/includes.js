// Dev-only: records how MJML's parser expands mj-include for each fixture in a directory,
// for `mix mjml_eex.gen.spec`. The trees are normalized to tags, attributes, the content of
// ending tags (trimmed) and children.
//
// Usage: node spec_gen/includes.js <fixtures dir> <allowed include dir> <output json path>

'use strict'

const fs = require('fs')
const path = require('path')
const parse = require('mjml-parser-xml')
const { components, assignComponents } = require('mjml-core')
const preset = require('mjml-preset-core')

const presetCore = preset.default || preset
assignComponents(components, presetCore.components)

const [dir, includeDir, output] = process.argv.slice(2)
if (!dir || !includeDir || !output) {
  process.stderr.write('usage: node spec_gen/includes.js <fixtures dir> <allowed include dir> <output json path>\n')
  process.exit(1)
}

const normalize = (node) => ({
  tag: node.tagName,
  attributes: node.attributes || {},
  ...(node.content !== undefined ? { content: node.content.trim() } : {}),
  children: (node.children || []).map(normalize),
})

const results = { generated_by: 'spec_gen/includes.js (mix mjml_eex.gen.spec)', fixtures: {} }

for (const file of fs.readdirSync(dir).filter((f) => f.endsWith('.mjml')).sort()) {
  const filePath = path.resolve(dir, file)
  const json = (parse.default || parse)(fs.readFileSync(filePath, 'utf8'), {
    components,
    filePath,
    actualPath: filePath,
    ignoreIncludes: false,
    includePath: [path.resolve(dir), path.resolve(includeDir)],
    keepComments: false,
  })
  results.fixtures[file] = normalize(json)
}

fs.writeFileSync(output, JSON.stringify(results, null, 2) + '\n')
