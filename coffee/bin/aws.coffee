#!/usr/bin/env node

'use strict';
process.title = 'aws';

doc = """
Usage:
  aws regions
  aws instances [--region=<region>]
  aws -h | --help | --version

"""
{docopt} = require 'docopt'
info = require('../package.json');

opts = docopt(doc)

if(opts['--version'])
	console.log 'version', info.version

