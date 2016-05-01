# Overview

I have an analysis that (maybe) is not well suited for standard High Performance Computing (HPC), but possibly would work with a map/reduce framework. Toward this goal, I am trying to figure out how to use a Spark cluster on TACC, specifically on Wrangler.


## Starting Hadoop Cluster on TACC
The first thing I went looking for is a spark installation, and so I tried:

      module spider spark

and then was able to find spark, and load like:

      module load spark-paths/1.2.0

I didn't see any "spark" executable, so I started to search my environmental variables and found one called `$SPARK_HOME` which pointed to `/usr/lib/spark`. Unfortunately when I tried to list the files, nothing showed up. I then inferred that it must be the case that these paths are only available on computational nodes (and not a head/login node). I then got myself a node:

      idev -m 60

and received an error about loading the spark-paths. Why? They were already loaded! In this case, I found a nice set of things to play with in my $SPARK_HOME. I quickly found an example python application and made a [modified version](../word_count.py) and I ran it like:

      /usr/lib/spark/bin/pyspark word_count.py

and immediately I started to get a bunch of Java errors. The one that caught my eye was something to the effect of a path not found, but the start of the path was an address with hdfs://. I looked this up online, and realized that hdfs is a special file system ([made by Google!](http://research.google.com/archive/gfs.html)) and ho! I needed to use hadoop to work with it. The way I think about this hadoop file system (called `hadoop fs`) is that it has many of the same commands as standard bash, and the general idea is that you move files between your local and hdfs. It then occurred to me that likely I needed to make a reservation on the [Wrangler Data Portal](https://portal.wrangler.tacc.utexas.edu/) to generate my own little hadoop file system, and was able to make a request! Back on Wrangler, I could see the status of my request with:

      scontrol show reservations

and then when it was active, I could connect to it by obtaining the name (either from the data portal or screen output from scontrol) like:

      idev -r hadoop+Analysis_Lonestar+1457 -m 700

Note that when TACC kicks you off for some period of inactivity, you can see your running idev session with:

      squeue -u vsochat
      login1.wrangler(1)$ squeue -u vsochat
             JOBID   PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
             13870      hadoop idv91334  vsochat  R    1:18:45      1 c252-118

and then reconnect to it with ssh:

      ssh -XY vsochat@c252-118

