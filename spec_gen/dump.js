// Dev-only: dumps the MJML component spec for `mix mjml_eex.gen.spec`.
//
// Usage: node spec_gen/dump.js <type_vectors.json path>
//
// Prints the spec as JSON on stdout and writes the type test vectors to the
// given path. Everything is read from the pinned MJML packages in
// package.json; nothing is scraped from source.

'use strict'

const fs = require('fs')
const path = require('path')
const { initializeType, HeadComponent, BodyComponent } = require('mjml-core')
const preset = require('mjml-preset-core')
const { rulesCollection } = require('mjml-validator')
const colorsModule = require('mjml-core/lib/types/helpers/colors')
const namedColors = colorsModule.default || colorsModule

const { components, dependencies } = preset.default || preset
const mjmlVersion = require('mjml-core/package.json').version

// These two lists are private constants in mjml-validator's rules. They are
// listed here and then checked against the rules, so a change in MJML fails
// loudly instead of silently producing a wrong spec.
const GLOBAL_ATTRIBUTES = ['mj-class', 'css-class']
const COMPONENT_LESS_TAGS = ['mj-all', 'mj-class', 'mj-selector', 'mj-html-attribute']

function fail(message) {
  process.stderr.write(`spec_gen: ${message}\n`)
  process.exit(1)
}

function checkValidatorConstants() {
  const componentMap = Object.fromEntries(components.map((c) => [c.componentName, c]))

  for (const tagName of COMPONENT_LESS_TAGS) {
    if (rulesCollection.validTag({ tagName }, { components: componentMap }) !== null) {
      fail(`${tagName} is no longer a component-less tag in mjml-validator`)
    }
  }

  if (rulesCollection.validTag({ tagName: 'mj-not-a-tag' }, { components: componentMap }) === null) {
    fail('validTag accepted an unknown tag; the component-less tag check is not trustworthy')
  }

  const attributes = Object.fromEntries(GLOBAL_ATTRIBUTES.map((name) => [name, 'x']))
  if (rulesCollection.validAttributes({ tagName: 'mj-text', attributes }, { components: componentMap }) !== null) {
    fail(`mjml-validator no longer allows all of ${GLOBAL_ATTRIBUTES.join(', ')} on every component`)
  }

  const unknown = { ...attributes, 'not-an-attribute': 'x' }
  const error = rulesCollection.validAttributes({ tagName: 'mj-text', attributes: unknown }, { components: componentMap })
  if (!error || error.message !== 'Attribute not-an-attribute is illegal') {
    fail(`mjml-validator accepts attributes beyond ${GLOBAL_ATTRIBUTES.join(', ')}`)
  }
}

function componentKind(component) {
  if (component.prototype instanceof HeadComponent) return 'head'
  if (component.prototype instanceof BodyComponent) return 'body'
  fail(`${component.componentName} is neither a head nor a body component`)
}

// A null default means the attribute has no default. Non-string defaults on
// undeclared attributes are internal component config (e.g. mj-accordion-element's
// `title`), not attributes, so they are skipped too.
function dumpDefaults(component, allowedAttributes) {
  const defaults = {}

  for (const [name, value] of Object.entries(component.defaultAttributes || {})) {
    if (typeof value === 'string') {
      defaults[name] = value
    } else if (value !== null && name in allowedAttributes) {
      fail(`${component.componentName} has a non-string default for ${name}: ${JSON.stringify(value)}`)
    }
  }

  return defaults
}

function dumpComponent(component) {
  // Read through the class chain, since mj-wrapper inherits from mj-section
  const allowedAttributes = { ...(component.allowedAttributes || {}) }

  return {
    name: component.componentName,
    kind: componentKind(component),
    ending_tag: !!component.endingTag,
    raw_element: !!component.rawElement,
    allowed_attributes: allowedAttributes,
    default_attributes: dumpDefaults(component, allowedAttributes),
  }
}

function dumpDependencies() {
  const result = {}

  for (const [parent, children] of Object.entries(dependencies)) {
    const regexes = children.filter((child) => child instanceof RegExp)

    if (regexes.length === 0) {
      result[parent] = children
    } else if (regexes.length === children.length && regexes.every((re) => re.test('mj-anything'))) {
      // mj-attributes uses a regex that matches any tag
      result[parent] = 'any'
    } else {
      fail(`unsupported dependency regex for ${parent}: ${regexes.join(', ')}`)
    }
  }

  return result
}

// mjml-parser-xml converts the attribute values "true" and "false" into
// booleans before the validator sees them (convertBooleansOnAttrs)
function parserValue(value) {
  if (value === 'true') return true
  if (value === 'false') return false
  return value
}

