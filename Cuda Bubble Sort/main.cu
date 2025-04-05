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
__global__ void sortColumns(matrix_type* matrix, int numRows, int numCols, bool* changesMade) {
    int col = blockIdx.x * blockDim.x + threadIdx.x;

    if (col < numCols) {
        bool localChanges = false;
        for (int i = 0; i < numRows - 1; ++i) {
            for (int j = 0; j < numRows - i - 1; ++j) {
                int idx = j * numCols + col;
                if (matrix[idx] > matrix[(j + 1) * numCols + col]) {
                    matrix_type temp = matrix[idx];
                    matrix[idx] = matrix[(j + 1) * numCols + col];
                    matrix[(j + 1) * numCols + col] = temp;
                    localChanges = true;
                }
            }
        }
        if (localChanges) {
            *changesMade = true;
        }
    }
}

float total_time = 0;
void processMatrixChunks(matrix_type** matrix, int numRows, int numCols, const char* filename) {
    int numChunks = numRows / CHUNK_SIZE;
    std::vector<matrix_type*> d_matrix(numChunks);

    std::vector<cudaStream_t> streams(numChunks);
    std::vector<bool*> d_changesMade(numChunks);

    // Allocate device memory and create streams for each chunk
    for (int i = 0; i < numChunks; ++i) {
        cudaMalloc(&d_matrix[i], CHUNK_SIZE * numCols * sizeof(matrix_type));
        cudaMalloc(&d_changesMade[i], sizeof(bool));
        cudaStreamCreate(&streams[i]);
    }
 bool changes;
        do {
            changes = false;
    // Process row chunks
    for (int chunk = 0; chunk < numChunks; ++chunk) {
        // Copy chunk to device
        for (int row = 0; row < CHUNK_SIZE; ++row) {
            cudaMemcpyAsync(&d_matrix[chunk][row * numCols], matrix[chunk * CHUNK_SIZE + row], numCols * sizeof(matrix_type),
                            cudaMemcpyHostToDevice, streams[chunk]);
        }

        // Sort rows in the chunk
        int numBlocks = (CHUNK_SIZE + BLOCK_SIZE - 1) / BLOCK_SIZE;



        // Start and stop events
        cudaEvent_t start, stop;
        cudaEventCreate(&start);
        cudaEventCreate(&stop);

        // Record start event
        cudaEventRecord(start, 0);



        sortRows<<<numBlocks, BLOCK_SIZE, 0, streams[chunk]>>>(d_matrix[chunk], CHUNK_SIZE, numCols);
        // cudaStreamSynchronize(streams[chunk]);

        // Record stop event
        cudaEventRecord(stop, 0);

        // Synchronize to ensure all work is done
        cudaEventSynchronize(stop);

        // Calculate and print elapsed time
        float milliseconds = 0;
        cudaEventElapsedTime(&milliseconds, start, stop);

        // printf("this time: %lf\n", milliseconds);


        total_time += milliseconds;



        // Copy chunk back to host
        for (int row = 0; row < CHUNK_SIZE; ++row) {
            cudaMemcpyAsync(matrix[chunk * CHUNK_SIZE + row], &d_matrix[chunk][row * numCols], numCols * sizeof(matrix_type),
                            cudaMemcpyDeviceToHost, streams[chunk]);
        }
    }

    // Process column chunks for merging
    int chunkCols = numCols / CHUNK_SIZE;
    for (int chunk = 0; chunk < chunkCols; ++chunk) {


            cudaMemcpyAsync(d_changesMade[chunk], &changes, sizeof(bool), cudaMemcpyHostToDevice, streams[chunk]);

            // Copy column chunk to device
            for (int row = 0; row < numRows; ++row) {
                cudaMemcpyAsync(&d_matrix[chunk][row * CHUNK_SIZE], &matrix[row][chunk * CHUNK_SIZE],
                                CHUNK_SIZE * sizeof(matrix_type), cudaMemcpyHostToDevice, streams[chunk]);
            }

            // Start and stop events
            cudaEvent_t start, stop;
            cudaEventCreate(&start);
            cudaEventCreate(&stop);

            // Record start event
            cudaEventRecord(start, 0);


            // Sort columns in the chunk
            int numBlocks = (CHUNK_SIZE + BLOCK_SIZE -1 ) / BLOCK_SIZE;
            sortColumns<<<numBlocks, BLOCK_SIZE, 0, streams[chunk]>>>(d_matrix[chunk], numRows, CHUNK_SIZE, d_changesMade[chunk]);
            // cudaStreamSynchronize(streams[chunk]);

            // Record stop event
            cudaEventRecord(stop, 0);

            // Synchronize to ensure all work is done
            cudaEventSynchronize(stop);

            // Calculate and print elapsed time
            float milliseconds = 0;
            cudaEventElapsedTime(&milliseconds, start, stop);

            total_time += milliseconds;

            // Copy column chunk back to host
            for (int row = 0; row < numRows; ++row) {
                cudaMemcpyAsync(&matrix[row][chunk * CHUNK_SIZE], &d_matrix[chunk][row * CHUNK_SIZE],
                                CHUNK_SIZE * sizeof(matrix_type), cudaMemcpyDeviceToHost, streams[chunk]);
            }

            // Check if any changes were made
            cudaMemcpy(&changes, d_changesMade[chunk], sizeof(bool), cudaMemcpyDeviceToHost);
        }
    }while (changes); // Repeat if changes were made

    // Free resources
    for (int i = 0; i < numChunks; ++i) {
        cudaFree(d_matrix[i]);
        cudaFree(d_changesMade[i]);
        cudaStreamDestroy(streams[i]);
    }



    write_matrix(filename, matrix, numRows);
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


    matrix_type** matrix = new matrix_type*[N];
    for (int i = 0; i < N; ++i) {
        matrix[i] = new matrix_type[N];
    }


    read_matrix(input_file, matrix, N);

    //
    // Process matrix chunks
    processMatrixChunks(matrix, N, N, output_file);

    // Free dynamically allocated memory
    for (int i = 0; i < N; ++i) {
        delete[] matrix[i];

    }
    delete[] matrix;

    printf("%lf\n", total_time);

    return 0;
}



