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
  writeResponse = NULL,
  #model lists for each provider
  openaiModels = NULL,
  anthropicModels = NULL,
  ollamaModels = NULL,
  #streaming state for each module
  parseStreaming = list(active = FALSE, outputFile = NULL, statusFile = NULL, process = NULL),
  completeStreaming = list(active = FALSE, outputFile = NULL, statusFile = NULL, process = NULL),
  compareStreaming = list(active = FALSE, outputFile = NULL, statusFile = NULL, process = NULL),
  writeStreaming = list(active = FALSE, outputFile = NULL, statusFile = NULL, process = NULL)
)
```

Key pattern: File uploads update `rv$*Path`, which triggers observers to re-read and re-render tables and prompts.

### Helper Reactive Functions

Three helper reactive functions provide consistent access to configuration:

- `getOpenAIKey()` - Returns OpenAI API key from user input or environment
- `getAnthropicKey()` - Returns Anthropic API key from user input or environment
- `getOllamaModel()` - Returns effective Ollama model (from dropdown or custom text input)

### Module Pattern

Each taxonomic task follows the same server-side pattern:

1. **Input handling**: `observeEvent` watches for file uploads, updates reactive paths
2. **Data processing**: `observe` blocks read files with `read_table_robust()`, format with `format_table()`
3. **Prompt generation**: `observe` blocks call `fill_*()` functions from templates
4. **Output rendering**: `renderUI` creates prompt display with copy buttons and optional API execution
5. **API execution**: `observeEvent` on Run Prompt button starts streaming in background process
6. **Streaming display**: `renderUI` polls temp files with `invalidateLater(200)` to show real-time response
7. **Result extraction**: Results are extracted from `<results>` tags using `extract_results()`

### LLM Integration

Three API providers supported with unified interface:

- **OpenAI**: `call_openai(prompt, api_key, model)` - supports all chat-compatible models
- **Anthropic**: `call_anthropic(prompt, api_key, model)` - supports all Claude models
- **Ollama**: `call_ollama(prompt, host, port, model)` - local LLM server

All API functions return:
```r
list(success = TRUE/FALSE, content = "...", error = "...")
```

#### Real-time Streaming

API responses are streamed in real-time using background processes:

- **`stream_openai_to_file(prompt, api_key, model, output_file, status_file)`** - Streams OpenAI response to file
- **`stream_anthropic_to_file(prompt, api_key, model, output_file, status_file)`** - Streams Anthropic response to file
- **`stream_ollama_to_file(prompt, host, port, model, output_file, status_file)`** - Streams Ollama response to file

Streaming architecture:
1. Run Prompt button triggers `callr::r_bg()` to spawn background R process
2. Background process sources `functions.R` and calls streaming function
3. Streaming function writes accumulated content to `output_file` and status to `status_file`
4. Main Shiny session polls files with `invalidateLater(200)` (every 200ms)
5. UI updates in real-time as content accumulates
6. Status file transitions: "starting" -> "running" -> "success" or "error:message"

#### Dynamic Model Selection

The app dynamically fetches available models for each provider:

- **`fetch_openai_models(api_key)`** - Calls `/v1/models` endpoint, filters for chat-compatible models (gpt-4*, gpt-3.5*, o1*, o3*, chatgpt*)
- **`fetch_anthropic_models(api_key)`** - Calls `/v1/models` endpoint, returns all available Claude models
- **`fetch_ollama_models(host, port)`** - Calls `/api/tags` endpoint, returns locally installed models

Each function returns `list(success, models, error)` with appropriate error messages guiding users to check API keys/credits or Ollama connection.

Model selection UI shows:
- Dropdown with available models when fetch succeeds
- Custom text input for Ollama to enter any model name
- Error message with troubleshooting guidance when fetch fails
- "Refresh" button to retry model fetching

#### API Key Detection

API keys are detected from environment variables (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`) on app startup and masked for display. Keys are session-only, never persisted to disk.

Users can:
- Enter API keys manually via password inputs
- Use detected environment variables automatically
- Click "Refresh environment variables" button if keys were set after app startup

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

### LLM API Functions
- `call_openai(prompt, api_key, model)` - Execute prompt via OpenAI API (non-streaming)
- `call_anthropic(prompt, api_key, model)` - Execute prompt via Anthropic API (non-streaming)
- `call_ollama(prompt, host, port, model)` - Execute prompt via Ollama local server (non-streaming)
- `stream_openai_to_file(...)` - Stream OpenAI response to file (for background process)
- `stream_anthropic_to_file(...)` - Stream Anthropic response to file (for background process)
- `stream_ollama_to_file(...)` - Stream Ollama response to file (for background process)
- `fetch_openai_models(api_key)` - Fetch available OpenAI models
- `fetch_anthropic_models(api_key)` - Fetch available Anthropic models
- `fetch_ollama_models(host, port)` - Fetch locally installed Ollama models
- `detect_api_keys()` - Detect and mask API keys from environment variables

### Utility Functions
- `format_table()` - Convert data frame to markdown pipe table
- `group_paragraphs()` - Split long text by word limits
- `group_table_rows()` - Split large tables by word limits
- `extract_results()` - Extract content between `<results>` tags (uses LAST occurrence)

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
- `shinyjs` - JavaScript integration for scroll preservation during streaming
- `rclipboard` - clipboard integration
- `dplyr`, `purrr`, `tidyr`, `tibble` - data manipulation
- `readr`, `readxl` - file reading
- `stringr` - string processing
- `DT` - interactive tables
- `httr2` - API calls
- `jsonlite` - JSON parsing
- `callr` - background R processes for streaming

## Notes

- API keys are session-only, never persisted to disk
- API keys are detected on startup; use "Refresh environment variables" button if keys are set after launch
- Model selection is dynamic - fetched from provider APIs when keys/connection are available
- For Ollama, users can enter any model name, not just locally installed ones
- Results should be wrapped in `<results>` tags for extraction
- Default word limits are set very high (`10000000`) - essentially unlimited
- The app uses FontAwesome icons via `icon()` function
- Links to external LLM services (ChatGPT, Claude AI) are provided in all module outputs
- Model fetching errors show specific troubleshooting guidance (check API keys/credits for OpenAI/Anthropic, check connection for Ollama)
- API responses stream in real-time (UI updates every 200ms while response is being generated)
- Streaming uses background R processes via callr to keep UI responsive
