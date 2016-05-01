hadoop jar /usr/lib/hadoop-mapreduce/hadoop-streaming.jar \
    -D mapred.map.tasks=4 \
    -D mapred.reduce.tasks=2 \
    -file ./mapper.py -mapper mapper.py \
    -file ./reducer.py -reducer reducer.py \
    -input /user/$USER/DATA/crimeandpunishment.txt \
    -output /user/$USER/DATA/cap_wc_stream \
