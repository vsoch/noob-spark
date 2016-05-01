from pyspark import SparkContext

logFile = "/user/vsochat/DATA/crimeandpunishment.txt"  # Should be some file on your system
sc = SparkContext("local", "Word Count App")
logData = sc.textFile(logFile).cache()

numAs = logData.filter(lambda s: 'a' in s).count()
numBs = logData.filter(lambda s: 'b' in s).count()

print "Lines with a: %i, lines with b: %i" % (numAs, numBs)
