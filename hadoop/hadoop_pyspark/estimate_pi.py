from pyspark import SparkContext
from numpy.random import rand
import sys

NUM_SAMPLES = int(sys.argv[1])

sc = SparkContext("local", "Estimate Pi")

def sample(p):
    x, y = rand(2)
    return 1 if x*x + y*y < 1 else 0

count = sc.parallelize(xrange(0, NUM_SAMPLES)).map(sample) \
       .reduce(lambda a, b: a + b)

print "Pi is roughly %f" % (4.0 * count / NUM_SAMPLES)
