import sys
from pyspark import SparkConf, SparkContext

infile = sys.argv[1]
output = sys.argv[2]

conf = SparkConf() \
    .setMaster("yarn-client")\
    .setAppName("Word Counter!")\
    .set("spark.executor.memory","lg")

sc = SparkContext(conf=conf)

text_file = sc.textFile(infile,minPartitions=20)
counts = text_file.flatMap(lambda line: line.split(" ")) \
    .map(lambda word: (word,1))\
    .reduceByKey(lambda a,b: a+b)

counts.sortBy(lambda x:x[1], ascending=False).saveAsTextFile(output)
