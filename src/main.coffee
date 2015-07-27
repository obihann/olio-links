crypto = require 'crypto'
fs = require 'fs'
hljs = require 'highlight.js'
jade = require 'jade'
less = require 'less'
markdownIt = require 'markdown-it'
moment = require 'moment'
path = require 'path'
querystring = require 'querystring'

# The root directory of this project
ROOT = path.dirname __dirname

cache = {}

# Utility for benchmarking
benchmark =
  start: (message) -> if process.env.BENCHMARK then console.time message
  end: (message) -> if process.env.BENCHMARK then console.timeEnd message

# A function to create ID-safe slugs. If `unique` is passed, then
# unique slugs are returned for the same input. The cache is just
# a plain object where the keys are the sluggified name.
slug = (cache={}, value='', unique=false) ->
  sluggified = value.toLowerCase().replace /[ \t\n\\:/]/g, '-'

  if unique
    while cache[sluggified]
      # Already exists, so let's try to make it unique.
      if sluggified.match /\d+$/
        sluggified = sluggified.replace /\d+$/, (value) ->
          parseInt(value) + 1
      else
        sluggified = sluggified + '-1'

  cache[sluggified] = true

  return sluggified

# A function to highlight snippets of code. lang is optional and
# if given, is used to set the code language. If lang is no-highlight
# then no highlighting is performed.
highlight = (code, lang, subset) ->
  benchmark.start "highlight #{lang}"
  response = switch lang
    when 'no-highlight' then code
    when undefined, null, ''
      hljs.highlightAuto(code, subset).value
    else hljs.highlight(lang, code).value
  benchmark.end "highlight #{lang}"
  return response.trim()

getCached = (key, compiledPath, sources, load, done) ->
  # Already loaded? Just return it!
  if cache[key] then return done null, cache[key]

  # Next, try to check if the compiled path exists and is newer than all of
  # the sources. If so, load the compiled path into the in-memory cache.
  try
    if fs.existsSync compiledPath
      compiledStats = fs.statSync compiledPath

      for source in sources
        sourceStats = fs.statSync source
        if sourceStats.mtime > compiledStats.mtime
          # There is a newer source file, so we ignore the compiled
          # version on disk. It'll be regenerated later.
          return done null

      load compiledPath, (err, item) ->
        if err then return done err

        cache[key] = item
        done null, cache[key]
    else
      done null
  catch err
    done err

getCss = (variables, style, done) ->
  # Get the CSS for the given variables and style. This method caches
  # its output, so subsequent calls will be extremely fast but will
  # not reload potentially changed data from disk.
  # The CSS is generated via a dummy LESS file with imports to the
  # default variables, any custom override variables, and the given
  # layout style. Both variables and style support special values,
  # for example `flatly` might load `styles/variables-flatly.less`.
  # See the `styles` directory for available options.
  key = "css-#{variables}-#{style}"
  if cache[key] then return done null, cache[key]

  # Not cached in memory, but maybe it's already compiled on disk?
  compiledPath = path.join ROOT, 'cache',
    "#{slug undefined, variables}-#{slug undefined, style}.css"

  defaultColorPath = path.join ROOT, 'styles', 'variables-default.less'
  sources = [defaultColorPath]

  customColorPath = null
  if variables isnt 'default'
    customColorPath = path.join ROOT, 'styles', "variables-#{variables}.less"
    if not fs.existsSync customColorPath
      customColorPath = variables
      if not fs.existsSync customColorPath
        return done new Error "#{customColorPath} does not exist!"
    sources.push customColorPath

  stylePath = path.join ROOT, 'styles', "layout-#{style}.less"
  if not fs.existsSync stylePath
    stylePath = style
    if not fs.existsSync stylePath
      return done new Error "#{stylePath} does not exist!"

  sources.push stylePath

  load = (filename, loadDone) ->
    fs.readFile filename, 'utf-8', loadDone

  getCached key, compiledPath, sources, load, (err, css) ->
    if err then return done err
    if css then return done null, css

    # Not cached, so let's create the file.
    tmp = "@import \"#{defaultColorPath}\";\n"
    if customColorPath
      tmp += "@import \"#{customColorPath}\";\n"
    tmp += "@import \"#{stylePath}\";\n"

    benchmark.start 'less-compile'
    less.render tmp, compress: true, (err, result) ->
      if err then return done err

      try
        css = result.css
        fs.writeFileSync compiledPath, css, 'utf-8'
      catch writeErr
        return done writeErr

      benchmark.end 'less-compile'

      cache[key] = css
      done null, cache[key]