function checkType(typeString, value) {
  const TypeChecker = initializeType(typeString)
  const checker = new TypeChecker(parserValue(value))
  // The validator only reports an error when isValid() is exactly false
  const valid = checker.isValid() !== false
  return valid ? { value, valid } : { value, valid, message: checker.getErrorMessage() }
}

const COMMON_VALUES = [
  '', ' ', '0', '00', '-0', '10', '-10', '1.5', '.5', '5.', '1,5', '10px', '-10px', '10%', '-10%', '10em', '-1.5em',
  '10PX', '10 px', 'px', '%', 'auto', 'AUTO', '-auto', '10px auto', 'auto auto', '0 0', '10px 0', '10px  0',
  ' 10px', '10px ', '10px\n', '\n10px', '10px\t0', '10px 20px 30px 40px', '10px 20px 30px 40px 50px', '1-1px',
  '--1px', '1.2.3px', ',,px', '0px', '0%', '0auto', 'true', 'false', 'TRUE', 'yes', '1', '-1', 'a1', '1a', 'abc',
  '#fff', '#FFF', '#Ab9', '#ffff', '#abcdef', '#ABCDEF', '#abcdeg', '#ggg', 'fff', '#fff ', 'red', 'Red', 'RED',
  'transparent', 'rebeccapurple', 'currentColor', 'rgb(1,2,3)', 'rgb(1, 2, 3)', 'rgb(1,  2, 3)', 'rgb(1000,2,3)',
  'rgb(1,2)', 'RGB(1,2,3)', 'rgba(1,2,3,0.5)', 'rgba(1,2,3,.5)', 'rgba(1, 2, 3, 1)', 'rgba(1,2,3,0.1234)',
  'rgba(1,2,3)', 'rgb(1,2,3', 'foo rgb(1,2,3) bar', 'rgb(1, 2,3)', 'rgb(1, 2,3)', 'rgb(١,2,3)',
  'left', 'LEFT', 'left ', 'center', 'right', 'justify', 'top', 'middle', 'bottom', 'full-width', 'none',
  'horizontal', 'file-start', '$value', '$&', '$$', "x$'y", 'a$`b', '1 px', '١px', 'é',
]

function enumValues(typeString) {
  const match = typeString.match(/\(([^)]*)\)/)
  return match ? match[1].split(',') : []
}

function typeSpecificValues(typeString) {
  const values = []

  if (/^enum/i.test(typeString)) {
    for (const value of enumValues(typeString)) {
      values.push(value, value.toUpperCase(), ` ${value}`, `${value} `, `${value},${value}`)
    }
  }

  if (/^(unit|unitWithNegative)\(/i.test(typeString)) {
    const units = enumValues(typeString)
    const counts = typeString.match(/\{([^}]+)\}/)
    const max = counts ? Number(counts[1].split(',').pop()) : 1

    for (const unit of units) {
      values.push(`10${unit}`, `-10${unit}`, `1.5${unit}`, `0${unit}`, unit)
      for (let count = 1; count <= max + 1; count++) {
        values.push(Array(count).fill(`1${unit}`).join(' '))
      }
    }
  }

  return values
}

function typeVectors(typeStrings) {
  const vectors = {}

  for (const typeString of typeStrings) {
    const values = [...new Set([...COMMON_VALUES, ...typeSpecificValues(typeString)])]
    vectors[typeString] = values.map((value) => checkType(typeString, value))
  }

  return vectors
}

function main() {
  const vectorsPath = process.argv[2]
  if (!vectorsPath) fail('usage: node spec_gen/dump.js <type_vectors.json path>')

  checkValidatorConstants()

  if (!Array.isArray(namedColors) || namedColors.length === 0) fail('could not load the named colors')

  const dumpedComponents = components.map(dumpComponent).sort((a, b) => a.name.localeCompare(b.name))
  const typeStrings = [...new Set(dumpedComponents.flatMap((c) => Object.values(c.allowed_attributes)))].sort()

  const vectors = {
    generated_by: 'spec_gen/dump.js (mix mjml_eex.gen.spec)',
    mjml_version: mjmlVersion,
    note: 'Values are attribute strings. Like mjml-parser-xml, "true" and "false" are converted to booleans before type checking.',
    types: typeVectors(typeStrings),
  }

  fs.mkdirSync(path.dirname(vectorsPath), { recursive: true })
  fs.writeFileSync(vectorsPath, JSON.stringify(vectors, null, 2) + '\n')

  const spec = {
    mjml_version: mjmlVersion,
    components: dumpedComponents,
    dependencies: dumpDependencies(),
    dependency_order: Object.keys(dependencies),
    global_attributes: GLOBAL_ATTRIBUTES,
    component_less_tags: COMPONENT_LESS_TAGS,
    named_colors: namedColors,
    type_strings: typeStrings,
  }

  process.stdout.write(JSON.stringify(spec))
}

main()
