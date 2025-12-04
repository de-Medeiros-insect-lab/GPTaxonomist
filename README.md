# GPTaxonomist

A Shiny dashboard application that helps taxonomists leverage AI language models (ChatGPT, Claude AI) to parse, compare, and write taxonomic descriptions.

## Overview

GPTaxonomist generates specialized prompts for AI assistants to handle common taxonomic tasks like converting natural language descriptions into structured tables, comparing species descriptions, and formatting data according to taxonomic standards.

## Authors

**Bruno A. S. de Medeiros** and **Aline O. Lira**
Field Museum of Natural History, Chicago, IL, USA

## Features

### 1. Parse Descriptions
Convert natural language taxonomic descriptions into structured tables.
- Input: A text description and example table (CSV or Excel)
- Output: AI-ready prompts to extract characters and states into table format
- Automatically splits long descriptions into manageable chunks

### 2. Complete Table
Fill out pre-made character tables using natural language descriptions.
- Input: A taxonomic description and a template table with character names
- Output: Prompts to populate the table with character states from the description
- Useful for standardizing data across multiple species

### 3. Compare Descriptions
Compare two taxonomic descriptions, potentially in different languages.
- Input: Two descriptions in any language
- Output: Side-by-side comparison table showing character states for both species
- Option to include only shared characters or all characters

### 4. Table to Description
Convert structured character tables into natural language descriptions.
- Input: A character table (CSV or Excel) and a template description
- Output: Prompts to generate prose descriptions following the template style
- Maintains taxonomic writing conventions

### 5. Specimen Lists (In Development)
Tools for parsing and writing lists of examined specimens.

## Installation

### Requirements

- R (version 4.0 or higher recommended)
- Required R packages:
  ```r
  install.packages(c(
    "shiny",
    "shinydashboard",
    "rclipboard",
    "tidyverse",
    "DT",
    "readxl"
  ))
  ```

### Running the Application

1. Clone this repository:
   ```bash
   git clone https://github.com/de-Medeiros-insect-lab/GPTaxonomist.git
   cd GPTaxonomist
   ```

2. Open R or RStudio and run:
   ```r
   shiny::runApp()
   ```

   Or in RStudio, open `app.R` and click "Run App"

## Usage

1. **Select a module** from the sidebar menu based on your task
2. **Prepare your input data**:
   - For tables: Export as CSV or Excel (.csv, .tsv, .xlsx, .xls)
   - For descriptions: Copy text into the provided text areas
3. **Review the generated prompt** in the Results tab
4. **Copy the prompt** and paste it into ChatGPT or Claude AI
5. **Copy the AI response** back into your preferred format (Excel, CSV, etc.)

### Tips

- Use 5-10 example rows when providing example tables
- If AI responses get cut off, use: "Continue from the last incomplete row, repeat table headers"
- All prompts can be customized by editing the template files in the `templates/` directory
- Default examples are provided for all modules to help you get started

## File Structure

```
GPTaxonomist/
├── app.R                 # Main Shiny application
├── code/
│   ├── UI.R             # UI components for all modules
│   └── functions.R      # Helper functions
├── templates/           # Prompt templates for each module
├── defaults/            # Default example data
└── README.md
```

## Customization

### Modifying Prompts

Edit the template files in `templates/` to customize how prompts are generated:
- `parse_description.txt` - For parsing descriptions
- `complete_table.txt` - For completing tables
- `compare_description.txt` - For comparing descriptions
- `write_description.txt` - For writing descriptions

### Changing Defaults

Edit files in the `defaults/` directory to change the example data shown when the app starts.

## Version History

- **v.0.2** (Current) - UI refactoring, Excel support, Claude AI integration
- **v.0.1** - Initial release with core functionality

## Contributing

This project is developed by the de Medeiros Insect Lab. Contributions and suggestions are welcome.

## License

[Add your license here]

## Citation

If you use GPTaxonomist in your research, please cite:

```
de Medeiros, B. A. S., & Lira, A. O. (2025). GPTaxonomist: A Shiny application for
  generating AI prompts for taxonomic descriptions (Version 0.2).
  https://github.com/de-Medeiros-insect-lab/GPTaxonomist
```

## Contact

For questions or suggestions, please contact:
- Bruno A. S. de Medeiros: [Open an issue](https://github.com/de-Medeiros-insect-lab/GPTaxonomist/issues)


