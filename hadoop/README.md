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

I then was able to do `which hadoop` to see that it was installed, and then when I typed `hadoop fs` I could see all of the [command options](http://hadoop.apache.org/docs/r2.5.2/hadoop-project-dist/hadoop-common/FileSystemShell.html). I found a good definition of HDFS [here](https://developer.yahoo.com/hadoop/tutorial/module2.html):

      >> HDFS, the Hadoop Distributed File System, is a distributed file system designed to hold very large amounts of data (terabytes or even petabytes), and provide high-throughput access to this information. Files are stored in a redundant fashion across multiple machines to ensure their durability to failure and high availability to very parallel applications. This module introduces the design of this distributed file system and instructions on how to operate it.


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

This also looks like it is set in the global config, but you can do on the command line as well:

      hadoop fs -Ddfs.block.size=1048576

I'm not entirey sure the reasons I'd want to do this, so I'm not going to mess with it for now.

### YARN is a resource manager
there is something called YARN (yet another resource manager) that looks like it helps to move files and resources around for your cluster, and I believe that when we set up configuration in a python script, we specify this (more will be discussed later). You can also type `which yarn` to see that it also has a command line utility. Some other commands I think will be useful:


      yarn node -list 

shows running nodes in your cluster, and 

      yarn logs 

lets you get logs for some node or application.

### Spark has data frames
it looks like in 2015 they made something called a "[spark dataframe](https://databricks.com/blog/2015/02/17/introducing-dataframes-in-spark-for-large-scale-data-science.html)" to make it easy to run map/reduce operations over data - it's like a pandas data frame but accessible across an entire cluster! I'm not sure what [HIVE](https://cwiki.apache.org/confluence/display/Hive/Home) is but I keep seeing it mentioned, so likely it will be important.
