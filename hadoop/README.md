# Overview

I have an analysis that (maybe) is not well suited for standard High Performance Computing (HPC), but possibly would work with a map/reduce framework. Toward this goal, I am trying to figure out how to use a Spark cluster on TACC, specifically on Wrangler.


### Starting Hadoop Cluster on TACC
The first thing I went looking for is a spark installation, and so I tried:

      module spider spark

and then was able to find spark, and load like:

      module load spark-paths/1.2.0

I didn't see any "spark" executable, so I started to search my environmental variables and found one called `$SPARK_HOME` which pointed to `/usr/lib/spark`. Unfortunately when I tried to list the files, nothing showed up. I then inferred that it must be the case that these paths are only available on computational nodes (and not a head/login node). I then got myself a node:

      idev -m 60

and received an error about loading the spark-paths. Why? They were already loaded! In this case, I found a nice set of things to play with in my $SPARK_HOME. I quickly found an example python application and made a [modified version](../word_count.py) and I ran it like:

      /usr/lib/spark/bin/pyspark word_count.py

and immediately I started to get a bunch of Java errors. The one that caught my eye was something to the effect of a path not found, but the start of the path was an address with hdfs://. I looked this up online, and realized that hdfs is a special file system (made by Google!) and ho! I needed to use hadoop to work with it. The way I think about this hadoop file system (called `hadoop fs`) is that it has many of the same commands as standard bash, and the general idea is that you move files between your local and hdfs. It then occurred to me that likely I needed to make a reservation on the [Wrangler Data Portal](https://portal.wrangler.tacc.utexas.edu/) to generate my own little hadoop file system, and was able to make a request! Back on Wrangler, I could see the status of my request with:

      scontrol show reservations

and then when it was active, I could connect to it by obtaining the name (either from the data portal or screen output from scontrol) like:

      idev -r hadoop+Analysis_Lonestar+1457 -m 700

