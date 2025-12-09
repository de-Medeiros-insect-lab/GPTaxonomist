###### CONFIGURATION

UI_config = tabItem(
  tabName = "config",
  h2("Configuration"),

  h3("Welcome to GPTaxonomist!"),
  p(
    "This is an interactive tool to help generate useful prompts for taxonomic tasks using large language models."
  ),
  p(
    "You can use this tool in two ways:"
  ),
  tags$div(
    tags$ul(
      tags$li(tags$b("Copy prompts to external LLM:"), " Generate prompts and copy them to ChatGPT, Claude AI, or any other LLM interface (default mode)."),
      tags$li(tags$b("Run prompts directly:"), " Configure an API connection below to run prompts and see results directly in this application.")
    )
  ),

  hr(),

  h3("Output Format"),
  p("Choose the format for table outputs (Parse, Complete, and Compare modules):"),

  radioButtons(
    "outputFormat",
    "Table Output Format:",
    choices = list(
      "CSV (comma-separated values)" = "csv",
      "JSON (array of objects)" = "json",
      "Markdown table" = "markdown"
    ),
    selected = "csv"
  ),

  hr(),

  h3("LLM Configuration"),
  p("Select how you want to use this application:"),

  radioButtons(
    "llmProvider",
    "LLM Provider:",
    choices = list(
      "None (copy prompts only)" = "none",
      "OpenAI API" = "openai",
      "Anthropic API" = "anthropic",
      "Ollama (local server)" = "ollama"
    ),
    selected = "none"
  ),

  conditionalPanel(
    condition = "input.llmProvider == 'openai'",
    h4("OpenAI API Configuration"),
    p("You need an OpenAI API key to use this option."),
    a("Get an OpenAI API key", href = "https://platform.openai.com/api-keys", target = "_blank"),
    p(),
    uiOutput("openaiKeyDetected"),
    passwordInput("openaiApiKey", "API Key:", placeholder = "sk-..."),
    p(tags$small("Your API key is only stored in this session and is never saved."))
  ),

  conditionalPanel(
    condition = "input.llmProvider == 'anthropic'",
    h4("Anthropic API Configuration"),
    p("You need an Anthropic API key to use this option."),
    a("Get an Anthropic API key", href = "https://console.anthropic.com/settings/keys", target = "_blank"),
    p(),
    uiOutput("anthropicKeyDetected"),
    passwordInput("anthropicApiKey", "API Key:", placeholder = "sk-ant-..."),
    p(tags$small("Your API key is only stored in this session and is never saved."))
  ),

  conditionalPanel(
    condition = "input.llmProvider == 'ollama'",
    h4("Ollama Configuration"),
    p("Ollama allows you to run large language models locally on your computer. This will only work if you are running GPTaxonomist at your computer and not through the shinyapps website."),
    a("Learn how to install Ollama", href = "https://ollama.com/download", target = "_blank"),
    p(),
    p("After installing Ollama, you can download models using:", tags$code("ollama pull <model-name>")),
    a("Browse available Ollama models", href = "https://ollama.com/library", target = "_blank"),
    p(),
    textInput("ollamaHost", "Host:", value = ollama_default_host),
    textInput("ollamaPort", "Port:", value = ollama_default_port),
    textInput("ollamaModel", "Model name:", value = ollama_default_model,
              placeholder = "e.g., deepseek-r1:1.5b, llama3.2, mistral"),
    p(tags$small("Make sure Ollama is running on your system before using this option."))
  ),

  hr(),

  uiOutput("configStatus")
)


###### PARSE