getTemplate = (name, done) ->
  # Get the template function for the given path. This will load and
  # compile the template if necessary, and cache it for future use.
  key = "template-#{name}"

  # Check if it is cached in memory. If not, then we'll check the disk.
  if cache[key] then return done null, cache[key]

  # Check if it is compiled on disk and not older than the template file.
  # If not present or outdated, then we'll need to compile it.
  compiledPath = path.join ROOT, 'cache', "#{slug undefined, name}.js"

  load = (filename, loadDone) ->
    loadDone null, require(filename)

  getCached key, compiledPath, [name], load, (err, template) ->
    if err then return done err
    if template then return done null, template

    # We need to compile the template, then cache it. This is interesting
    # because we are compiling to a client-side template, then adding some
    # module-specific code to make it work here. This allows us to save time
    # in the future by just loading the generated javascript function.
    benchmark.start 'jade-compile'
    compileOptions =
      filename: name
      name: 'compiledFunc'
      self: true
      compileDebug: false

    try
      compiled = """
        var jade = require('jade/runtime');
        #{jade.compileFileClient name, compileOptions}
        module.exports = compiledFunc;
      """
    catch compileErr
      return done compileErr

    fs.writeFileSync compiledPath, compiled, 'utf-8'
    benchmark.end 'jade-compile'

    cache[key] = require(compiledPath)
    done null, cache[key]

modifyUriTemplate = (templateUri, parameters) ->
  # Modify a URI template to only include the parameter names from
  # the given parameters. For example:
  # URI template: /pages/{id}{?verbose}
  # Parameters contains a single `id` parameter
  # Output: /pages/{id}
  parameterValidator = (b) ->
    # Compare the names, removing the special `*` operator
    parameters.indexOf(querystring.unescape b.replace(/^\*|\*$/, '')) isnt -1
  parameters = (param.name for param in parameters)
  parameterBlocks = []
  lastIndex = index = 0
  while (index = templateUri.indexOf("{", index)) isnt - 1
    parameterBlocks.push templateUri.substring(lastIndex, index)
    block = {}
    closeIndex = templateUri.indexOf("}", index)
    block.querySet = templateUri.indexOf("{?", index) is index
    block.formSet = templateUri.indexOf("{&", index) is index
    block.reservedSet = templateUri.indexOf("{+", index) is index
    lastIndex = closeIndex + 1
    index++
    index++ if block.querySet
    parameterSet = templateUri.substring(index, closeIndex)
    block.parameters = parameterSet.split(",").filter(parameterValidator)
    parameterBlocks.push block if block.parameters.length
  parameterBlocks.push templateUri.substring(lastIndex, templateUri.length)
  parameterBlocks.reduce((uri, v) ->
    if typeof v is "string"
      uri.push v
    else
      segment = ["{"]
      segment.push "?" if v.querySet
      segment.push "&" if v.formSet
      segment.push "+" if v.reservedSet
      segment.push v.parameters.join()
      segment.push "}"
      uri.push segment.join("")
    uri
  , []).join('')

