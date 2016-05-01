hadoop jar $HADOOP_STREAMING \
-D mapred.map.tasks=4 -D mapred.reduce.tasks=2 \
-file mapper.py -mapper mapper.py \
-file reducer.py -reducer reducer.py \
-input /user/$USER/data/book.txt  -output /user/$USER/output-streaming-py
