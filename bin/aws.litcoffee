#AWS CLI

    #!/usr/bin/env coffee

    'use strict';
    process.title = 'aws'

## define usage options

    doc = """
    Usage:
      aws regions
      aws security-credentials --access-key-id=<accessKeyId> --secret-access-key=<secretAccessKey>
      aws instances [<region>...] [--id-only]  
      aws metrics
      aws get-metrics <id>...
      aws -h | --help | --version

    Options:
      -h --help             Show this screen.
      --version             Show version.
      --access-key-id       Amazon access key id.
      --secret-access-key   Amazon secret access key.
      --id-only             Show only the EC2 instance id. Not tabular.
      <region>              Region ie. us-east-1
      <id>                  EC2 instance id.
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
    inspect = require 'inspect'
    AWS = require('aws-sdk')

    info = require '../package.json'
    opts = docopt(doc)

###Reference Data
####Region info from [http://docs.aws.amazon.com/general/latest/gr/rande.html](http://docs.aws.amazon.com/general/latest/gr/rande.html)

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

####EC2 Metrics

    EC2_metrics = [ 'CPUUtilization',
      'DiskWriteBytes',
      'DiskReadOps',
      'NetworkOut',
      'NetworkIn',
      'DiskWriteOps',
      'StatusCheckFailed_System',
      'DiskReadBytes',
      'StatusCheckFailed_Instance',
      'StatusCheckFailed']

###Helper functions

    getAWSConfig = (callback) ->
      fs.readFile "#{process.cwd()}/.aws-cli", "utf8",(err, data) ->
          if err
            console.log 'Set your access-key-id and secret-access-key.'.red
            console.log 'aws security-credentials --access-key-id=<accessKeyId> --secret-access-key=<secretAccessKey>'.yellow
          else
            sc = data.split(' ')
            callback {'AWS_ACCESS_KEY_ID':sc[0], "AWS_SECRET_KEY":sc[1]}

    printRegionHeader = (region) ->
      regionName = _.find EC2_regions, (r) ->
        r.region is region

      titleLength = "#{region} - #{regionName.name}".length
      i=0
      underdash = ""
      while i < titleLength
        underdash += "="
        i++

      console.log "\n\n#{region} - #{regionName.name}".blue
      console.log "#{underdash}".blue

    getRegions = (opts) ->
      if !opts['<region>'] or opts['<region>'].length is 0
        regions = _.pluck EC2_regions, 'region'
      else 
        regions = opts['<region>']
        if (_.intersection(regions, _.pluck(EC2_regions, 'region'))).length isnt regions.length
          console.log 'Error: Unrecognized region'.red
          return false

      regions


###Executing the CLI options

####version

    if opts['--version']
      console.log "version: #{info.version}".green

####set aws sercurity credentials. You only do this once

    else if opts['security-credentials']
      key = opts['--access-key-id']
      secret = opts['--secret-access-key']
      fs.writeFile "#{process.cwd()}/.aws-cli", "#{key} #{secret}", (err) ->
        if err
          console.log 'error: #{err}'.red
        else
          console.log 'security credentials saved'.green

####list regions

    else if opts['regions']
      table = new Table
        head: ['region', 'region name'],

      _.each EC2_regions, (r) ->
        table.push [r.region, r.name]

      console.log table.toString()

####list instances
  
    else if opts['instances']
      done = 0
      instanceIdsStr = ""

      regions = getRegions(opts)
      if !regions 
        return

      getAWSConfig (credentials) ->
        AWS.config.update
          accessKeyId: credentials.AWS_ACCESS_KEY_ID
          secretAccessKey: credentials.AWS_SECRET_KEY

        _.each regions, (region) ->
          AWS.config.update {region: region}

          new AWS.EC2().describeInstances (error, data) ->
            console.log "get instances ERROR:#{error}".red if error
            regionInstances = []
            instanceIds = []

            _.each data.Reservations, (r) ->
              r = r.Instances[0]

only print out instanceIds

              if opts['--id-only']
                instanceIds.push r.InstanceId

or print all instance details

              else
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
                  LaunchTime:moment(r.LaunchTime).fromNow()
                  Placement:r.Placement
                  Name:instanceName
                  Tags:r.Tags
                  State:r.State.Name
                  PublicDnsName:r.PublicDnsName
                  PublicIpAddress:r.PublicIpAddress
                }
                regionInstances.push(instance)

            if opts['--id-only']
              instanceIdsStr += instanceIds.join(' ')
              if ++done is regions.length
                console.log instanceIdsStr

            else
              printRegionHeader region
              table = new Table
                head: ['Name','Instance Id','Instance Type','Status','Launched','Public DNS Name','Public IP Address']
              _.each regionInstances, (i) ->
                table.push [i.Name || '', i.InstanceId || '', i.InstanceType || '', i.State || '', i.LaunchTime || '', i.PublicDnsName || '', i.PublicIpAddress || '']

              console.log table.toString()

####list metrics 

    if opts['metrics']
      table = new Table
        head: ['Metrics name'],

      _.each EC2_metrics, (r) ->
        table.push [r]

      console.log table.toString()




### Misc.

commented out code to get list of available metrics for EC2 instances 

      # regionMetrics = []
      # regions = EC2_regions
      # getAWSConfig (credentials) ->
      #   AWS.config.update
      #     accessKeyId: credentials.AWS_ACCESS_KEY_ID
      #     secretAccessKey: credentials.AWS_SECRET_KEY

      #   _.each regions, (region) ->
      #     AWS.config.update {region: region}

      #     new AWS.CloudWatch().listMetrics (error, data) ->
      #       console.log "get metrics error: #{error}" if error
            

      #       fs.writeFile "#{process.cwd()}/metrics-test", JSON.stringify(data.Metrics)

      #       _.each data.Metrics, (m) ->
      #         if m.Namespace is 'AWS/EC2' and m.Dimensions[0].Name is 'InstanceId'
      #           regionMetrics.push m

      #       printRegionHeader region
      #       console.log _.unique(_.pluck(regionMetrics, 'MetricName'))


aws.js sibling file used to shim coffee-script (gets overwritten sometimes)

    # #!/usr/bin/env node
    # require('coffee-script')
    # require('./aws.litcoffee')