decorate = (api, md, slugCache) ->
  # Decorate an API Blueprint AST with various pieces of information that
  # will be useful for the theme. Anything that would significantly
  # complicate the Jade template should probably live here instead!

  # Use the slug caching mechanism
  slugify = slug.bind slug, slugCache

  # API overview description
  if api.description
    api.descriptionHtml = md.render api.description
    api.navItems = slugCache._nav
    slugCache._nav = []

  for resourceGroup in api.resourceGroups or []
    # Element ID and link
    resourceGroup.elementId = slugify resourceGroup.name, true
    resourceGroup.elementLink = "##{resourceGroup.elementId}"

    # Description
    if resourceGroup.description
      resourceGroup.descriptionHtml = md.render resourceGroup.description
      resourceGroup.navItems = slugCache._nav
      slugCache._nav = []

    for resource in resourceGroup.resources or []
      # Element ID and link
      resource.elementId = slugify(
        "#{resourceGroup.name}-#{resource.name}", true)
      resource.elementLink = "##{resource.elementId}"

      for action in resource.actions or []
        # Element ID and link
        action.elementId = slugify(
          "#{resourceGroup.name}-#{resource.name}-#{action.method}", true)
        action.elementLink = "##{action.elementId}"

        # Lowercase HTTP method name
        action.methodLower = action.method.toLowerCase()

        # Parameters may be defined on the action or on the
        # parent resource. Resource parameters should be concatenated
        # to the action-specific parameters if set.
        if not action.parameters or not action.parameters.length
          action.parameters = resource.parameters
        else if resource.parameters
          action.parameters = resource.parameters.concat(action.parameters)

        # Remove any duplicates! This gives precedence to the parameters
        # defined on the action.
        knownParams = {}
        newParams = []
        reversed = (action.parameters or []).concat([]).reverse()
        for param in reversed
          if knownParams[param.name] then continue
          knownParams[param.name] = true
          newParams.push param

        action.parameters = newParams.reverse()

        # Set up the action's template URI
        action.uriTemplate = modifyUriTemplate(
          (action.attributes or {}).uriTemplate or resource.uriTemplate or '',
          action.parameters)

        # Examples have a content section only if they have a
        # description, headers, body, or schema.
        for example in action.examples or []
          for name in ['requests', 'responses']
            for item in example[name] or []
              item.hasContent = item.description or \
                                Object.keys(item.headers).length or \
                                item.body or \
                                item.schema

              # If possible, make the body/schema pretty
              try
                if item.body
                  item.body = JSON.stringify(JSON.parse(item.body), null, 2)
                if item.schema
                  item.schema = JSON.stringify(JSON.parse(item.schema), null, 2)
              catch err
                false

# Get the theme's configuration, used by Aglio to present available
# options and confirm that the input blueprint is a supported
# version.
exports.getConfig = ->
  formats: ['1A']
  options: [
    {name: 'variables',
    description: 'Color scheme name or path to custom variables',
    default: 'default'},
    {name: 'condense-nav', description: 'Condense navigation links',
    boolean: true, default: true},
    {name: 'full-width', description: 'Use full window width',
    boolean: true, default: false},
    {name: 'template', description: 'Template name or path to custom template',
    default: 'default'},
    {name: 'style',
    description: 'Layout style name or path to custom stylesheet'}
  ]

# Render the blueprint with the given options using Jade and LESS
exports.render = (input, options, done) ->
  if not done?
    done = options
    options = {}

  # This is purely for backward-compatibility
  if options.condenseNav then options.themeCondenseNav = options.condenseNav
  if options.fullWidth then options.themeFullWidth = options.fullWidth

  # Setup defaults
  options.themeVariables ?= 'default'
  options.themeStyle ?= 'default'
  options.themeTemplate ?= 'default'
  options.themeCondenseNav ?= true
  options.themeFullWidth ?= false

  # Transform built-in layout names to paths
  if options.themeTemplate is 'default'
    options.themeTemplate = path.join ROOT, 'templates', 'index.jade'

  # Setup markdown with code highlighting and smartypants. This also enables
  # automatically inserting permalinks for headers.
  slugCache =
    _nav: []
  md = markdownIt(
    html: true
    linkify: true
    typographer: true
    highlight: highlight
  ).use(require('markdown-it-anchor'),
    slugify: (value) ->
      output = "header-#{slug(slugCache, value, true)}"
      slugCache._nav.push [value, "##{output}"]
      return output
    permalink: true
    permalinkClass: 'permalink')

  # Enable code highlighting for unfenced code blocks
  md.renderer.rules.code_block = md.renderer.rules.fence

  benchmark.start 'decorate'
  decorate input, md, slugCache
  benchmark.end 'decorate'

  benchmark.start 'css-total'
  getCss options.themeVariables, options.themeStyle, (err, css) ->
    if err then return done(err)
    benchmark.end 'css-total'

    locals =
      api: input
      condenseNav: options.themeCondenseNav
      css: css
      fullWidth: options.themeFullWidth
      date: moment
      hash: (value) ->
        crypto.createHash('md5').update(value.toString()).digest('hex')
      highlight: highlight
      markdown: (content) -> md.render content
      slug: slug.bind(slug, slugCache)
      urldec: (value) -> querystring.unescape(value)

    for key, value of options.locals or {}
      locals[key] = value

    benchmark.start 'get-template'
    getTemplate options.themeTemplate, (getTemplateErr, renderer) ->
      if getTemplateErr then return done(getTemplateErr)
      benchmark.end 'get-template'

      benchmark.start 'call-template'
      try html = renderer locals
      catch err then return done err
      benchmark.end 'call-template'
      done null, html