UI_parse = tabItem(
  tabName = "parse",
  h2("Parse descriptions"),
  h3("Purpose"),
  p("Generate a prompt to parse a taxonomic description in natural language into structured data (table or json)"),
  h3("Input required"),
  tags$div(
    tags$ul(
      tags$li(tags$b("The output language desired.")," Edit the text box below to change."),
      tags$li(tags$b("The description to parse.")," Edit the text box below to change."),
      tags$li(tags$b("A table with examples.")," only use 5-10 examples. Create a table in csv or excel format and upload it here using the button below.")
    )
  ),
  
  
  tabsetPanel(type = "tabs", id = "parseTabset",
              tabPanel("Input",
                       p("Edit text and table below with your data."),
                       textInput(
                         "parseLanguage",
                         "Language to output",
                         value = read_file("defaults/language.txt")
                       ),
                       textAreaInput(
                         "parseDesc",
                         "Description to parse",
                         value = read_file("defaults/parse/description.txt"),
                         rows = 10,
                         width = "100%"
                       ),
                       strong("Examples"),
                       p("Upload a data table to change examples."),
                       fileInput(
                         "parseExampleFile",
                         NULL,
                         accept = c(".csv", ".tsv", ".txt", ".xls", ".xlsx"),
                         buttonLabel = "Upload table..."
                       ),
                       DTOutput("parseTable1")
              ),
              tabPanel("Generated prompt",
                       uiOutput("parsePromptUI")
              ),
              tabPanel("Results",
                       conditionalPanel(
                         condition = "input.llmProvider != 'none'",
                         fluidRow(
                           class = "my-margin",
                           h4("Raw response:"),
                           uiOutput("parseRawResponse")
                         ),
                         fluidRow(
                           class = "my-margin",
                           h4("Result:"),
                           uiOutput("parseExtractedResult")
                         )
                       ),
                       conditionalPanel(
                         condition = "input.llmProvider == 'none'",
                         p("Configure an LLM provider in the Configuration tab to see results here.")
                       )
              )
  )
)

###################################### COMPLETE UI ####################################
UI_complete = tabItem(
  tabName = "complete",
  h2("Complete table"),
  h3("Purpose"),
  p("Generate a prompt to parse a taxonomic description in natural language and add its character states to a pre-made table containing other species. No new characters will be added, only the states will be extracted."),
  h3("Input required"),
  tags$div(
    tags$ul(
      tags$li(tags$b("The output language desired."), " Edit the text box below to change."),
      tags$li(tags$b("The description to parse.")," Edit the text box below to change."),
      tags$li(tags$b("A table to be filled out.")," This must include 2 columns: one with character names and another with observed states for an example species. The second column may be blank, but it will work better if not. Create a table in csv or excel and upload it here using the button below.")
    )
  ),
  tabsetPanel(type = "tabs", id = "completeTabset",
              tabPanel("Input",
                       textInput(
                         "completeLanguage",
                         "Language to output",
                         value = read_file("defaults/language.txt")
                       ),
                       textAreaInput(
                         "completeDesc",
                         "Description to parse",
                         value = read_file("defaults/complete/description.txt"),
                         rows = 10,
                         width = "100%"
                       ),
                       strong("Table to add to"),
                       p("Upload a file to change the table."),
                       fileInput(
                         "completeTableFile",
                         NULL,
                         accept = c(".csv", ".tsv", ".txt", ".xls", ".xlsx"),
                         buttonLabel = "Upload table..."
                       ),
                       DTOutput("completeTable1")
              ),
              tabPanel("Generated prompt",
                       uiOutput("completePromptUI")
              ),
              tabPanel("Results",
                       conditionalPanel(
                         condition = "input.llmProvider != 'none'",
                         fluidRow(
                           class = "my-margin",
                           h4("Raw response:"),
                           uiOutput("completeRawResponse")
                         ),
                         fluidRow(
                           class = "my-margin",
                           h4("Result:"),
                           uiOutput("completeExtractedResult")
                         )
                       ),
                       conditionalPanel(
                         condition = "input.llmProvider == 'none'",
                         p("Configure an LLM provider in the Configuration tab to see results here.")
                       )
              )
  )
)

