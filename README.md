# GPTaxonomist

A Shiny dashboard application that helps taxonomists leverage AI language models (ChatGPT, Claude AI) to parse, compare, and write taxonomic descriptions.

## Overview

GPTaxonomist generates specialized prompts for AI assistants to handle common taxonomic tasks like converting natural language descriptions into structured tables, comparing species descriptions, and formatting data according to taxonomic standards.

## Authors

**Bruno A. S. de Medeiros** and **Aline O. Lira**
Field Museum of Natural History, Chicago, IL, USA

## Features

### LLM Integration
- **Copy-only mode**: Generate prompts and copy them to ChatGPT, Claude AI, or any LLM interface (default)
- **Direct API execution**: Run prompts directly within the app using:
  - OpenAI API (GPT-4o-mini)
  - Anthropic API (Claude 3.5 Haiku)
  - Ollama (local LLM server)
- Automatic API key detection from environment variables
- Response extraction and formatting

### 1. Parse Descriptions
Convert natural language taxonomic descriptions into structured tables.
- Input: A text description and example table (CSV or Excel)
- Output: AI-ready prompts to extract characters and states into table format
- Direct execution shows raw response and extracted results

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
    "dplyr",
    "readr",
    "stringr",
    "purrr",
    "tidyr",
    "tibble",
    "DT",
    "readxl",
    "httr2"
  ))
  ```

### Optional: API Configuration

To run prompts directly in the application:

- **OpenAI**: Get an API key from [OpenAI Platform](https://platform.openai.com/api-keys)
- **Anthropic**: Get an API key from [Anthropic Console](https://console.anthropic.com/)
- **Ollama**: Install [Ollama](https://ollama.ai/) for local LLM execution

API keys can be provided in the Configuration page or set as environment variables:
```bash
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="sk-ant-..."
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

### Configuration (First Time Setup)

1. Open the **Configuration** page from the sidebar
2. Choose your preferred LLM provider:
   - **None**: Copy prompts manually to external LLM services (default)
   - **OpenAI API**: Enter API key to use GPT-4o-mini directly
   - **Anthropic API**: Enter API key to use Claude 3.5 Haiku directly
   - **Ollama**: Configure local server settings

### Working with Modules

1. **Select a module** from the sidebar menu based on your task
2. **Prepare your input data**:
   - For tables: Upload CSV or Excel files (.csv, .tsv, .xlsx, .xls)
   - For descriptions: Paste text into the provided text areas
3. **Review the generated prompt**
4. **Execute the prompt**:
   - **Copy-only mode**: Click "Copy to clipboard" and paste into ChatGPT or Claude AI
   - **API mode**: Click "Run Prompt" to execute directly and see results

### Tips

- Use 5-10 example rows when providing example tables
- All prompts can be customized by editing the template files in the `templates/` directory
- Default examples are provided for all modules to help you get started
- When using API mode, results are extracted automatically from `<results>` tags
- API keys are only stored in the current session and are never saved to disk

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

- **v.0.3** (Current) - Direct API integration (OpenAI, Anthropic, Ollama), Configuration page, in-app prompt execution
- **v.0.2** - UI refactoring, Excel support, Claude AI integration
- **v.0.1** - Initial release with core functionality

## Contributing

This project is developed by the de Medeiros Insect Lab. Contributions and suggestions are welcome.

## License

[Add your license here]

## Citation

If you use GPTaxonomist in your research, please cite:

```
de Medeiros, B. A. S., & Lira, A. O. (2025). GPTaxonomist: A Shiny application for
  generating AI prompts for taxonomic descriptions (Version 0.3).
  https://github.com/de-Medeiros-insect-lab/GPTaxonomist
```

## Contact

For questions or suggestions, please contact:
- Bruno A. S. de Medeiros: [Open an issue](https://github.com/de-Medeiros-insect-lab/GPTaxonomist/issues)