I then was able to do `which hadoop` to see that it was installed, and then when I typed `hadoop fs` I could see all of the [command options](http://hadoop.apache.org/docs/r2.5.2/hadoop-project-dist/hadoop-common/FileSystemShell.html). 

#### Hadoop File System Commands

The first thing I wanted to do was just see the file system directories. I didn't know what I was doing, so I found the help command:

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

Note that you can also retrieve a file from the hadoop file system with get, and if the file already exists, you get an equivalent error:

      hadoop fs -get crimeandpunishment.txt 
      get: `crimeandpunishment.txt': File exists

The next thing that makes sense to do is create a directory to put data in. Let's call it DATA.

      hadoop fs -mkdir DATA

This by default will be created in my home folder. The way they have set it up on TACC, the "user" folder has everyone's user name in it, and this is considered the home folder. To see this folder with the new directory, I need to change the ls command a bit:

      hadoop fs -ls /user/vsochat
      Found 2 items
      drwxr-xr-x   - vsochat hadoop          0 2016-05-01 15:06 /user/vsochat/DATA
      -rw-r--r--   2 vsochat hadoop    1154664 2016-04-30 21:38 /user/vsochat/crimeandpunishment.txt

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


### YARN is a resource manager
there is something called YARN (yet another resource manager) that looks like it helps to move files and resources around for your cluster, and I believe that when we set up configuration in a python script, we specify this (more will be discussed later). You can also type `which yarn` to see that it also has a command line utility. Some other commands I think will be useful:


      yarn node -list 

shows running nodes in your cluster, and 

      yarn logs 

lets you get logs for some node or application.

### Spark has data frames
it looks like in 2015 they made something called a "[spark dataframe](https://databricks.com/blog/2015/02/17/introducing-dataframes-in-spark-for-large-scale-data-science.html)" to make it easy to run map/reduce operations over data - it's like a pandas data frame but accessible across an entire cluster! I'm not sure what [HIVE](https://cwiki.apache.org/confluence/display/Hive/Home) is but I keep seeing it mentioned, so likely it will be important.

 

#Practice suggestions
1. how to move, rename a file within hdfs.
2. how to change the replication factor of a paricular file 
3. how to change the block size of a parciular file.
4. what's the difference between storing direcory  stories and test_text.txt
 
################################################
# Exercise 2: 
#  Run hadoop application from the example jar  
#
###############################################

# running word count in example jar 
hadoop jar /usr/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar wordcount -D mapred.map.tasks=96 -D mapred.reduce.tasks=24 data/test_text.txt test_text_wc

#check the result files
hadoop fs -ls test_text_wc 
hadoop fs -cat test_text_wc/part-r-00000

#Paractice suggestions
1. What happens when not specificy map.tasks and reduce.tasks 
2. What happens when changing the value of map.tasks and reduce.tasks 
3. Try some other command in the example jar using 
   hadoop jar /usr/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar
   to see avaliable programs e.g. 
    teragen: create a large file for 
      hadoop jar /usr/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar teragen -D mapred.map.tasks=96 100000000 TS-10GB
    terasort:
      hadoop jar /usr/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar terasort -D mapred.map.tasks=96 -D mapred.reduce.tasks=24 TS-10GB TS-10GB-sort
   calculate pi?


################################################
# Exercise 3: 
#  compile and run a simple java 
#  implementaiton of wordcount
###############################################

# compile WordCount.java
export JAVA_HOME=/usr/lib/jvm/java-1.7.0/
export HADOOP_CLASSPATH=$JAVA_HOME/lib/tools.jar
hadoop com.sun.tools.javac.Main WordCount.java 
jar cf wc.jar WordCount*.class

#run compiled jar file 
hadoop jar wc.jar WordCount /tmp/data/20news-all/alt.atheism/54564 wc_output

#check the result file
hadoop fs -ls wc_output 
hadoop fs -cat wc_output/part-r-00000

#practice suggestions
1. Any improvements to the code? 
2. Just count word length longer than 3?
3. try program something useful. 


################################################
# Exercise 4: 
#  Run hadoop streaming job with bash scripts  
#  implementaiton of wordcount
###############################################

hadoop jar /usr/lib/hadoop-mapreduce/hadoop-streaming.jar \
     -D mapred.map.tasks=96 -D mapred.reduce.tasks=24 -D stream.num.map.output.key.fields=1 \
     -output wc_bash \
     -mapper ./mapwc.sh -reducer ./reducewc.sh \
     -file ./mapwc.sh -file ./reducewc.sh \
     -input /tmp/data/20news-all/alt.atheism \



#Practice suggestion:
1. The bash scripts actually could work without Hadoop 
   but just bash/linux command. How?

2. It won't work (too slow) with large file.    
   Can you write your own map reduce routines with 
   your favoirate prorgamming languages that 
   work with Hadoop streaming? 

3. There is also implementation using python and Rscript. Give it a try. 

################################################
# Exercise 5: 
#  Running K-means example with Mahout  
#
###############################################
cp -r /work/00791/xwj/hadoop-training/reuters-sgm ~/reuters-sgm

#step 1
mahout org.apache.lucene.benchmark.utils.ExtractReuters ~/reuters-sgm reuters-sgm-extract
hadop fs -put reuters-sgm-exrtact 

#step 2
mahout seqdirectory -i reuters-sgm-extract -o reuters-seqdir -c UTF-8 -chunk 5

#step 3
mahout seq2sparse -i reuters-seqdir/ -o reuters-seqdir-vectors

#step 4 
mahout kmeans -i reuters-seqdir-vectors/tfidf-vectors/ -c reuters-kmeans-clusters -o reuters-kmeans -x 10 -k 20

#step 5
mahout clusterdump -i reuters-kmeans/clusters-* -d reuters-seqdir-vectors/dictionary.file-0 -dt sequencefile -b 100 -n 20 -o ./cluster-output.txt

#practice suggestion:
1. Try mahout to see other programs. 


################################################
# Exercise 6: 
# Spark basics  
#
###############################################
#Run Spark example
> /usr/lib/spark/bin/run-example SparkPi 10

#or 

>spark-submit --class org.apache.spark.examples.SparkPi /usr/lib/spark/examples/lib/spark-examples-1.5.0-cdh5.5.1-hadoop2.6.0-cdh5.5.1.jar 10


#
#start spark-shell with following:
#
>spark-shell --master=yarn-client

#Once spark-shell started type 
:help           Show spark-shell commands help
:sh <command>	Run a shell command from within spark shell 

#type in following for an word count using scala. 
val f = sc.textFile("/tmp/data/book.txt")
val words = f.flatMap(_.split(" "))
val wc = words.map(w => (w, 1)).reduceByKey(_ + _)
wc.saveAsTextFile("SS-counts") 
