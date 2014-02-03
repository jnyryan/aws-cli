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
      aws get-metrics [--metrics=<metrics>] [--instances=<ids|region>]
      aws -h | --help | --version

    Options:
      -h --help             Show this screen.
      --version             Show version.
      --access-key-id       Amazon access key id.
      --secret-access-key   Amazon secret access key.
      --id-only             Show only the EC2 instance id. Not tabular.
      <region>              Region ie. us-east-1
      <metrics>             Comma separated metrics
      <ids>                 Comma separated EC2 instance ids.
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
    sparkline = require 'sparkline'
    AWS = require 'aws-sdk'

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
      'DiskReadBytes']

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
      printHeader "#{region} - #{regionName.name}"


    printHeader = (title) ->
      titleLength = title.length
      i=0
      underdash = ""
      while i < titleLength
        underdash += "="
        i++

      console.log "\n\n#{title}".blue
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


    getAllInstances = (callback) ->
      done = 0
      allInstances = []
      getAWSConfig (credentials) ->
        AWS.config.update
          accessKeyId: credentials.AWS_ACCESS_KEY_ID
          secretAccessKey: credentials.AWS_SECRET_KEY

        _.each EC2_regions, (rObj) ->
          AWS.config.update {region: rObj.region}

          new AWS.EC2().describeInstances (error, data) ->
            console.log "get instances ERROR:#{error}".red if error
            _.each data.Reservations, (r) ->
              r = r.Instances[0]
              allInstances.push
                region:rObj.region
                instanceId:r.InstanceId

            if ++done is EC2_regions.length
              instancesStr = JSON.stringify(allInstances)
              fs.writeFile "#{process.cwd()}/.aws-cli-all-instances", instancesStr
              callback instancesStr




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
              if instanceIds.length > 0
                instanceIdsStr += instanceIds.join(',') + ','

              if ++done is regions.length
                instanceIdsStr = instanceIdsStr.substr 0,instanceIdsStr.length-1
                console.log instanceIdsStr

            else
              printRegionHeader region
              table = new Table
                head: ['Name','Instance Id','Instance Type','Status','Launched','Public DNS Name','Public IP Address']
              _.each regionInstances, (i) ->
                table.push [i.Name || '', i.InstanceId || '', i.InstanceType || '', i.State || '', i.LaunchTime || '', i.PublicDnsName || '', i.PublicIpAddress || '']

              console.log table.toString()

####list available EC2 metrics 

    else if opts['metrics']
      table = new Table
        head: ['EC2 Metrics'],

      _.each EC2_metrics, (r) ->
        table.push [r]

      console.log table.toString()

####get speicified metrics for specified instances
    
    else if opts['get-metrics']
    


in order to get metrics you need region of instance

      regions = _.pluck EC2_regions, 'region'

      async.waterfall([
        # get All instances
        (callback) ->
          # check if all instances files is older than 1 hour
          fs.stat "#{process.cwd()}/.aws-cli-all-instances", (err, stats) ->
            if(err || moment(stats.mtime).isBefore(moment().subtract('hour',1)))
              getAllInstances (data) ->
                callback null, JSON.parse(data)
            else
                fs.readFile "#{process.cwd()}/.aws-cli-all-instances", "utf8",(err, data) ->
                  callback null, JSON.parse(data)

        # get the instances and regions to get metrics for
        ,(aI, callback) ->
          getMetricsFor = []
          if opts['--metrics']
            metrics = opts['--metrics'].split(',')
          else
            metrics=EC2_metrics

          if opts['--instances']
            instances = opts['--instances'].split(',')
          else 
            instances = regions

          # get instances based on regions
          _.each instances, (region) ->
            if _.indexOf regions, region != -1
              getMetricsFor = _.union(getMetricsFor, _.where aI, {'region':region})

          _.each instances, (instance) ->
            if typeof instance is 'string'
              getMetricsFor = _.union(getMetricsFor, _.where aI, {'instanceId':instance})

          callback null, getMetricsFor, metrics

        # get the metrics
        ,(getMetricsFor, metrics, callback) ->
          regions = _.unique(_.pluck getMetricsFor, 'region')
          getAWSConfig (credentials) ->

              _.each regions, (region) ->
                AWS.config.update
                  accessKeyId: credentials.AWS_ACCESS_KEY_ID
                  secretAccessKey: credentials.AWS_SECRET_KEY
                  region: region
                instances = _.where getMetricsFor, {'region':region}
                

                _.each instances, (instance) ->
                  _.each metrics, (metric) ->
                    if _.indexOf(EC2_metrics, metric) == -1
                      return false;

                    dimensions = []
                    dimensions.push
                      Name: 'InstanceId'
                      Value: instance.instanceId

                    new AWS.CloudWatch().getMetricStatistics {
                        Dimensions:dimensions
                        Namespace:'AWS/EC2'
                        MetricName:metric
                        StartTime:moment(new Date()).subtract('hour',4).toDate()
                        EndTime:new Date()
                        Period:60
                        Statistics:['Average']
                      }, (error, data) ->
                        if error
                          console.log "ERROR:", error
                          return


                        printHeader region  + ', ' + instance.instanceId + ' - ' + metric

                        if data.Datapoints.length > 0
                          data = data.Datapoints
                          _.forEach data, (d) ->
                            d.UnixTimeStamp = moment(d.Timestamp).unix()

                          data.sort (a,b) ->
                            a.UnixTimeStamp - b.UnixTimeStamp

                          plot = []
                          _.each data, (d) ->
                            plot.push d.Average

                          console.log 'Last 4 hours, every minute'.green
                          console.log sparkline(plot)
                          console.log 'max'.green, _.max(plot).toFixed(2)
                          console.log 'min'.green, _.min(plot).toFixed(2)

                          sum = _.reduce plot, (sum, num) ->
                            sum + num
                          console.log 'avg'.green, (sum/plot.length).toFixed(2)
                        else 
                          console.log 'N/A'
      ])


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
