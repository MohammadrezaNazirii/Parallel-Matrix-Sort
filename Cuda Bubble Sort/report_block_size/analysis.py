import os
import matplotlib.pyplot as plt

# Directory containing the files
directory = '.'

# Data structure to hold values for each type
data = {}

# Iterate over all files in the directory
for filename in os.listdir(directory):
    if filename.startswith("report_") and filename.endswith(".txt"):
        parts = filename.split('_')
        file_type = parts[1]  # Extract the type (e.g., double, float, int)
        size = parts[2]       # Extract the size (e.g., 1024, 2048)
        block = parts[3].split('.')[0]  # Extract the block (e.g., 512, 64)
        x_label = f"{size}_{block}"

        # Read the number inside the file
        with open(os.path.join(directory, filename), 'r') as file:
            value = float(file.read().strip())

        # Initialize the type if not present
        if file_type not in data:
            data[file_type] = {}

        # Store the value with x_label as key
        data[file_type][x_label] = value

# Sort the x-axis labels (size and block combinations) numerically
x_labels = sorted({label for type_data in data.values() for label in type_data},
                  key=lambda x: tuple(map(int, x.split('_'))))

# Prepare the plot
plt.figure(figsize=(16, 8), dpi=120)  # Increased resolution and size

# Assign line styles and markers for each type
line_styles = {
    'int': ('-', 'o'),
    'float': ('--', 's'),
    'double': (':', '^')
}

for file_type, values in data.items():
    # Extract y-values corresponding to the sorted x_labels
    y_values = [values.get(label, None) for label in x_labels]
    # Filter out None values and corresponding x_labels
    filtered_x = [x for x, y in zip(x_labels, y_values) if y is not None]
    filtered_y = [y for y in y_values if y is not None]
    style, marker = line_styles.get(file_type, ('-', 'o'))
    plt.plot(filtered_x, filtered_y, linestyle=style, marker=marker, label=file_type)

# Customize the plot
plt.xlabel("Size_Block", fontsize=14)
plt.ylabel("Values", fontsize=14)
plt.title("Values by Type", fontsize=16)
plt.legend(title="Type", fontsize=12)
plt.grid(True, linestyle='--', alpha=0.7)
plt.xticks(rotation=45, ha='right', fontsize=10)
plt.yticks(fontsize=10)
plt.tight_layout()

# Show the plot
plt.show()
