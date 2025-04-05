#!/bin/bash

nvcc -DUSE_INT -o sort_int main.cu
nvcc -DUSE_DOUBLE -o sort_double main.cu
nvcc -DUSE_FLOAT -o sort_float main.cu
# Matrix sizes to test
matrix_sizes=(1024 2048 4096)
# matrix_sizes=(1024 4096)
# Block sizes to test
# block_sizes=(64 512 1024)
block_sizes=(128)

# block_sizes=(8 16 32 64 128 256 512 1024 2048)
# Loop through each matrix size
# for size in "${matrix_sizes[@]}"; do
#   # Loop through each block size
#   for blocksize in "${block_sizes[@]}"; do
#     echo "Running with matrix size ${size}x${size} and block size ${blocksize} with int"
# #     ncu ./sort_int "matrix_int_${size}x${size}.txt" "sorted_int_${size}x${size}_${blocksize}.txt" ${blocksize} > ncu_report_block/report_int_${size}_${blocksize}.txt
#     ncu ./sort_int "matrix_int_${size}x${size}.txt" "sorted_int_${size}x${size}_${blocksize}.txt" ${blocksize} > ncu_report/report_int_${size}_${blocksize}.txt
#
# #     ./sort_int "matrix_int_${size}x${size}.txt" "sorted_int_${size}x${size}_${blocksize}.txt" ${blocksize} > report/report_int_${size}_${blocksize}.txt
#
#   done
# done


for size in "${matrix_sizes[@]}"; do
  # Loop through each block size
  for blocksize in "${block_sizes[@]}"; do
    echo "Running with matrix size ${size}x${size} and block size ${blocksize} with float"
    ncu ./sort_float "matrix_double_${size}x${size}.txt" "sorted_float_${size}x${size}_${blocksize}.txt" ${blocksize} > ncu_report/report_float_${size}_${blocksize}.txt
  done
done


for size in "${matrix_sizes[@]}"; do
  # Loop through each block size
  for blocksize in "${block_sizes[@]}"; do
    echo "Running with matrix size ${size}x${size} and block size ${blocksize} with double"
    ncu ./sort_double "matrix_double_${size}x${size}.txt" "sorted_double_${size}x${size}_${blocksize}.txt" ${blocksize} > ncu_report/report_double_${size}_${blocksize}.txt
  done
done
