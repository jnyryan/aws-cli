#AWS CLI

    #!/usr/bin/env coffee

    'use strict';
    process.title = 'aws'

## define usage options

    doc = """
    Usage:
      aws regions
      aws security-credentials --access-key-id=<accessKeyId> --secret-access-key=<secretAccessKey>
      aws instances [<region>...]
      aws -h | --help | --version

    """

    {docopt} = require 'docopt'
    Table = require 'cli-table'
    colors = require 'colors'
    _ = require 'lodash'
    fs = require 'fs'
    path = require 'path'
    request = require 'request'
    async = require 'async'
    moment = require 'moment'
    AWS = require('aws-sdk')

    info = require '../package.json'
    opts = docopt(doc)


region info from [http://docs.aws.amazon.com/general/latest/gr/rande.html](http://docs.aws.amazon.com/general/latest/gr/rande.html)

    EC2_regions= [
      {"region": "us-east-1", name:"US East (Northern Virginia)"},
      {"region": "us-west-2", name:"US West (Oregon)"},
      {"region": "us-west-1", name:"US West (Northern California)"},
      {"region": "eu-west-1", name:"EU (Ireland)"},
      {"region": "ap-southeast-1", name:"Asia Pacific (Singapore)"},
      {"region": "ap-southeast-2", name:"Asia Pacific (Sydney)"},
      {"region": "ap-northeast-1", name:"Asia Pacific (Tokyo)"},
      {"region": "sa-east-1", name:"South America (Sao Paulo)"}
    ]

###Helper functions

    getAWSConfig = (callback) ->
      fs.readFile "#{process.cwd()}/.aws-cli", "utf8",(err, data) ->
          if err
            console.log 'getAWSConfig error: #{err}'.red
          else
            sc = data.split(' ')
            callback {'AWS_ACCESS_KEY_ID':sc[0], "AWS_SECRET_KEY":sc[1]}


###Executing the CLI options

version

    if opts['--version']
      console.log "version: #{info.version}".green

set aws sercurity credentials. You should only have to do this once

    else if opts['security-credentials']
      key = opts['--access-key-id']
      secret = opts['--secret-access-key']
      fs.writeFile "#{process.cwd()}/.aws-cli", "#{key} #{secret}", (err) ->
        if err
          console.log 'error: #{err}'.red
        else
          console.log 'security credentials saved'.green

regions

    else if opts['regions']
      table = new Table
        head: ['region', 'region name'],

      _.each EC2_regions, (r) ->
        table.push [r.region, r.name]

      console.log table.toString()

get instances

    else if opts['instances']
      if opts['<region>'].length is 0
        regions = _.pluck EC2_regions, 'region'
      else 
        regions = opts['<region>']

      getAWSConfig (credentials) ->
        instances = [];

        AWS.config.update
          accessKeyId: credentials.AWS_ACCESS_KEY_ID
          secretAccessKey: credentials.AWS_SECRET_KEY

        _.each regions, (region) ->
          AWS.config.update {region: region}

          new AWS.EC2().describeInstances (error, data) ->
            if error
              console.log(error)
            else
              regionInstances = [];
              _.each data.Reservations, (r) ->
                r = r.Instances[0]

                instanceName = ""
                _.forEach r.Tags, (t) ->
                  if t.Key is "Name"
                    instanceName = t.Value
                    return false

                instance = {
                  ImageId:r.ImageId
                  InstanceId:r.InstanceId
                  InstanceType:r.InstanceType
                  KeyName:r.KeyName
                  LaunchTime:moment(r.LaunchTime).utc().valueOf()
                  Placement:r.Placement
                  Name:instanceName
                  Tags:r.Tags
                  State:r.State.Name
                  PublicDnsName:r.PublicDnsName
                  PublicIpAddress:r.PublicIpAddress
                }
                regionInstances.push(instance)

              instances.push({region:region, instances:regionInstances})
              if instances.length is regions.length
                instances  = _.sortBy instances, (i) ->
                  i.instances.length

                _.each instances.reverse(), (ri) ->
                  console.log '\n\n===================================================='.blue
                  console.log ri.region.blue
                  
                  table = new Table
                    head: ['Name','Instance Id','Instance Type','Status','Launched','Public DNS Name','Public IP Address']
                  _.each ri.instances, (i) ->
                    table.push [i.Name || '', i.InstanceId || '', i.InstanceType || '', i.State || '', i.LaunchTime || '', i.PublicDnsName || '', i.PublicIpAddress || '']

                  console.log table.toString()






    # #!/usr/bin/env node
    # require('coffee-script')
    # require('./aws.litcoffee')
