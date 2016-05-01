from pyspark import SparkContext
import sys

infile = sys.argv[1]
outfile = sys.argv[2]

sc = SparkContext("local", "Word Count App")

text_file = sc.textFile(infile)

counts = text_file.flatMap(lambda line: line.split(" ")) \
             .map(lambda word: (word, 1)) \
             .reduceByKey(lambda a, b: a + b)

counts.saveAsTextFile(outfile)
