#include <iostream>
#include <fstream>
#include <vector>
#include <cuda_runtime.h>
#include <stdio.h>
#include <stdlib.h>

#ifdef USE_INT
    typedef int matrix_type;
    #define FORMAT_SPECIFIER "%d"
#elif defined(USE_FLOAT)
    typedef float matrix_type;
    #define FORMAT_SPECIFIER "%f"
#elif defined(USE_DOUBLE)
    typedef double matrix_type;
    #define FORMAT_SPECIFIER "%lf"
#else
    #error "Please define USE_INT, USE_FLOAT, or USE_DOUBLE."
#endif

#define CHUNK_SIZE 1024


int N;
int BLOCK_SIZE;


// Function to read a matrix from a file
void read_matrix(const char* filename, matrix_type** matrix, int size) {
    FILE *fin = fopen(filename, "r");
    if (fin == NULL) {
        perror("Error opening input file");
        exit(EXIT_FAILURE);
    }

    // Reading the matrix elements
    for (int i = 0; i < size; i++) {
        for (int j = 0; j < size; j++) {
            if (fscanf(fin, FORMAT_SPECIFIER, &matrix[i][j]) != 1) {
                perror("Error reading matrix from file");
                exit(EXIT_FAILURE);
            }
        }
    }

    fclose(fin);
}

// Function to write a matrix to a file
void write_matrix(const char* filename, matrix_type** matrix, int size) {
    FILE *fout = fopen(filename, "w");
    if (fout == NULL) {
        perror("Error opening output file");
        exit(EXIT_FAILURE);
    }

    // Writing the matrix elements
    for (int i = 0; i < size; i++) {
        for (int j = 0; j < size; j++) {
            fprintf(fout, FORMAT_SPECIFIER " ", matrix[i][j]);
        }
        fprintf(fout, "\n");  // End each row with a newline
    }

    fclose(fout);
}




// CUDA kernel to sort rows within a chunk
__global__ void sortRows(matrix_type* matrix, int numRows, int numCols) {
    int row = blockIdx.x * blockDim.x + threadIdx.x;

    if (row < numRows) {
        for (int i = 0; i < numCols - 1; ++i) {
            for (int j = 0; j < numCols - i - 1; ++j) {
                int idx = row * numCols + j;
                if (matrix[idx] > matrix[idx + 1]) {
                    matrix_type temp = matrix[idx];
                    matrix[idx] = matrix[idx + 1];
                    matrix[idx + 1] = temp;
                }
            }
        }
    }
}

// CUDA kernel to sort columns within a chunk
__global__ void sortColumns(matrix_type* matrix, int numRows, int numCols, int* changesMade) {
    int col = blockIdx.x * blockDim.x + threadIdx.x;

    if (col < numCols) {
        for (int i = 0; i < numRows - 1; ++i) {
            for (int j = 0; j < numRows - i - 1; ++j) {
                int idx = j * numCols + col;
                if (matrix[idx] > matrix[(j + 1) * numCols + col]) {
                    matrix_type temp = matrix[idx];
                    matrix[idx] = matrix[(j + 1) * numCols + col];
                    matrix[(j + 1) * numCols + col] = temp;

                    // Use atomic operation to set the flag
                    atomicExch(changesMade, 1);  // Set to 1 (true)
                }
            }
        }
    }
}



float total_time = 0;
void processMatrixChunks(matrix_type** matrix, int numRows, int numCols, const char* filename) {
    int numChunks = numRows / CHUNK_SIZE;
    int* d_changesMade;

    // Allocate unified memory for changesMade as an int
    cudaMallocManaged(&d_changesMade, sizeof(int));
    int temp = numRows/1024;
    printf("%d", temp);

    do {
        *d_changesMade = 0; // Reset the flag to 0 (false)
        temp--;

        // Process row chunks
        for (int chunk = 0; chunk < numChunks; ++chunk) {
            int numBlocks = (CHUNK_SIZE + BLOCK_SIZE - 1) / BLOCK_SIZE;

            // Timing
            cudaEvent_t start, stop;
            cudaEventCreate(&start);
            cudaEventCreate(&stop);
            cudaEventRecord(start, 0);

            // Sort rows in the chunk
            sortRows<<<numBlocks, BLOCK_SIZE>>>(matrix[chunk], CHUNK_SIZE, numCols);

            cudaEventRecord(stop, 0);
            cudaEventSynchronize(stop);

            float milliseconds = 0;
            cudaEventElapsedTime(&milliseconds, start, stop);
            printf("Row sorting time: %lf ms\n", milliseconds);
            total_time += milliseconds;
        }

        // Process column chunks for merging
        int chunkCols = numCols / CHUNK_SIZE;
        for (int chunk = 0; chunk < chunkCols; ++chunk) {
            int numBlocks = (CHUNK_SIZE + BLOCK_SIZE - 1) / BLOCK_SIZE;

            // Timing
            cudaEvent_t start, stop;
            cudaEventCreate(&start);
            cudaEventCreate(&stop);
            cudaEventRecord(start, 0);

            // Sort columns in the chunk
            sortColumns<<<numBlocks, BLOCK_SIZE>>>(matrix[chunk], numRows, CHUNK_SIZE, d_changesMade);

            cudaEventRecord(stop, 0);
            cudaEventSynchronize(stop);

            float milliseconds = 0;
            cudaEventElapsedTime(&milliseconds, start, stop);
            printf("Column sorting time: %lf ms\n", milliseconds);
            total_time += milliseconds;
        }

        cudaDeviceSynchronize(); // Ensure all device computations are done
        if(temp == 0){
            break;
        }
    } while (*d_changesMade != 0); // Check if changes were made

    write_matrix(filename, matrix, numRows);

    // Free the unified memory for changesMade
    cudaFree(d_changesMade);
}


int main(int argc, char *argv[]) {
    if (argc != 4) {
        printf("Usage: %s <input_matrix_file> <output_matrix_file>\n", argv[0]);
        return EXIT_FAILURE;
    }



    const char* input_file = argv[1];
    const char* output_file = argv[2];

    // std::string output_file = output_fil;

    BLOCK_SIZE = atoi(argv[3]);


     if (sscanf(input_file, "matrix_%*[^_]_%dx%d", &N, &N) != 2) {
        printf("Error: Could not determine matrix size from filename. Expected format is matrix_TYPE_SIZExSIZE.txt\n");
        return EXIT_FAILURE;
    }


   matrix_type** matrix;
    // Allocate memory for the 2D array

     cudaError_t err = cudaMallocManaged(&matrix, N * sizeof(matrix_type*));
    if (err != cudaSuccess) {
        printf("CUDA malloc failed for row pointers: %s\n", cudaGetErrorString(err));
        return EXIT_FAILURE;
    }

    // Step 2: Allocate memory for each row
    for (int i = 0; i < N; ++i) {
        err = cudaMallocManaged(&matrix[i], N * sizeof(matrix_type));
        if (err != cudaSuccess) {
            printf("CUDA malloc failed for row %d: %s\n", i, cudaGetErrorString(err));
            return EXIT_FAILURE;
        }
    }

    cudaDeviceSynchronize();

    read_matrix(input_file, matrix, N);



    processMatrixChunks(matrix, N, N, output_file);

  cudaFree(matrix);

    printf("total: %lf\n", total_time);

    return 0;
}



