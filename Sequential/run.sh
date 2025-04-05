#!/bin/bash

gcc -pg -DUSE_INT -o sort_int main.c
gcc -pg -DUSE_DOUBLE -o sort_double main.c
gcc -pg -DUSE_FLOAT -o sort_float main.c
# Matrix sizes to test
matrix_sizes=(1024 2048 4096)
# matrix_sizes=(1024 4096)
# Block sizes to test
# block_sizes=(64 512 1024)
block_sizes=(64)

# for size in "${matrix_sizes[@]}"; do
#     ./sort_int "matrix_int_${size}x${size}.txt" "sorted_int_${size}x${size}.txt"
#     gprof sort_int gmon.out > ./reports/"gprof_report_int_${size}.txt"
# done

# for size in "${matrix_sizes[@]}"; do
#     ./sort_float "matrix_int_${size}x${size}.txt" "soeted_float_${size}x${size}.txt"
#     gprof sort_float gmon.out > ./reports/"gprof_report_float_${size}.txt"
# done

for size in "${matrix_sizes[@]}"; do
    ./sort_double "matrix_int_${size}x${size}.txt" "soeted_double_${size}x${size}.txt"
    gprof sort_double gmon.out > ./reports/"gprof_report_double_${size}.txt"
done
