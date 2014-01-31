aws-cli
=======

command line interface for AWS


###Set Up
```
npm install . -g
```

###Usage

Usage manual
```
aws -h
```

Set up security credentials.  You only have to do this one time.
```
aws security-credentials --access-key-id=XXXXXXXX --secret-access-key=XXXXXXXXXXXX
```

Get regions
```
aws regions
```

Get all instances
```
aws instnaces
```

Get instances for specific regions
```
aws instnaces us-east-1 us-west-2
```

Get comma separated instance Ids for specific regions
```
aws instnaces us-east-1 us-west-2 --id-only
```

Get list of available metrics
```
aws metrics
```

Get all metrics for all instances
```
aws get-metrics


Get DiskReadBytes and CPUUtilization metrics for instances in us-west-2 and the i-b0607fe7 instance
```
aws get-metrics --instances=us-west-2,i-b0607fe7 --metrics=DiskReadBytes,CPUUtilization
```