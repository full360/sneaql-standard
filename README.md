### SneaQL - Standard Implementation

This repo contains the artifacts used to create the sneaql-standard gem, as well as the public container. 

In most cases you can simply use the public container, but this code is made available so that you can customize your container if desired.

##### Docker Container

In order to run the sneaql you will require the following:

* http store containing the jar file of the database you want to connect to
* http store containing a zip file with your sneaql transform and sneaql.json file
* jdbc connection details for your database

The following example demonstrates the environment variables that need to be passed to the container:

```
export SNEAQL_JDBC_URL=jdbc:redshift://your-cluster.us-west-2.redshift.amazonaws.com:5439/sneaql
export SNEAQL_DB_USER=dbadmin
export SNEAQL_DB_PASS=password
export SNEAQL_JDBC_DRIVER_JAR=http://your-server/RedshiftJDBC4-1.1.6.1006.jar
export SNEAQL_JDBC_DRIVER_CLASS=com.amazon.redshift.jdbc4.Driver
docker run \
-e SNEAQL_JDBC_URL \
-e SNEAQL_DB_USER \
-e SNEAQL_DB_PASS \
-e SNEAQL_JDBC_DRIVER_JAR \
-e SNEAQL_JDBC_DRIVER_CLASS \
full360/sneaql:latest
```

##### Environment Variables

SneaQL accepts the following environment variables:

**Required**

* **SNEAQL_JDBC_URL** - jdbc url of the operating database
* **SNEAQL_DB_USER** - database user
* **SNEAQL_DB_PASS** - database password
* **SNEAQL_JDBC_DRIVER_JAR** - location of the jar file containing the JDBC driver for the operating database.  this value can either be from an http/https store (no authentication) or it can be an s3 path such as s3://your-bucket/RedshiftJDBC4-1.1.6.1006.jar (note that s3 requires that you provide AWS credentials or use an instance profile)
* **SNEAQL_JDBC_DRIVER_CLASS** - java class name of the JDBC driver
* **SNEAQL_JDBC_DRIVER_JAR_MD5** - hex encoded md5 associated with the jar file.  use this as an extra layer of security to prevent intrusion by way of an infected jar file.

**Optional for Container**

* **AWS_SECRET_KEY_ID** - required if using s3 for driver or repos
* **AWS_SECRET_ACCESS_KEY** - required if using s3 for driver or repos
* **AWS_REGION** - required if using an AWS region other than us-east-1
* **SNEAQL_TRANSFORM_CONCURRENCY** - the number of concurrent threads used to process the queue of transforms. defaults to 1.
* **SNEAQL_TRANSFORM_TABLE_NAME** - database table containing the transforms. defaults to sneaql.transforms


##### Gem install

The sneaql-standard ruby gem provides a CLI allowing you to interact with SneaQL.  Currently testing on jruby-9.1.5.0.

If you're not sure how to install jruby... we suggest using rbenv or homebrew (osx).

```
gem install sneaql-standard
```

##### CLI commands

To output a list of commands available in sneaql...

```
sneaql help
```

##### Container Build

```
docker build -t full360/sneaql-standard:0.0.2 .
```
