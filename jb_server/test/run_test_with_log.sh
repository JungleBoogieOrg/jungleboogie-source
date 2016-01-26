#!/bin/bash

for i in {1..1000}
do
    escript test/run_single_test > logs/test$i.log
    echo "Done with $i"
done
