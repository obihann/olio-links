# Olio Links 

[![Dependency Status](https://david-dm.org/obihann/aglio.svg)](https://david-dm.org/obihann/aglio)
[![Build Status](http://img.shields.io/travis/obihann/aglio.svg)](https://travis-ci.org/obihann/aglio) 
[![Coverage Status](https://coveralls.io/repos/obihann/aglio/badge.svg?branch=master&service=github)](https://coveralls.io/github/obihann/aglio?branch=master)
[![NPM version](http://img.shields.io/npm/v/aglio-theme-olio-links.svg)](https://www.npmjs.org/package/aglio-theme-olio-links) 
[![License](http://img.shields.io/npm/l/aglio-theme-olio-links.svg)](https://www.npmjs.org/package/aglio-theme-olio-links)

This is *Olio-Links*, a fork of the default theme for [Aglio](https://github.com/danielgtaylor/aglio) with the addition of LINK and UNLINK support. It takes an [API Blueprint](http://apiblueprint.org/) AST and renders it into static HTML. Example use:

```bash
$ sudo npm install -g aglio
$ aglio -i blueprint.apib -o MyAPI.html
```

Theme engines for Aglio are described in more detail in the [Aglio documentation](https://github.com/danielgtaylor/aglio#customizing-output).

## Design Philosophy
Olio is designed from the ground up to be both **fast** and **extensible** while maintaining backward compatibility with most of the original Aglio theme. It uses the following technologies:

* [Less](http://lesscss.org/) to produce CSS
* [Markdown-it](https://github.com/markdown-it/markdown-it#readme) to render Markdown
* [Jade](http://jade-lang.com/) to produce HTML
* [Highlight.js](https://highlightjs.org/) to highlight code snippets

For backward compatibility, Jade templates can continue to use inline Stylus and CoffeeScript.

## Theme Options

Olio comes with a handful of configurable theme options. These are set via the `--theme-XXX` parameter, where `XXX` is one of the following:

Name           | Description
-------------- | ------------------
`condense-nav` | Whether to condense nagivation for resources with only a single action (default is `true`).
`full-width`   | Whether to use the full page width or a responsive layout (default is responsive).
`style`        | LESS or CSS to control the layout and style of the document using the variables from below. Can be a path to your own file or one of the following presets: `default`.
`template`     | Jade template to render HTML. Can be a path to your own file or one of the following presets: `default`.
`variables`    | LESS variables that control theme colors, fonts, and spacing. Can be a path to your own file or one of the following presets: `default`, `flatly`, `slate`, `cyborg`.

**Note**: When using this theme programmatically, these options are cased like you would expect in Javascript: `--theme-full-width` becomes `options.themeFullWidth`.

## Benchmark

Olio makes use of aggressive caching whenever it can, which means that rendering HTML can be blazing fast. Benchmark taken on a 2015 Macbook Pro via `BENCHMARK=1 aglio -i example.apib -o example.html`:

Step                | Cached | No cache
------------------- | ------:| --------:
Parse API Blueprint |   44ms |  44ms
Get CSS             |    1ms |  49ms
Get template        |    2ms | 102ms
Call template       |   28ms |  32ms
**Total time**      |   75ms | 227ms

License
=======
Copyright &copy; 2015 Jeffrey Hann 

http://dgt.mit-license.org/
