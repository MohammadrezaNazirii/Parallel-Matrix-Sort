#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

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

int N;

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

// Function to sort the rows of the matrix
void sort_rows(matrix_type** matrix, int size, bool* changesMade) {
    for (int i = 0; i < size; i++) {
        for (int j = 0; j < size - 1; j++) {
            for (int k = 0; k < size - j - 1; k++) {
                if (matrix[i][k] > matrix[i][k + 1]) {
                    matrix_type temp = matrix[i][k];
                    matrix[i][k] = matrix[i][k + 1];
                    matrix[i][k + 1] = temp;
                    *changesMade = true;
                }
            }
        }
    }
}

// Function to sort the columns of the matrix
void sort_columns(matrix_type** matrix, int size, bool* changesMade) {
    for (int j = 0; j < size; j++) {
        for (int i = 0; i < size - 1; i++) {
            for (int k = 0; k < size - i - 1; k++) {
                if (matrix[k][j] > matrix[k + 1][j]) {
                    matrix_type temp = matrix[k][j];
                    matrix[k][j] = matrix[k + 1][j];
                    matrix[k + 1][j] = temp;
                    *changesMade = true;
                }
            }
        }
    }
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        printf("Usage: %s <input_matrix_file> <output_matrix_file>\n", argv[0]);
        return EXIT_FAILURE;
    }

    const char* input_file = argv[1];
    const char* output_file = argv[2];

    // Extract matrix size from the file name
    if (sscanf(input_file, "matrix_%*[^_]_%dx%d", &N, &N) != 2) {
        printf("Error: Could not determine matrix size from filename. Expected format is matrix_TYPE_SIZExSIZE.txt\n");
        return EXIT_FAILURE;
    }

    // Allocate memory for the matrix
    matrix_type** matrix = (matrix_type**)malloc(N * sizeof(matrix_type*));
    for (int i = 0; i < N; ++i) {
        matrix[i] = (matrix_type*)malloc(N * sizeof(matrix_type));
    }

    // Read the matrix from the input file
    read_matrix(input_file, matrix, N);

    bool changesMade;
    int maxIterations = 100;

    // Perform the sorting until the matrix is sorted or maximum iterations are reached
    for (int iteration = 0; iteration < maxIterations; ++iteration) {
        changesMade = false;

        // Step 1: Sort rows
        sort_rows(matrix, N, &changesMade);

        // Step 2: Sort columns
        sort_columns(matrix, N, &changesMade);

        // Check if any changes were made
        if (!changesMade) {
            printf("Matrix is sorted after %d iterations.\n", iteration + 1);
            break;
        }
    }

    // Write the sorted matrix to the output file
    write_matrix(output_file, matrix, N);

    // Free allocated memory
    for (int i = 0; i < N; ++i) {
        free(matrix[i]);
    }
    free(matrix);

    return 0;
}