Once connected to my reservation I was able to do `which hadoop` to see that it was installed, and then when I typed `hadoop fs` I could see all of the [command options](http://hadoop.apache.org/docs/r2.5.2/hadoop-project-dist/hadoop-common/FileSystemShell.html). I found a good definition of HDFS [here](https://developer.yahoo.com/hadoop/tutorial/module2.html):

>> HDFS, the Hadoop Distributed File System, is a distributed file system designed to hold very large amounts of data (terabytes or even petabytes), and provide high-throughput access to this information. Files are stored in a redundant fashion across multiple machines to ensure their durability to failure and high availability to very parallel applications. This module introduces the design of this distributed file system and instructions on how to operate it.


#### Hadoop File System Commands

The first thing I wanted to do was just see the file system directories. It turns out, HDFS is running in a separate namespace that is isolated from local files, and this is the address that I saw in the original error message. I didn't know what I was doing, so I found the help command:

      hadoop fs -help

Phew! Documentation! You can do that with:

      hadoop fs -ls /

      Found 3 items
      drwxrwxrwx   - mapred hadoop          0 2016-04-30 21:42 /tmp
      drwxr-xr-x   - hdfs   hadoop          0 2016-04-30 19:47 /user
      drwxrwxr-x   - hdfs   hadoop          0 2016-04-30 19:43 /var

Note that if you don't have the slash (indicative of the base path), you won't see anything! Next I wanted to try adding a file. From my base directory where I created a text file with Crime and Punishment, I did:

      hadoop fs -put crimeandpunishment.txt

If you try to put a file that is already there, it gives you an error:

      hadoop fs -put crimeandpunishment.txt 
      put: `crimeandpunishment.txt': File exists

I believe `put` is equivalent syntax and functionality to the command `-copyFromLocal`. Note that you can also retrieve a file from the hadoop file system with get, and if the file already exists, you get an equivalent error:

      hadoop fs -get crimeandpunishment.txt 
      get: `crimeandpunishment.txt': File exists

The next thing that makes sense to do is create a directory to put data in. Let's call it DATA.

      hadoop fs -mkdir DATA

This by default will be created in my home folder. The way they have set it up on TACC, the "user" folder has everyone's user name in it, and this is considered the home folder. To see this folder with the new directory, I need to change the ls command a bit:

      hadoop fs -ls /user/vsochat
      Found 2 items
      drwxr-xr-x   - vsochat hadoop          0 2016-05-01 15:06 /user/vsochat/DATA
      -rw-r--r--   2 vsochat hadoop    1154664 2016-04-30 21:38 /user/vsochat/crimeandpunishment.txt

###### Moving, Viewing, and Renaming Files
This is good, but oups, maybe I should have put crimeandpunishment.txt into the DATA folder? Let's see if we can move it!

      hadoop fs -mv /user/vsochat/crimeandpunishment.txt /user/vsochat/DATA
      hadoop fs -ls /user/vsochat/DATA
      Found 1 items
      -rw-r--r--   2 vsochat hadoop    1154664 2016-04-30 21:38 /user/vsochat/DATA/crimeandpunishment.txt

Success! I found some other cool commands too. We can check the status of a file, look at the file (eg cat/tail)

      hadoop fs -stat /user/vsochat/DATA/crimeandpunishment.txt 
      2016-05-01 02:38:39

      hadoop fs -tail /user/vsochat/DATA/crimeandpunishment.txt
      hadoop fs -cat /user/vsochat/DATA/crimeandpunishment.txt

You can also count the number of files at a path:

      hadoop fs -count /user/vsochat/DATA
           1            1            1154664 /user/vsochat/DATA


What do the different things mean? I believe we are looking at 1) the count, 2) the number of replicas, 3) the file size?, and 4) the location

###### Replication Factor and Block Size
There is something called `replication factor` which gets at the number of duplicated blocks (of a file) distributed across the cluster. I haven't run anything yet so it's not totally intuitive what this means, but I found a command for adjusted the replication factor of a file:

      -setrep [-R] [-w] <rep> <path> ... :
        Set the replication level of a file. If <path> is a directory then the command
        recursively changes the replication factor of all files under the directory tree
        rooted at <path>.
                                                                                 
        -w  It requests that the command waits for the replication to complete. This   
            can potentially take a very long time.                                     
        -R  It is accepted for backwards compatibility. It has no effect. 

Meaning I could do something like:

      hadoop fs –setrep –w 3 /user/vsochat/DATA/crimeandpunishment.txt

to set the replication factor to 3. Note that you can set a global replication factor for an entire cluster in the hadoop config file, which I'm not sure I have access to (but haven't looked yet). The default is 3.

