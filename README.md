aws-cli
=======

command line interface for AWS


###Set Up
npm install

###Usage

Usage manual
```
aws -h
```

Set up security credentials
```
aws security-credentials --access-key-id=XXXXXXXX --secret-access-key=XXXXXXXXXXXX
```

Get regions
```
aws regions
```


Get all instances
```
aws instances
```


Get instances for specific regions
```
aws instances us-east-1 us-west-2
```