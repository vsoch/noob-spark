#!/bin/bash
hadoop jar $HADOOP_STREAMING \
-D mapred.map.tasks=4 -D mapred.reduce.tasks=2 \
-file mapper-2.R -file runRMapper.sh -mapper runRMapper.sh \
-file reducer-4.R -file runRReducer.sh -reducer runRReducer.sh \
-input /user/$USER/data/book.txt  -output /user/$USER/output-streaming