UI_compare = ###################################### COMPARE UI ####################################
tabItem(
  tabName = "compare",
  h2("Compare descriptions"),
  h3("Purpose"),
  p("Compare to taxonomic descriptions, potentially in different languages"),
  h3("Input required"),
  tags$div(
    tags$ul(
      tags$li(tags$b("The output language desired.")," Edit the text box below to change."),
      tags$li(tags$b("Description 1.")," Edit the text box below to change."),
      tags$li(tags$b("Description 2.")," Edit the text box below to change.")
    )
  ),
  tabsetPanel(type = "tabs", id = "compareTabset",
              tabPanel("Input",
                       textInput(
                         "compareLanguage",
                         "Language to output",
                         value = read_file("defaults/language.txt")
                       ),
                       checkboxInput(
                         "compareSelectExclude",
                         "Only include characters observed in both descriptions"
                       ),
                       textAreaInput(
                         "compareDesc1",
                         "Description 1",
                         value = read_file("defaults/compare/description1.txt"),
                         rows = 10,
                         width = "100%"
                       ),
                       textAreaInput(
                         "compareDesc2",
                         "Description 2",
                         value = read_file("defaults/compare/description2.txt"),
                         rows = 10,
                         width = "100%"
                       )
              ),
              tabPanel("Generated prompt",
                       uiOutput("comparePromptUI")
              ),
              tabPanel("Results",
                       conditionalPanel(
                         condition = "input.llmProvider != 'none'",
                         fluidRow(
                           class = "my-margin",
                           h4("Raw response:"),
                           uiOutput("compareRawResponse")
                         ),
                         fluidRow(
                           class = "my-margin",
                           h4("Result:"),
                           uiOutput("compareExtractedResult")
                         )
                       ),
                       conditionalPanel(
                         condition = "input.llmProvider == 'none'",
                         p("Configure an LLM provider in the Configuration tab to see results here.")
                       )
              )
  )
  
)



###################################### WRITE UI ####################################
UI_write = tabItem(
  tabName = "table",
  h2("Natural language description"),
  h3("Purpose"),
  p("Given input characters and their states in table format, write them out as a natural-language description. This description follows the template provided."),
  h3("Input required"),
  tags$div(
    tags$ul(
      tags$li(tags$b("The output language desired.")," Edit the text box below to change."),
      tags$li(tags$b("Table.")," Provide a table of characters in csv or excel format."),
      tags$li(tags$b("Template description.")," Provide a natural-language description to use as template.")
    )
  ),
  tabsetPanel(type = "tabs", id = "writeTabset",
              tabPanel("Input",
                       textInput(
                         "writeLanguage",
                         "Language to output",
                         value = read_file("defaults/language.txt")
                       ),
                       fileInput(
                         "writeTableFile",
                         NULL,
                         accept = c(".csv", ".tsv", ".txt", ".xls", ".xlsx"),
                         buttonLabel = "Upload table..."
                       ),
                       DTOutput("writeTable"),
                       textAreaInput(
                         "writeTemplate",
                         "Description to use as template",
                         value = read_file("defaults/write/template_description.txt"),
                         rows = 10,
                         width = "100%"
                       )
              ),
              tabPanel("Generated prompt",
                       uiOutput("writePromptUI")
              ),
              tabPanel("Results",
                       conditionalPanel(
                         condition = "input.llmProvider != 'none'",
                         fluidRow(
                           class = "my-margin",
                           h4("Raw response:"),
                           uiOutput("writeRawResponse")
                         ),
                         fluidRow(
                           class = "my-margin",
                           h4("Result:"),
                           uiOutput("writeExtractedResult")
                         )
                       ),
                       conditionalPanel(
                         condition = "input.llmProvider == 'none'",
                         p("Configure an LLM provider in the Configuration tab to see results here.")
                       )
              )
  )
)


#################PARSE SPECIMEN LIST UI ####################################
UI_specimenParse = tabItem(
  tabName = "parseSpecimenList",
  h2("Parse table to list of examined specimens"),
  p("Lorem ipsum."),
  tabsetPanel(type = "tabs",
              tabPanel("Input"),
              tabPanel("Result"))
)


#################WRITE SPECIMEN LIST UI ####################################
UI_specimenWrite = tabItem(
  tabName = "writeSpecimenList",
  h2("Write list of examined specimens from table"),
  p("Lorem ipsum."),
  tabsetPanel(type = "tabs",
              tabPanel("Input"),
              tabPanel("Result"))
)