Block size is defined as ([from](http://princetonits.com/blog/technology/how-to-configure-replication-factor-and-block-size-for-hdfs/)):

>> The block size setting is used by HDFS to divide files into blocks and then distribute those blocks across the cluster. For example, if a cluster is using a block size of 64 MB, and a 128-MB text file was put in to HDFS, HDFS would split the file into two blocks (128 MB/64 MB) and distribute the two chunks to the data nodes in the cluster.

What is blowing my mind is the idea that a file can be "stored" on multiple different machines. This means that you can have a single file larger than any single machine! This also means that if a machine goes kaput you could lose part of the file, but this is guarded against by redundancy (as mentioned above, the default replication factor of files is 3). The only exception is meta data about files and folders, it looks like this is stored on one node called the NameNode. When you do stuff with a file, it's this node that is contacted first, and it knows all the blocks that the relevant file(s) are stored on. The block size setting also looks like it is set in the global config, but you can do on the command line as well:

      hadoop fs -Ddfs.block.size=1048576

I'm not entirey sure the reasons I'd want to do this, so I'm not going to mess with it for now.

## Health of HDFS
I found a deprecated command to check if a cluster is healthy:

    hadoop fsck /users/vsochat

and the updated command is:

      hdfs fsck /user/vsochat
      Connecting to namenode via http://c252-118.wrangler.tacc.utexas.edu:50070
      FSCK started by vsochat (auth:SIMPLE) from /129.114.58.161 for path /user/vsochat at Sun May 01 16:06:43 CDT 2016
      .
      /user/vsochat/DATA/crimeandpunishment.txt:  Under replicated BP-1399245593-129.114.58.161-1462063375858:blk_1073741825_1001. Target Replicas is 2 but found 1 replica(s).
      Status: HEALTHY
       Total size:	1154664 B
       Total dirs:	2
       Total files:	1
       Total symlinks:		0
       Total blocks (validated):	1 (avg. block size 1154664 B)
       Minimally replicated blocks:	1 (100.0 %)
       Over-replicated blocks:	0 (0.0 %)
       Under-replicated blocks:	1 (100.0 %)
       Mis-replicated blocks:		0 (0.0 %)
       Default replication factor:	2
       Average block replication:	1.0
       Corrupt blocks:		0
       Missing replicas:		1 (50.0 %)
       Number of data-nodes:		1
       Number of racks:		1
      FSCK ended at Sun May 01 16:06:43 CDT 2016 in 0 milliseconds

      The filesystem under path '/user/vsochat' is HEALTHY

The reason my files are under replicated is likely because I only specified two nodes, meaning I have a NameNode and one other. I wonder what would happen if I tried to increase the replication for the file?

      hadoop fs -setrep 3 /user/vsochat/DATA/crimeandpunishment.txt
      Replication 3 set: /user/vsochat/DATA/crimeandpunishment.txt

Interesting, it tells me that the target is 3, but I only have 1, and that there are missing replicas... again likely because my cluster is tiny!

      hdfs fsck /user/vsochat/ 
      ...
      /user/vsochat/DATA/crimeandpunishment.txt:  Under replicated BP-1399245593-129.114.58.161-1462063375858:blk_1073741825_1001. Target Replicas is 3 but found 1 replica(s).
      ...
      Missing replicas:		2 (66.666664 %)
      

## Running Programs

#### Java

Now let's try to run some jobs! First let's try from an example jar. Java isn't my language of choice, but I found this on TACC resources, and seems reasonable to give it a go. Note that these jar files are stored on the local file system, they have code that will work with the cluster, and  work with the data is on the hadoop cluster. and Here we will count words in crimeandpunishment.txt

      hadoop jar /usr/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar wordcount -D mapred.map.tasks=96 -D mapred.reduce.tasks=24 DATA/crimeandpunishment.txt cap_text_wc

Hooo we have things happening!

      16/05/01 16:16:22 INFO client.RMProxy: Connecting to ResourceManager at c252-118.wrangler.tacc.utexas.edu/129.114.58.161:8032
      16/05/01 16:16:22 INFO input.FileInputFormat: Total input paths to process : 1
      16/05/01 16:16:22 INFO mapreduce.JobSubmitter: number of splits:1
      16/05/01 16:16:22 INFO Configuration.deprecation: mapred.map.tasks is deprecated. Instead, use mapreduce.job.maps
      16/05/01 16:16:22 INFO Configuration.deprecation: mapred.reduce.tasks is deprecated. Instead, use mapreduce.job.reduces
      16/05/01 16:16:23 INFO mapreduce.JobSubmitter: Submitting tokens for job: job_1462063386551_0001
      16/05/01 16:16:23 INFO impl.YarnClientImpl: Submitted application application_1462063386551_0001
      16/05/01 16:16:23 INFO mapreduce.Job: The url to track the job: http://c252-118.wrangler.tacc.utexas.edu:8088/proxy/application_1462063386551_0001/
      16/05/01 16:16:23 INFO mapreduce.Job: Running job: job_1462063386551_0001
      16/05/01 16:16:31 INFO mapreduce.Job: Job job_1462063386551_0001 running in uber mode : false
      16/05/01 16:16:31 INFO mapreduce.Job:  map 0% reduce 0%
      16/05/01 16:16:36 INFO mapreduce.Job:  map 100% reduce 0%
      16/05/01 16:16:41 INFO mapreduce.Job:  map 100% reduce 8%
      16/05/01 16:16:42 INFO mapreduce.Job:  map 100% reduce 13%
      16/05/01 16:16:43 INFO mapreduce.Job:  map 100% reduce 17%
      16/05/01 16:16:44 INFO mapreduce.Job:  map 100% reduce 21%
      16/05/01 16:16:45 INFO mapreduce.Job:  map 100% reduce 25%
      16/05/01 16:16:46 INFO mapreduce.Job:  map 100% reduce 29%
      16/05/01 16:16:47 INFO mapreduce.Job:  map 100% reduce 33%
      16/05/01 16:16:48 INFO mapreduce.Job:  map 100% reduce 42%
      16/05/01 16:16:49 INFO mapreduce.Job:  map 100% reduce 46%
      16/05/01 16:16:50 INFO mapreduce.Job:  map 100% reduce 54%
      16/05/01 16:16:51 INFO mapreduce.Job:  map 100% reduce 63%
      16/05/01 16:16:52 INFO mapreduce.Job:  map 100% reduce 71%
      16/05/01 16:16:53 INFO mapreduce.Job:  map 100% reduce 79%
      16/05/01 16:16:54 INFO mapreduce.Job:  map 100% reduce 88%
      16/05/01 16:16:55 INFO mapreduce.Job:  map 100% reduce 96%
      16/05/01 16:16:56 INFO mapreduce.Job:  map 100% reduce 100%
      16/05/01 16:16:56 INFO mapreduce.Job: Job job_1462063386551_0001 completed successfully
      16/05/01 16:16:56 INFO mapreduce.Job: Counters: 49
	File System Counters
		FILE: Number of bytes read=329998
		FILE: Number of bytes written=3292867
		FILE: Number of read operations=0
		FILE: Number of large read operations=0
		FILE: Number of write operations=0
		HDFS: Number of bytes read=1154815
		HDFS: Number of bytes written=242599
		HDFS: Number of read operations=75
		HDFS: Number of large read operations=0
		HDFS: Number of write operations=48
	Job Counters 
		Launched map tasks=1
		Launched reduce tasks=24
		Data-local map tasks=1
		Total time spent by all maps in occupied slots (ms)=5720
		Total time spent by all reduces in occupied slots (ms)=218624
		Total time spent by all map tasks (ms)=2860
		Total time spent by all reduce tasks (ms)=54656
		Total vcore-seconds taken by all map tasks=2860
		Total vcore-seconds taken by all reduce tasks=54656
		Total megabyte-seconds taken by all map tasks=11714560
		Total megabyte-seconds taken by all reduce tasks=447741952
	Map-Reduce Framework
		Map input records=22456
		Map output records=206525
		Map output bytes=1976334
		Map output materialized bytes=329998
		Input split bytes=151
		Combine input records=206525
		Combine output records=22390
		Reduce input groups=22390
		Reduce shuffle bytes=329998
		Reduce input records=22390
		Reduce output records=22390
		Spilled Records=44780
		Shuffled Maps =24
		Failed Shuffles=0
		Merged Map outputs=24
		GC time elapsed (ms)=3072
		CPU time spent (ms)=47700
		Physical memory (bytes) snapshot=10315898880
		Virtual memory (bytes) snapshot=258443550720
		Total committed heap usage (bytes)=53245894656
	Shuffle Errors
		BAD_ID=0
		CONNECTION=0
		IO_ERROR=0
		WRONG_LENGTH=0
		WRONG_MAP=0
		WRONG_REDUCE=0
	File Input Format Counters 
		Bytes Read=1154664
	File Output Format Counters 
		Bytes Written=242599

I tried looking into the jar file, but all I can see are compiled class files, so I can also assume that the code assumes paths originating from the running users home directory (e.g., /user/vsochat) since I could specify the crimeandpunishment.txt just as being at `DATA/crimeandpunishment.txt`. Actually, let's not assume things - I found a .java file to take a look at how the cluster is configured. First, it looks like we import functions from apache.hadoop.*:

      import java.io.IOException;
      import java.util.StringTokenizer;

      import org.apache.hadoop.conf.Configuration;
      import org.apache.hadoop.fs.Path;
      import org.apache.hadoop.io.IntWritable;
      import org.apache.hadoop.io.Text;
      import org.apache.hadoop.mapreduce.Job;
      import org.apache.hadoop.mapreduce.Mapper;
      import org.apache.hadoop.mapreduce.Reducer;
      import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
      import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;

If I remember java, the public static void main is running the show, so let's look there to see how the cluster is configured:

      public static void main(String[] args) throws Exception {
          Configuration conf = new Configuration();
          Job job = Job.getInstance(conf, "word count");
          job.setJarByClass(WordCount.class);
          job.setMapperClass(TokenizerMapper.class);
          job.setCombinerClass(IntSumReducer.class);
          job.setReducerClass(IntSumReducer.class);
          job.setOutputKeyClass(Text.class);
          job.setOutputValueClass(IntWritable.class);
          FileInputFormat.addInputPath(job, new Path(args[0]));
          FileOutputFormat.setOutputPath(job, new Path(args[1]));
          System.exit(job.waitForCompletion(true) ? 0 : 1);
      }

We basically create a new configuration, point it to another class  (WordCount.class, the original file I tried looking at and duh, it's compiled), and then set different functions for mapping and reducing, and the input file is the first command argument (as we saw above) and the output the second. I think it must be the case that when I run the hadoop command, this by default "knows" it is relative to my hdfs, and the paths are expected to be there. I'm satisfied with this level of "understanding" for now. Let's look at the result file! Is it in my data folder?

      hadoop fs -ls /user/vsochat/DATA

Nope. Didn't see it. It must be that the output folder/file is also relative to the user home, so let's look there:

      hadoop fs -ls /user/vsochat
      Found 2 items
      drwxr-xr-x   - vsochat hadoop          0 2016-05-01 15:14 /user/vsochat/DATA
      drwxr-xr-x   - vsochat hadoop          0 2016-05-01 16:16 /user/vsochat/cap_text_wc

Ah, it's a folder! Found it! How many files are inside?

      hadoop fs -ls /user/vsochat/cap_text_wc | wc -l
      26

      hadoop fs -cat cap_text_wc/part-r-00000

      ...

      whispered	35
      white	33
      who?"	1
      whom	61
      ...
 
It looks like we would have needed to do some original parsing to deal with punctuation, etc., but it worked! I'm going to move away from Java (don't really want to use Java...) and try programs in Python next.

#### Spark

Let's try something with spark. I remember that I saw something called "run-example" that produced some spectacular errors when I was trying to run it without a hadoop file system. Does it work now? 

      /usr/lib/spark/bin/run-example

      Usage: ./bin/run-example <example-class> [example-args]
        - set MASTER=XX to use a specific master
        - can use abbreviated example class name relative to com.apache.spark.examples
           (e.g. SparkPi, mllib.LinearRegression, streaming.KinesisWordCountASL)

Let's try LinearRegression. I was watching a video online and they mentioned something about MLLib that there are a crapton of machine learning functions. There is also one called SparkML that seems to be popular.

      /usr/lib/spark/bin/run-example mllib.LinearRegression

      LinearRegression: an example app for linear regression.
      Usage: LinearRegression [options] <input>

        --numIterations <value>
              number of iterations
        --stepSize <value>
              initial step size, default: 1.0
        --regType <value>
              regularization type (NONE,L1,L2), default: L2
        --regParam <value>
              regularization parameter, default: 0.01
        <input>
              input paths to labeled examples in LIBSVM format

      For example, the following command runs this app on a synthetic dataset:

       bin/spark-submit --class org.apache.spark.examples.mllib.LinearRegression \
        examples/target/scala-*/spark-examples-*.jar \
        data/mllib/sample_linear_regression_data.txt

I couldn't find this sample data file on TACC, but I found it online and added it to [data/sample_linear_regression_data.txt](data/sample_linear_regression_data.txt). Let's add this file to hdfs:

      hadoop fs -put data/sample_linear_regression_data.txt /user/vsochat/DATA
      hadoop fs -ls /user/vsochat/DATA
      Found 2 items
      -rw-r--r--   3 vsochat hadoop    1154664 2016-04-30 21:38 /user/vsochat/DATA/crimeandpunishment.txt
      -rw-r--r--   2 vsochat hadoop     119069 2016-05-01 16:57 /user/vsochat/DATA/sample_linear_regression_data.txt

There it is! Let's try running linear regression. We will need to change some of the paths to coincide with what actually exists on TACC.

        /usr/lib/spark/bin/spark-submit --class org.apache.spark.examples.mllib.LinearRegression \
        /usr/lib/spark/examples/lib/spark-examples-1.5.0-cdh5.5.1-hadoop2.6.0-cdh5.5.1.jar \
        DATA/sample_linear_regression_data.txt

Looks like some of the BLAS libraries failed, but we still got a result!

      16/05/01 16:59:06 INFO spark.SparkContext: Running Spark version 1.5.0-cdh5.5.1
      16/05/01 16:59:06 WARN util.NativeCodeLoader: Unable to load native-hadoop library for your platform... using builtin-java classes where applicable
      16/05/01 16:59:07 INFO spark.SecurityManager: Changing view acls to: vsochat
      16/05/01 16:59:07 INFO spark.SecurityManager: Changing modify acls to: vsochat
      16/05/01 16:59:07 INFO spark.SecurityManager: SecurityManager: authentication disabled; ui acls disabled; users with view permissions: Set(vsochat); users with modify permissions: Set(vsochat)
      16/05/01 16:59:07 INFO slf4j.Slf4jLogger: Slf4jLogger started
      16/05/01 16:59:07 INFO Remoting: Starting remoting
      16/05/01 16:59:07 INFO Remoting: Remoting started; listening on addresses :[akka.tcp://sparkDriver@129.114.58.161:59143]
      16/05/01 16:59:07 INFO Remoting: Remoting now listens on addresses: [akka.tcp://sparkDriver@129.114.58.161:59143]
      16/05/01 16:59:07 INFO util.Utils: Successfully started service 'sparkDriver' on port 59143.
      16/05/01 16:59:07 INFO spark.SparkEnv: Registering MapOutputTracker
      16/05/01 16:59:07 INFO spark.SparkEnv: Registering BlockManagerMaster
      16/05/01 16:59:08 INFO storage.DiskBlockManager: Created local directory at /tmp/blockmgr-96cfde10-ad59-4f02-af32-1b18d295f00d
      16/05/01 16:59:08 INFO storage.MemoryStore: MemoryStore started with capacity 530.0 MB
      16/05/01 16:59:08 INFO spark.HttpFileServer: HTTP File server directory is /tmp/spark-b6e497c7-9c2e-49d2-8da1-6a27f7c2db05/httpd-ceded285-cdd6-4ccd-8640-77f6d7d45bda
      16/05/01 16:59:08 INFO spark.HttpServer: Starting HTTP Server
      16/05/01 16:59:08 INFO server.Server: jetty-8.y.z-SNAPSHOT
      16/05/01 16:59:08 INFO server.AbstractConnector: Started SocketConnector@0.0.0.0:34623
      16/05/01 16:59:08 INFO util.Utils: Successfully started service 'HTTP file server' on port 34623.
      16/05/01 16:59:08 INFO spark.SparkEnv: Registering OutputCommitCoordinator
      16/05/01 16:59:08 INFO server.Server: jetty-8.y.z-SNAPSHOT
      16/05/01 16:59:08 INFO server.AbstractConnector: Started SelectChannelConnector@0.0.0.0:4040
      16/05/01 16:59:08 INFO util.Utils: Successfully started service 'SparkUI' on port 4040.
      16/05/01 16:59:08 INFO ui.SparkUI: Started SparkUI at http://129.114.58.161:4040
      16/05/01 16:59:08 INFO spark.SparkContext: Added JAR file:/usr/lib/spark/examples/lib/spark-examples-1.5.0-cdh5.5.1-hadoop2.6.0-cdh5.5.1.jar at http://129.114.58.161:34623/jars/spark-examples-1.5.0-cdh5.5.1-hadoop2.6.0-cdh5.5.1.jar with timestamp 1462139948508
      16/05/01 16:59:08 WARN metrics.MetricsSystem: Using default name DAGScheduler for source because spark.app.id is not set.
      16/05/01 16:59:08 INFO executor.Executor: Starting executor ID driver on host localhost
      16/05/01 16:59:08 INFO util.Utils: Successfully started service 'org.apache.spark.network.netty.NettyBlockTransferService' on port 57254.
      16/05/01 16:59:08 INFO netty.NettyBlockTransferService: Server created on 57254
      16/05/01 16:59:08 INFO storage.BlockManagerMaster: Trying to register BlockManager
      16/05/01 16:59:08 INFO storage.BlockManagerMasterEndpoint: Registering block manager localhost:57254 with 530.0 MB RAM, BlockManagerId(driver, localhost, 57254)
      16/05/01 16:59:08 INFO storage.BlockManagerMaster: Registered BlockManager
      Training: 391, test: 110.
      16/05/01 16:59:11 WARN netlib.BLAS: Failed to load implementation from: com.github.fommil.netlib.NativeSystemBLAS
      16/05/01 16:59:11 WARN netlib.BLAS: Failed to load implementation from: com.github.fommil.netlib.NativeRefBLAS
      Test RMSE = 10.430543451248058.

It's interesting that we see it setting up a web server (Jetty). I bet if we were to launch this instance from the TACC visualization portal, we would get some kind of interface for our Spark job.

###### The Interactive Spark Console
I also see an executable called spark-shell, and it seems to already be on my path. Let's try running something from it, which (scary) I think means we will try some Scala:


spark-shell --master=yarn-client

You will see a bunch of stuff flash across the screen...

      Welcome to
            ____              __
           / __/__  ___ _____/ /__
          _\ \/ _ \/ _ `/ __/  '_/
         /___/ .__/\_,_/_/ /_/\_\   version 1.5.0-cdh5.5.1
            /_/

      Using Scala version 2.10.4 (Java HotSpot(TM) 64-Bit Server VM, Java 1.8.0_45)
      Type in expressions to have them evaluated.
 
And some useful commands:

      :help           Show spark-shell commands help
      :sh <command>	Run a shell command from within spark shell 

I believe this will run spark using files in the local file system. Let's try to read in our crimeandpunishment.txt file.

      val filey = sc.textFile("DATA/crimeandpunishment.txt")
      val words = filey.flatMap(_.split(" "))

      words
      res1: org.apache.spark.rdd.RDD[String] = MapPartitionsRDD[6] at flatMap at <console>:23

      val word_count = words.map(w => (w, 1)).reduceByKey(_ + _)
      16/05/01 17:08:05 INFO mapred.FileInputFormat: Total input paths to process : 1
word_count: org.apache.spark.rdd.RDD[(String, Int)] = ShuffledRDD[8] at reduceByKey at <console>:25

      word_count.saveAsTextFile("DATA/cap_word_counts") 

I then exit to see if I could find the output. Turns out, the function saveAsTextFile generates a directory:

      hadoop fs -ls /user/vsochat/DATA/cap_word_counts
      Found 3 items
      -rw-r--r--   2 vsochat hadoop          0 2016-05-01 17:09 /user/vsochat/DATA/cap_word_counts/_SUCCESS
      -rw-r--r--   2 vsochat hadoop     142486 2016-05-01 17:09 /user/vsochat/DATA/cap_word_counts/part-00000
      -rw-r--r--   2 vsochat hadoop     144901 2016-05-01 17:09 /user/vsochat/DATA/cap_word_counts/part-00001

The file `_SUCCESS` is totally empty, it's presence alone must indicate success.


      hadoop fs -cat /user/vsochat/DATA/cap_word_counts/part-00001
      ..
      (expressed,,1)
      (darning,1)
      (lower,9)
      (inhumanly,1)
      (hesitating?,1)

Seems to again have worked, again sans removal of punctuation, etc. :).

#### Streaming
Hadoop has an API that will let us write scripts for mapping, reducing, and do it in a streaming fashion. In the [hadoop_streaming_python](hadoop_streaming_python) folder in wordcount.sh we run the following streaming task:

      hadoop jar /usr/lib/hadoop-mapreduce/hadoop-streaming.jar \
          -D mapred.map.tasks=4 \
          -D mapred.reduce.tasks=2 \
          -file ./mapper.py -mapper mapper.py \
          -file ./reducer.py -reducer reducer.py \
          -input /user/$USER/DATA/crimeandpunishment.txt \
          -output /user/$USER/DATA/cap_wc_stream \

Take a look at the [mapper.py](hadoop_streaming_python/mapper.py) and [reducer.py](hadoop_streaming_python/reducer.py) to see how the file is streamed from stdin, and passed to the reducer (the values in sorted order to count!) You will again see a bunch of output, and look for a line that says it completed successfully:

      16/05/01 17:45:31 INFO mapreduce.Job: Job job_1462063386551_0003 completed successfully

Then we can look for our output files and see something similar to as before:

      hadoop fs -ls /user/vsochat/DATA/cap_wc_stream
      Found 3 items
      -rw-r--r--   2 vsochat hadoop          0 2016-05-01 17:45 /user/vsochat/DATA/cap_wc_stream/_SUCCESS
      -rw-r--r--   2 vsochat hadoop     122460 2016-05-01 17:45 /user/vsochat/DATA/cap_wc_stream/part-00000
      -rw-r--r--   2 vsochat hadoop     120139 2016-05-01 17:45 /user/vsochat/DATA/cap_wc_stream/part-00001

#### pyspark
Let's try some basic scripts with pyspark - these are from the introduction/tutorial page. First take a look at the script [hadoop_pyspark/count_a_b.py](hadoop_pyspark/count_a_b.py). The script basically reads in our same text file from storage, counts the A's and B's. and prints to the console. I think it used to be that we would run pyspark scripts with the pyspark executable, but now it looks like we send the script to spark-submit:

      /usr/lib/spark/bin/spark-submit count_a_b.py

You will again see a lot of output, but look for these lines to see that the job was successful:

      16/05/01 18:09:42 INFO scheduler.DAGScheduler: Job 1 finished: count at /home/02092/vsochat/SCRIPT/spark/noob-spark/hadoop/hadoop_pyspark/word_count.py:8, took 0.078777 s
      Lines with a: 17428, lines with b: 8357


## YARN is a resource manager
there is something called YARN (yet another resource manager) that looks like it helps to move files and resources around for your cluster, and I believe that when we set up configuration in a python script, we specify this (more will be discussed later). You can also type `which yarn` to see that it also has a command line utility. Some other commands I think will be useful:


      yarn node -list 

shows running nodes in your cluster, and 

      yarn logs 

lets you get logs for some node or application.

## Spark has data frames
it looks like in 2015 they made something called a "[spark dataframe](https://databricks.com/blog/2015/02/17/introducing-dataframes-in-spark-for-large-scale-data-science.html)" to make it easy to run map/reduce operations over data - it's like a pandas data frame but accessible across an entire cluster! I'm not sure what [HIVE](https://cwiki.apache.org/confluence/display/Hive/Home) is but I keep seeing it mentioned, so likely it will be important.
