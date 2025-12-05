# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GPTaxonomist is a Shiny dashboard application for taxonomists that generates AI-optimized prompts to parse, compare, and write taxonomic descriptions. The application supports both copy-only mode (for external LLMs) and direct API execution via OpenAI, Anthropic, or Ollama.

## Running the Application

Start the Shiny app:
```r
shiny::runApp()
```

Or open `app.R` in RStudio and click "Run App"

## Architecture

### Core Structure

The application follows a modular Shiny architecture with clear separation:

- **app.R**: Main application file containing UI definition (`dashboardPage`) and server logic
- **code/functions.R**: Helper functions for prompt generation, table formatting, and API calls
- **code/UI.R**: UI component definitions for all modules (configuration, parse, complete, compare, write)
- **templates/**: Prompt templates with `${VARIABLE}` placeholders for dynamic substitution
- **defaults/**: Default example data loaded on app startup

### Reactive Data Flow

The app uses a single `rv` (reactive values) object to manage state:

```r
rv = reactiveValues(
  parseExamplePath = "defaults/parse/example.csv",
  completeTablePath = "defaults/complete/table.csv",
  writeTablePath = "defaults/write/input_table.csv",
  detectedKeys = NULL,
  parseResponse = NULL,
  completeResponse = NULL,
  compareResponse = NULL,
  writeResponse = NULL
)
```

Key pattern: File uploads update `rv$*Path`, which triggers observers to re-read and re-render tables and prompts.

### Module Pattern

Each taxonomic task follows the same server-side pattern:

1. **Input handling**: `observeEvent` watches for file uploads, updates reactive paths
2. **Data processing**: `observe` blocks read files with `read_table_robust()`, format with `format_table()`
3. **Prompt generation**: `observe` blocks call `fill_*()` functions from templates
4. **Output rendering**: `renderUI` creates prompt display with copy buttons and optional API execution
5. **API execution**: `observeEvent` on Run Prompt button calls appropriate API function
6. **Result extraction**: Results are extracted from `<results>` tags using `extract_results()`

### LLM Integration

Three API providers supported with unified interface:

- **OpenAI**: `call_openai(prompt, api_key, model)` - uses gpt-4o-mini
- **Anthropic**: `call_anthropic(prompt, api_key, model)` - uses claude-3-5-haiku-20241022
- **Ollama**: `call_ollama(prompt, host, port, model)` - local LLM server

All API functions return:
```r
list(success = TRUE/FALSE, content = "...", error = "...")
```

API keys are detected from environment variables (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`) and masked for display.

### Template System

Templates in `templates/` use placeholders:
- `${DESCRIPTION}` - taxonomic description text
- `${LANGUAGE}` - output language
- `${EXAMPLE}` - formatted table
- `${TABLE}` - character table
- `${TEMPLATE_DESCRIPTION}` - template for writing
- `${INCLUDE_STATEMENT}` - comparison options

Fill functions use `str_replace_all()` for substitution.

## File Format Support

`read_table_robust()` handles multiple formats:
- CSV (.csv)
- TSV (.tsv, .txt)
- Excel (.xls, .xlsx) via `readxl::read_excel()`

## Key Functions

### Prompt Generation
- `fill_parseDescription()` - Parse natural language into tables
- `fill_completeTable()` - Fill character tables from descriptions
- `fill_compareDescriptions()` - Compare two descriptions
- `fill_writeDescription()` - Generate prose from tables

### Utility Functions
- `format_table()` - Convert data frame to markdown pipe table
- `group_paragraphs()` - Split long text by word limits
- `group_table_rows()` - Split large tables by word limits
- `extract_results()` - Extract content between `<results>` tags (uses LAST occurrence)
- `detect_api_keys()` - Find and mask API keys from environment

## Adding New Modules

To add a new taxonomic task module:

1. Create template file in `templates/new_module.txt` with `${PLACEHOLDERS}`
2. Add `fill_newModule()` function in `code/functions.R`
3. Add `UI_newModule` definition in `code/UI.R`
4. Add menu item in `app.R` sidebar
5. Add `UI_newModule` to `tabItems` in `app.R`
6. Implement server-side logic following existing module patterns
7. Add default examples in `defaults/new_module/`

## Dependencies

Core packages:
- `shiny`, `shinydashboard` - UI framework
- `rclipboard` - clipboard integration
- `dplyr`, `purrr`, `tidyr`, `tibble` - data manipulation
- `readr`, `readxl` - file reading
- `stringr` - string processing
- `DT` - interactive tables
- `httr2` - API calls

## Notes

- API keys are session-only, never persisted to disk
- Results should be wrapped in `<results>` tags for extraction
- Default word limits are set very high (`10000000`) - essentially unlimited
- The app uses FontAwesome icons via `icon()` function
- Links to external LLM services (ChatGPT, Claude AI) are provided in all module outputs
