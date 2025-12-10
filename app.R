#
# This is a Shiny web application. You can run the application by clicking
# the "Run App" button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
library(shinydashboard)
library(shinyjs)
library(rclipboard)
library(dplyr)
library(readr)
library(stringr)
library(purrr)
library(tidyr)
library(tibble)
library(readxl)
library(DT)
library(httr2)
library(jsonlite)
library(callr)

#load functions first (needed for UI)
source("./code/functions.R")

#load UI pages
source("./code/UI.R")


ui <- dashboardPage(
  dashboardHeader(title = "GPTaxonomist"),
  
  dashboardSidebar(
    sidebarMenu(
      id = "sidebar",
      rclipboardSetup(),
      menuItem("Configuration", tabName = "config", icon = icon("gear")),
      menuItem(
        "Parse Description",
        tabName = "parse",
        icon = icon("list")
      ),
      menuItem(
        "Complete table",
        tabName = "complete",
        icon = icon("list-check")
      ),
      menuItem(
        "Compare Descriptions",
        tabName = "compare",
        icon = icon("code-compare")
      ),
      menuItem(
        "Table to description",
        tabName = "table",
        icon = icon("table")
      ),
      menuItem(
        "Parse specimen list",
        tabName = "parseSpecimenList",
        icon = icon("clipboard-list")
      ),
      menuItem(
        "Write specimen list",
        tabName = "writeSpecimenList",
        icon = icon("map-location")
      ),
      p(
        "Bruno de Medeiros, 2023 ",
        a(href = "https://github.com/de-Medeiros-insect-lab/GPTaxonomist", target = "_blank", icon("github")),
        align = "center"
      ),
      
      HTML(
        paste0(
          "<br>",
          '<a href="https://www.fieldmuseum.org/about/staff/profile/bruno-de-medeiros" target="_blank"><img style = "display: block; margin-left: auto; margin-right: auto; position: relative" src="Field_Logo_Std_Blue_CMYK.png" width = "186"></a>',
          "<br>"
        )
      )
    )
  ),
  
  dashboardBody(
    useShinyjs(),
    tags$head(
      tags$style(HTML(
        "
        .my-margin {
          margin-left: 10px;
        }
        .streaming-output {
          white-space: pre-wrap;
          max-height: 500px;
          overflow-y: auto;
          margin-top: 10px;
        }
        "
      )),
      tags$script(HTML("
        // Store scroll positions for streaming outputs
        var streamScrollPositions = {};
        var streamUserScrolled = {};

        // Function to check if user has scrolled up from bottom
        function isScrolledToBottom(el) {
          return el.scrollHeight - el.scrollTop - el.clientHeight < 50;
        }

        // Function to update streaming content while preserving scroll
        Shiny.addCustomMessageHandler('updateStreamContent', function(message) {
          var el = document.getElementById(message.id);
          if (el) {
            var wasAtBottom = isScrolledToBottom(el);
            var oldScrollTop = el.scrollTop;

            el.textContent = message.content;

            // If user was at bottom, scroll to new bottom; otherwise preserve position
            if (wasAtBottom) {
              el.scrollTop = el.scrollHeight;
            } else {
              el.scrollTop = oldScrollTop;
            }
          }
        });
      "))
    ),
    tabItems(
      UI_config,
      UI_parse,
      UI_complete,
      UI_compare,
      UI_write,
      UI_specimenParse,
      UI_specimenWrite
    )
  )
  )
      
      
      
      
    
  


# Server computations
server <- function(input, output, session) {
  #initialize reactive values
  rv = reactiveValues(parseExamplePath = "defaults/parse/example.csv",
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

  chatGPTlink = a("Go to chatGPT", href = "https://chat.openai.com", target = "_blank", class="btn btn-primary")
  claudeLink = a("Go to Claude AI", href = "https://claude.ai", target = "_blank", class="btn btn-primary")


  ######################## CONFIG server-side ###########################
  #detect API keys on startup - run immediately and store result
  rv$detectedKeys = detect_api_keys()

  #helper reactive to get the effective Ollama model
  getOllamaModel = reactive({
    #if dropdown exists and is not custom, use it
    if(!is.null(input$ollamaModelSelect) && input$ollamaModelSelect != "_custom_"){
      return(input$ollamaModelSelect)
    }
    #otherwise use custom text input
    if(!is.null(input$ollamaModelCustom) && input$ollamaModelCustom != ""){
      return(input$ollamaModelCustom)
    }
    #fallback to default
    return(ollama_default_model)
  })

  #helper reactive to get effective OpenAI API key
  getOpenAIKey = reactive({
    if(!is.null(input$openaiApiKey) && input$openaiApiKey != ""){
      return(input$openaiApiKey)
    }
    if(!is.null(rv$detectedKeys$openai$value) && rv$detectedKeys$openai$value != ""){
      return(rv$detectedKeys$openai$value)
    }
    return(NULL)
  })

  #helper reactive to get effective Anthropic API key
  getAnthropicKey = reactive({
    if(!is.null(input$anthropicApiKey) && input$anthropicApiKey != ""){
      return(input$anthropicApiKey)
    }
    if(!is.null(rv$detectedKeys$anthropic$value) && rv$detectedKeys$anthropic$value != ""){
      return(rv$detectedKeys$anthropic$value)
    }
    return(NULL)
  })

  #button to re-detect environment variables
  observeEvent(input$refreshEnvKeys, {
    rv$detectedKeys = detect_api_keys()
  })

  #display detected OpenAI key
  output$openaiKeyDetected = renderUI({
    if(!is.null(rv$detectedKeys$openai$masked)){
      tags$div(
        style = "padding: 10px; background-color: #d4edda; border: 1px solid #c3e6cb; border-radius: 4px; margin-bottom: 10px;",
        icon("check-circle"),
        " Detected API key in environment variable ",
        tags$code(rv$detectedKeys$openai$var_name),
        ": ",
        tags$code(rv$detectedKeys$openai$masked)
      )
    }
  })

  #display detected Anthropic key
  output$anthropicKeyDetected = renderUI({
    if(!is.null(rv$detectedKeys$anthropic$masked)){
      tags$div(
        style = "padding: 10px; background-color: #d4edda; border: 1px solid #c3e6cb; border-radius: 4px; margin-bottom: 10px;",
        icon("check-circle"),
        " Detected API key in environment variable ",
        tags$code(rv$detectedKeys$anthropic$var_name),
        ": ",
        tags$code(rv$detectedKeys$anthropic$masked)
      )
    }
  })

  #fetch OpenAI models when API key changes or refresh clicked
  observe({
    api_key = getOpenAIKey()
    #also react to refresh button
    input$refreshOpenaiModels

    if(!is.null(api_key) && api_key != ""){
      isolate({
        rv$openaiModels = fetch_openai_models(api_key)
      })
    } else {
      rv$openaiModels = NULL
    }
  })

  #fetch Anthropic models when API key changes or refresh clicked
  observe({
    api_key = getAnthropicKey()
    #also react to refresh button
    input$refreshAnthropicModels

    if(!is.null(api_key) && api_key != ""){
      isolate({
        rv$anthropicModels = fetch_anthropic_models(api_key)
      })
    } else {
      rv$anthropicModels = NULL
    }
  })

  #fetch Ollama models when host/port changes
  observeEvent(c(input$ollamaHost, input$ollamaPort, input$refreshOllamaModels), {
    req(input$ollamaHost, input$ollamaPort)
    rv$ollamaModels = fetch_ollama_models(input$ollamaHost, input$ollamaPort)
  }, ignoreNULL = FALSE)

  #render OpenAI model selection UI
  output$openaiModelUI = renderUI({
    result = rv$openaiModels

    if(is.null(result)){
      return(NULL)
    }

    if(result$success){
      tagList(
        selectInput(
          "openaiModel",
          "Model:",
          choices = result$models,
          selected = if("gpt-4o-mini" %in% result$models) "gpt-4o-mini" else result$models[1]
        ),
        actionButton("refreshOpenaiModels", "Refresh models", icon = icon("sync"), class = "btn-sm")
      )
    } else {
      tags$div(
        style = "padding: 10px; background-color: #fff3cd; border: 1px solid #ffeaa7; border-radius: 4px; margin-top: 10px;",
        icon("exclamation-triangle"),
        " ", result$error,
        tags$br(),
        actionButton("refreshOpenaiModels", "Retry", icon = icon("sync"), class = "btn-sm", style = "margin-top: 5px;")
      )
    }
  })

  #render Anthropic model selection UI
  output$anthropicModelUI = renderUI({
    result = rv$anthropicModels

    if(is.null(result)){
      return(NULL)
    }

    if(result$success){
      tagList(
        selectInput(
          "anthropicModel",
          "Model:",
          choices = result$models,
          selected = if("claude-3-5-haiku-20241022" %in% result$models) "claude-3-5-haiku-20241022" else result$models[1]
        ),
        actionButton("refreshAnthropicModels", "Refresh models", icon = icon("sync"), class = "btn-sm")
      )
    } else {
      tags$div(
        style = "padding: 10px; background-color: #fff3cd; border: 1px solid #ffeaa7; border-radius: 4px; margin-top: 10px;",
        icon("exclamation-triangle"),
        " ", result$error,
        tags$br(),
        actionButton("refreshAnthropicModels", "Retry", icon = icon("sync"), class = "btn-sm", style = "margin-top: 5px;")
      )
    }
  })

  #render Ollama model selection UI
  output$ollamaModelUI = renderUI({
    result = rv$ollamaModels

    #always show text input for custom model name, plus dropdown if models detected
    if(is.null(result)){
      return(tagList(
        textInput("ollamaModelCustom", "Model name:", value = ollama_default_model,
                  placeholder = "e.g., deepseek-r1:1.5b, llama3.2, mistral"),
        tags$div(
          style = "padding: 10px; background-color: #d1ecf1; border: 1px solid #bee5eb; border-radius: 4px;",
          icon("info-circle"),
          " Click 'Refresh' to detect locally installed models, or type any model name above."
        ),
        actionButton("refreshOllamaModels", "Refresh local models", icon = icon("sync"), class = "btn-sm", style = "margin-top: 5px;")
      ))
    }

    if(result$success){
      #add custom option to the choices
      model_choices = c("(custom)" = "_custom_", result$models)
      default_selected = if(ollama_default_model %in% result$models) ollama_default_model else result$models[1]

      tagList(
        selectInput(
          "ollamaModelSelect",
          "Select installed model:",
          choices = model_choices,
          selected = default_selected
        ),
        conditionalPanel(
          condition = "input.ollamaModelSelect == '_custom_'",
          textInput("ollamaModelCustom", "Custom model name:", value = "",
                    placeholder = "e.g., llama3.2, mistral, phi3")
        ),
        tags$small(
          class = "text-muted",
          "Only locally installed models are shown. Use ",
          tags$code("ollama pull <model>"),
          " to download new models, or select '(custom)' to enter any model name."
        ),
        actionButton("refreshOllamaModels", "Refresh", icon = icon("sync"), class = "btn-sm", style = "margin-top: 5px;")
      )
    } else {
      tagList(
        textInput("ollamaModelCustom", "Model name:", value = ollama_default_model,
                  placeholder = "e.g., deepseek-r1:1.5b, llama3.2, mistral"),
        tags$div(
          style = "padding: 10px; background-color: #fff3cd; border: 1px solid #ffeaa7; border-radius: 4px; margin-top: 10px;",
          icon("exclamation-triangle"),
          " ", result$error,
          tags$br(),
          tags$small("You can still enter a model name manually above.")
        ),
        actionButton("refreshOllamaModels", "Retry", icon = icon("sync"), class = "btn-sm", style = "margin-top: 5px;")
      )
    }
  })

  #display configuration status
  output$configStatus = renderUI({
    if(input$llmProvider == "none"){
      tags$div(
        style = "padding: 15px; background-color: #d1ecf1; border: 1px solid #bee5eb; border-radius: 4px;",
        icon("info-circle"),
        " You are in copy-only mode. Generated prompts will include copy buttons and links to external LLM services."
      )
    } else if(input$llmProvider == "openai"){
      api_key = getOpenAIKey()

      if(!is.null(api_key) && api_key != ""){
        model_name = if(!is.null(input$openaiModel)) input$openaiModel else "loading..."
        tags$div(
          style = "padding: 15px; background-color: #d4edda; border: 1px solid #c3e6cb; border-radius: 4px;",
          icon("check-circle"),
          paste0(" OpenAI API configured. You can run prompts directly in the application using model: ", model_name)
        )
      } else {
        tags$div(
          style = "padding: 15px; background-color: #fff3cd; border: 1px solid #ffeaa7; border-radius: 4px;",
          icon("exclamation-triangle"),
          " Please provide an API key to enable direct prompt execution."
        )
      }
    } else if(input$llmProvider == "anthropic"){
      api_key = getAnthropicKey()

      if(!is.null(api_key) && api_key != ""){
        model_name = if(!is.null(input$anthropicModel)) input$anthropicModel else "loading..."
        tags$div(
          style = "padding: 15px; background-color: #d4edda; border: 1px solid #c3e6cb; border-radius: 4px;",
          icon("check-circle"),
          paste0(" Anthropic API configured. You can run prompts directly in the application using model: ", model_name)
        )
      } else {
        tags$div(
          style = "padding: 15px; background-color: #fff3cd; border: 1px solid #ffeaa7; border-radius: 4px;",
          icon("exclamation-triangle"),
          " Please provide an API key to enable direct prompt execution."
        )
      }
    } else if(input$llmProvider == "ollama"){
      model_name = getOllamaModel()
      if(is.null(model_name) || model_name == ""){
        model_name = "not selected"
      }
      tags$div(
        style = "padding: 15px; background-color: #d4edda; border: 1px solid #c3e6cb; border-radius: 4px;",
        icon("check-circle"),
        paste0(" Ollama configured at ", input$ollamaHost, ":", input$ollamaPort, " using model: ", model_name)
      )
    }
  })
  
  
  
  ######################## PARSE server-side ###########################
  ### Reactive input handling
  #change example table if a new table uploaded
  observeEvent(input$parseExampleFile,
               {
                 rv$parseExamplePath = input$parseExampleFile$datapath
               })

  #update parsed example table
  observe({
    rv$parseExampleDF = read_table_robust(rv$parseExamplePath)
    rv$parseExampleDT = datatable(rv$parseExampleDF,
                                  filter = "none",
                                  options = list(dom = "t", ordering = F))
  })
  #update table in UI
  observe({
    output$parseTable1 = renderDT(datatable(
      read_table_robust(rv$parseExamplePath),
      filter = "none",
      options = list(dom = "t", ordering = F)
    ))
  })

  ### Generating output
  #generate prompt
  observe({
    req(rv$parseExampleDF, input$parseDesc, input$parseLanguage, input$outputFormat)
    rv$parseOutputPrompt = fill_parseDescription(
      input$parseDesc,
      input$parseLanguage,
      format_table_for_prompt(rv$parseExampleDF, input$outputFormat),
      input$outputFormat
    )
  })

  #render output prompt
  output$parseOutputPrompt = renderText(rv$parseOutputPrompt)

  #render prompt UI
  output$parsePromptUI <- renderUI({
    tagList(
      fluidRow(
        class = "my-margin",
        rclipButton(
          "parseOutputClip",
          "Copy to clipboard",
          if(!is.null(rv$parseOutputPrompt)) rv$parseOutputPrompt else ""
        ),
        if(input$llmProvider != "none"){
          actionButton(
            "parseRunPrompt",
            "Run Prompt",
            icon = icon("play"),
            class = "btn-success"
          )
        },
        chatGPTlink,
        claudeLink
      ),
      fluidRow(
        class = "my-margin",
        h4("Prompt:"),
        verbatimTextOutput("parseOutputPrompt")
      )
    )
  })


  #helper function to get app directory for background processes
  appDir = getwd()

  #wrapper function for background streaming that sources our functions
  runStreamingBg = function(provider, prompt, output_file, status_file, app_dir, ...) {
    setwd(app_dir)
    source("./code/functions.R")
    args = list(...)
    if(provider == "openai"){
      stream_openai_to_file(prompt, args$api_key, args$model, output_file, status_file)
    } else if(provider == "anthropic"){
      stream_anthropic_to_file(prompt, args$api_key, args$model, output_file, status_file)
    } else if(provider == "ollama"){
      stream_ollama_to_file(prompt, args$host, args$port, args$model, output_file, status_file)
    }
  }

  #handle Run Prompt button - start streaming in background
  observeEvent(input$parseRunPrompt, {
    #create temp files for streaming
    outputFile = tempfile(pattern = "stream_output_", fileext = ".txt")
    statusFile = tempfile(pattern = "stream_status_", fileext = ".txt")
    cat("starting", file = statusFile)
    cat("", file = outputFile)

    #clear previous result
    rv$parseResult = NULL

    #get parameters based on provider
    if(input$llmProvider == "openai"){
      api_key = getOpenAIKey()
      model = if(!is.null(input$openaiModel)) input$openaiModel else "gpt-4o-mini"
      rv$parseStreaming = list(
        active = TRUE,
        outputFile = outputFile,
        statusFile = statusFile,
        process = r_bg(
          runStreamingBg,
          args = list(
            provider = "openai",
            prompt = rv$parseOutputPrompt,
            output_file = outputFile,
            status_file = statusFile,
            app_dir = appDir,
            api_key = api_key,
            model = model
          ),
          package = TRUE
        )
      )
    } else if(input$llmProvider == "anthropic"){
      api_key = getAnthropicKey()
      model = if(!is.null(input$anthropicModel)) input$anthropicModel else "claude-3-5-haiku-20241022"
      rv$parseStreaming = list(
        active = TRUE,
        outputFile = outputFile,
        statusFile = statusFile,
        process = r_bg(
          runStreamingBg,
          args = list(
            provider = "anthropic",
            prompt = rv$parseOutputPrompt,
            output_file = outputFile,
            status_file = statusFile,
            app_dir = appDir,
            api_key = api_key,
            model = model
          ),
          package = TRUE
        )
      )
    } else if(input$llmProvider == "ollama"){
      rv$parseStreaming = list(
        active = TRUE,
        outputFile = outputFile,
        statusFile = statusFile,
        process = r_bg(
          runStreamingBg,
          args = list(
            provider = "ollama",
            prompt = rv$parseOutputPrompt,
            output_file = outputFile,
            status_file = statusFile,
            app_dir = appDir,
            host = input$ollamaHost,
            port = input$ollamaPort,
            model = getOllamaModel()
          ),
          package = TRUE
        )
      )
    }
  })

  #observer for parse streaming updates (polls without triggering UI rebuild)
  observe({
    streaming = rv$parseStreaming
    if(streaming$active && !is.null(streaming$statusFile) && file.exists(streaming$statusFile)){
      status = tryCatch(readLines(streaming$statusFile, warn = FALSE)[1], error = function(e) "")
      content = tryCatch(
        paste(readLines(streaming$outputFile, warn = FALSE), collapse = "\n"),
        error = function(e) ""
      )

      if(status == "running" || status == "starting"){
        #update content via JavaScript to preserve scroll position
        session$sendCustomMessage("updateStreamContent", list(
          id = "parseStreamingContent",
          content = content
        ))
        invalidateLater(200)  #poll every 200ms
      } else if(status == "success"){
        #streaming completed successfully
        rv$parseResult = list(success = TRUE, content = content)
        rv$parseStreaming = list(active = FALSE, outputFile = NULL, statusFile = NULL, process = NULL)
      } else if(startsWith(status, "error:")){
        #streaming encountered an error
        rv$parseResult = list(success = FALSE, error = substring(status, 7))
        rv$parseStreaming = list(active = FALSE, outputFile = NULL, statusFile = NULL, process = NULL)
      }
    }
  })

  #render raw response UI (only rebuilds when streaming state or result changes)
  output$parseRawResponse <- renderUI({
    streaming = rv$parseStreaming
    result = rv$parseResult

    if(streaming$active){
      #render streaming UI once - content updated via JS observer above
      tagList(
        tags$div(
          style = "padding: 10px; background-color: #d1ecf1; border: 1px solid #bee5eb; border-radius: 4px; margin-bottom: 10px;",
          icon("spinner", class = "fa-spin"),
          " Receiving response..."
        ),
        tags$pre(id = "parseStreamingContent", class = "streaming-output", "")
      )
    } else if(!is.null(result)){
      #show final result
      if(result$success){
        tags$div(
          rclipButton(
            "parseRawResponseClip",
            "Copy raw response",
            result$content,
            icon = icon("copy")
          ),
          tags$pre(class = "streaming-output", style = "margin-top: 10px;", result$content)
        )
      } else {
        tags$div(
          style = "padding: 10px; background-color: #f8d7da; border: 1px solid #f5c6cb; border-radius: 4px;",
          icon("exclamation-circle"),
          " Error: ", result$error
        )
      }
    }
  })

  #render extracted result
  output$parseExtractedResult <- renderUI({
    result = rv$parseResult
    if(is.null(result)){
      return(NULL)
    }

    if(result$success){
      extracted = extract_results(result$content)
      if(!is.null(extracted)){
        tags$div(
          rclipButton(
            "parseExtractedResultClip",
            "Copy result",
            extracted,
            icon = icon("copy")
          ),
          tags$pre(style = "white-space: pre-wrap; margin-top: 10px;", extracted)
        )
      } else {
        tags$div(
          style = "padding: 10px; background-color: #fff3cd; border: 1px solid #ffeaa7; border-radius: 4px;",
          icon("exclamation-triangle"),
          " No <results> tags found in response. The model may not have formatted the output correctly."
        )
      }
    }
  })


  ######################## COMPLETE server-side ###########################
  #change description table if a new table uploaded
  observeEvent(input$completeTableFile,
               {
                 rv$completeTablePath = input$completeTableFile$datapath
               })

  #update complete input table
  observe({
    rv$completeTableDF = read_table_robust(rv$completeTablePath)
    rv$completeTableDT = datatable(rv$completeTableDF,
                                  filter = "none",
                                  options = list(ordering = F))
  })
  #update input table in UI
  observe({
    output$completeTable1 = renderDT(datatable(
      read_table_robust(rv$completeTablePath),
      filter = "none",
      options = list(ordering = F)
    ))
  })

  #generate prompt
  observe({
    req(rv$completeTableDF, input$completeDesc, input$completeLanguage, input$outputFormat)
    rv$completeOutputPrompt = fill_completeTable(
      input$completeDesc,
      input$completeLanguage,
      rv$completeTableDF,
      input$outputFormat
    )
  })

  #render output prompt
  output$completeOutputPrompt = renderText(rv$completeOutputPrompt)

  #render prompt UI
  output$completePromptUI <- renderUI({
    tagList(
      fluidRow(
        class = "my-margin",
        rclipButton(
          "completeOutputClip",
          "Copy to clipboard",
          if(!is.null(rv$completeOutputPrompt)) rv$completeOutputPrompt else ""
        ),
        if(input$llmProvider != "none"){
          actionButton(
            "completeRunPrompt",
            "Run Prompt",
            icon = icon("play"),
            class = "btn-success"
          )
        },
        chatGPTlink,
        claudeLink
      ),
      fluidRow(
        class = "my-margin",
        h4("Prompt:"),
        verbatimTextOutput("completeOutputPrompt")
      )
    )
  })


  #handle Run Prompt button - start streaming in background
  observeEvent(input$completeRunPrompt, {
    #create temp files for streaming
    outputFile = tempfile(pattern = "stream_output_", fileext = ".txt")
    statusFile = tempfile(pattern = "stream_status_", fileext = ".txt")
    cat("starting", file = statusFile)
    cat("", file = outputFile)

    #clear previous result
    rv$completeResult = NULL

    #get parameters based on provider
    if(input$llmProvider == "openai"){
      api_key = getOpenAIKey()
      model = if(!is.null(input$openaiModel)) input$openaiModel else "gpt-4o-mini"
      rv$completeStreaming = list(
        active = TRUE,
        outputFile = outputFile,
        statusFile = statusFile,
        process = r_bg(
          runStreamingBg,
          args = list(
            provider = "openai",
            prompt = rv$completeOutputPrompt,
            output_file = outputFile,
            status_file = statusFile,
            app_dir = appDir,
            api_key = api_key,
            model = model
          ),
          package = TRUE
        )
      )
    } else if(input$llmProvider == "anthropic"){
      api_key = getAnthropicKey()
      model = if(!is.null(input$anthropicModel)) input$anthropicModel else "claude-3-5-haiku-20241022"
      rv$completeStreaming = list(
        active = TRUE,
        outputFile = outputFile,
        statusFile = statusFile,
        process = r_bg(
          runStreamingBg,
          args = list(
            provider = "anthropic",
            prompt = rv$completeOutputPrompt,
            output_file = outputFile,
            status_file = statusFile,
            app_dir = appDir,
            api_key = api_key,
            model = model
          ),
          package = TRUE
        )
      )
    } else if(input$llmProvider == "ollama"){
      rv$completeStreaming = list(
        active = TRUE,
        outputFile = outputFile,
        statusFile = statusFile,
        process = r_bg(
          runStreamingBg,
          args = list(
            provider = "ollama",
            prompt = rv$completeOutputPrompt,
            output_file = outputFile,
            status_file = statusFile,
            app_dir = appDir,
            host = input$ollamaHost,
            port = input$ollamaPort,
            model = getOllamaModel()
          ),
          package = TRUE
        )
      )
    }
  })

  #observer for complete streaming updates (polls without triggering UI rebuild)
  observe({
    streaming = rv$completeStreaming
    if(streaming$active && !is.null(streaming$statusFile) && file.exists(streaming$statusFile)){
      status = tryCatch(readLines(streaming$statusFile, warn = FALSE)[1], error = function(e) "")
      content = tryCatch(
        paste(readLines(streaming$outputFile, warn = FALSE), collapse = "\n"),
        error = function(e) ""
      )

      if(status == "running" || status == "starting"){
        #update content via JavaScript to preserve scroll position
        session$sendCustomMessage("updateStreamContent", list(
          id = "completeStreamingContent",
          content = content
        ))
        invalidateLater(200)  #poll every 200ms
      } else if(status == "success"){
        #streaming completed successfully
        rv$completeResult = list(success = TRUE, content = content)
        rv$completeStreaming = list(active = FALSE, outputFile = NULL, statusFile = NULL, process = NULL)
      } else if(startsWith(status, "error:")){
        #streaming encountered an error
        rv$completeResult = list(success = FALSE, error = substring(status, 7))
        rv$completeStreaming = list(active = FALSE, outputFile = NULL, statusFile = NULL, process = NULL)
      }
    }
  })

  #render raw response UI (only rebuilds when streaming state or result changes)
  output$completeRawResponse <- renderUI({
    streaming = rv$completeStreaming
    result = rv$completeResult

    if(streaming$active){
      #render streaming UI once - content updated via JS observer above
      tagList(
        tags$div(
          style = "padding: 10px; background-color: #d1ecf1; border: 1px solid #bee5eb; border-radius: 4px; margin-bottom: 10px;",
          icon("spinner", class = "fa-spin"),
          " Receiving response..."
        ),
        tags$pre(id = "completeStreamingContent", class = "streaming-output", "")
      )
    } else if(!is.null(result)){
      #show final result
      if(result$success){
        tags$div(
          rclipButton(
            "completeRawResponseClip",
            "Copy raw response",
            result$content,
            icon = icon("copy")
          ),
          tags$pre(class = "streaming-output", style = "margin-top: 10px;", result$content)
        )
      } else {
        tags$div(
          style = "padding: 10px; background-color: #f8d7da; border: 1px solid #f5c6cb; border-radius: 4px;",
          icon("exclamation-circle"),
          " Error: ", result$error
        )
      }
    }
  })

  #render extracted result
  output$completeExtractedResult <- renderUI({
    result = rv$completeResult
    if(is.null(result)){
      return(NULL)
    }

    if(result$success){
      extracted = extract_results(result$content)
      if(!is.null(extracted)){
        tags$div(
          rclipButton(
            "completeExtractedResultClip",
            "Copy result",
            extracted,
            icon = icon("copy")
          ),
          tags$pre(style = "white-space: pre-wrap; margin-top: 10px;", extracted)
        )
      } else {
        tags$div(
          style = "padding: 10px; background-color: #fff3cd; border: 1px solid #ffeaa7; border-radius: 4px;",
          icon("exclamation-triangle"),
          " No <results> tags found in response. The model may not have formatted the output correctly."
        )
      }
    }
  })




  ######################## COMPARE server-side ###########################
  #generate prompt
  observe({
    req(input$compareDesc1, input$compareDesc2, input$compareLanguage, input$outputFormat)
    rv$compareOutputPrompt = fill_compareDescriptions(
      description1 = input$compareDesc1,
      description2 = input$compareDesc2,
      language = input$compareLanguage,
      exclude_unique = input$compareSelectExclude,
      output_format = input$outputFormat
    )
  })

  #render output prompt
  output$compareOutputPrompt = renderText(rv$compareOutputPrompt)

  #render prompt UI
  output$comparePromptUI <- renderUI({
    tagList(
      fluidRow(
        class = "my-margin",
        rclipButton(
          "compareOutputClip",
          "Copy to clipboard",
          if(!is.null(rv$compareOutputPrompt)) rv$compareOutputPrompt else ""
        ),
        if(input$llmProvider != "none"){
          actionButton(
            "compareRunPrompt",
            "Run Prompt",
            icon = icon("play"),
            class = "btn-success"
          )
        },
        chatGPTlink,
        claudeLink
      ),
      fluidRow(
        class = "my-margin",
        h4("Prompt:"),
        verbatimTextOutput("compareOutputPrompt")
      )
    )
  })


  #handle Run Prompt button for Compare - start streaming in background
  observeEvent(input$compareRunPrompt, {
    #create temp files for streaming
    outputFile = tempfile(pattern = "stream_output_", fileext = ".txt")
    statusFile = tempfile(pattern = "stream_status_", fileext = ".txt")
    cat("starting", file = statusFile)
    cat("", file = outputFile)

    #clear previous result
    rv$compareResult = NULL

    #get parameters based on provider
    if(input$llmProvider == "openai"){
      api_key = getOpenAIKey()
      model = if(!is.null(input$openaiModel)) input$openaiModel else "gpt-4o-mini"
      rv$compareStreaming = list(
        active = TRUE,
        outputFile = outputFile,
        statusFile = statusFile,
        process = r_bg(
          runStreamingBg,
          args = list(
            provider = "openai",
            prompt = rv$compareOutputPrompt,
            output_file = outputFile,
            status_file = statusFile,
            app_dir = appDir,
            api_key = api_key,
            model = model
          ),
          package = TRUE
        )
      )
    } else if(input$llmProvider == "anthropic"){
      api_key = getAnthropicKey()
      model = if(!is.null(input$anthropicModel)) input$anthropicModel else "claude-3-5-haiku-20241022"
      rv$compareStreaming = list(
        active = TRUE,
        outputFile = outputFile,
        statusFile = statusFile,
        process = r_bg(
          runStreamingBg,
          args = list(
            provider = "anthropic",
            prompt = rv$compareOutputPrompt,
            output_file = outputFile,
            status_file = statusFile,
            app_dir = appDir,
            api_key = api_key,
            model = model
          ),
          package = TRUE
        )
      )
    } else if(input$llmProvider == "ollama"){
      rv$compareStreaming = list(
        active = TRUE,
        outputFile = outputFile,
        statusFile = statusFile,
        process = r_bg(
          runStreamingBg,
          args = list(
            provider = "ollama",
            prompt = rv$compareOutputPrompt,
            output_file = outputFile,
            status_file = statusFile,
            app_dir = appDir,
            host = input$ollamaHost,
            port = input$ollamaPort,
            model = getOllamaModel()
          ),
          package = TRUE
        )
      )
    }
  })

  #observer for compare streaming updates (polls without triggering UI rebuild)
  observe({
    streaming = rv$compareStreaming
    if(streaming$active && !is.null(streaming$statusFile) && file.exists(streaming$statusFile)){
      status = tryCatch(readLines(streaming$statusFile, warn = FALSE)[1], error = function(e) "")
      content = tryCatch(
        paste(readLines(streaming$outputFile, warn = FALSE), collapse = "\n"),
        error = function(e) ""
      )

      if(status == "running" || status == "starting"){
        #update content via JavaScript to preserve scroll position
        session$sendCustomMessage("updateStreamContent", list(
          id = "compareStreamingContent",
          content = content
        ))
        invalidateLater(200)  #poll every 200ms
      } else if(status == "success"){
        #streaming completed successfully
        rv$compareResult = list(success = TRUE, content = content)
        rv$compareStreaming = list(active = FALSE, outputFile = NULL, statusFile = NULL, process = NULL)
      } else if(startsWith(status, "error:")){
        #streaming encountered an error
        rv$compareResult = list(success = FALSE, error = substring(status, 7))
        rv$compareStreaming = list(active = FALSE, outputFile = NULL, statusFile = NULL, process = NULL)
      }
    }
  })

  #render raw response UI for Compare (only rebuilds when streaming state or result changes)
  output$compareRawResponse <- renderUI({
    streaming = rv$compareStreaming
    result = rv$compareResult

    if(streaming$active){
      #render streaming UI once - content updated via JS observer above
      tagList(
        tags$div(
          style = "padding: 10px; background-color: #d1ecf1; border: 1px solid #bee5eb; border-radius: 4px; margin-bottom: 10px;",
          icon("spinner", class = "fa-spin"),
          " Receiving response..."
        ),
        tags$pre(id = "compareStreamingContent", class = "streaming-output", "")
      )
    } else if(!is.null(result)){
      #show final result
      if(result$success){
        tags$div(
          rclipButton(
            "compareRawResponseClip",
            "Copy raw response",
            result$content,
            icon = icon("copy")
          ),
          tags$pre(class = "streaming-output", style = "margin-top: 10px;", result$content)
        )
      } else {
        tags$div(
          style = "padding: 10px; background-color: #f8d7da; border: 1px solid #f5c6cb; border-radius: 4px;",
          icon("exclamation-circle"),
          " Error: ", result$error
        )
      }
    }
  })

  #render extracted result for Compare
  output$compareExtractedResult <- renderUI({
    result = rv$compareResult
    if(is.null(result)){
      return(NULL)
    }

    if(result$success){
      extracted = extract_results(result$content)
      if(!is.null(extracted)){
        tags$div(
          rclipButton(
            "compareExtractedResultClip",
            "Copy result",
            extracted,
            icon = icon("copy")
          ),
          tags$pre(style = "white-space: pre-wrap; margin-top: 10px;", extracted)
        )
      } else {
        tags$div(
          style = "padding: 10px; background-color: #fff3cd; border: 1px solid #ffeaa7; border-radius: 4px;",
          icon("exclamation-triangle"),
          " No <results> tags found in response. The model may not have formatted the output correctly."
        )
      }
    }
  })
  
  
  
  ######################## WRITE server-side ###########################
  ### Reactive input handling
  #change example table if a new table uploaded
  observeEvent(input$writeTableFile,
               {
                 rv$writeTablePath = input$writeTableFile$datapath
               })

  #update parsed example table
  observe({
    rv$writeTableDF = read_table_robust(rv$writeTablePath)
    rv$writeTableDT = datatable(rv$writeTableDF,
                                  filter = "none",
                                  options = list(dom = "t", ordering = F))
  })
  #update table in UI
  observe({
    output$writeTable = renderDT(datatable(
      read_table_robust(rv$writeTablePath),
      filter = "none",
      options = list(dom = "t", ordering = F)
    ))
  })

  #generate output
  observe({
    req(rv$writeTableDF, input$writeTemplate, input$writeLanguage)
    rv$writeOutputPrompt = fill_writeDescription(
      character_table = rv$writeTableDF,
      template_description = input$writeTemplate,
      language = input$writeLanguage
    )
  })

  #render output prompt
  output$writeOutputPrompt = renderText(rv$writeOutputPrompt)

  #render prompt UI
  output$writePromptUI <- renderUI({
    tagList(
      fluidRow(
        class = "my-margin",
        rclipButton(
          "writeOutputClip",
          "Copy to clipboard",
          if(!is.null(rv$writeOutputPrompt)) rv$writeOutputPrompt else ""
        ),
        if(input$llmProvider != "none"){
          actionButton(
            "writeRunPrompt",
            "Run Prompt",
            icon = icon("play"),
            class = "btn-success"
          )
        },
        chatGPTlink,
        claudeLink
      ),
      fluidRow(
        class = "my-margin",
        h4("Prompt:"),
        verbatimTextOutput("writeOutputPrompt")
      )
    )
  })


  #handle Run Prompt button for Write - start streaming in background
  observeEvent(input$writeRunPrompt, {
    #create temp files for streaming
    outputFile = tempfile(pattern = "stream_output_", fileext = ".txt")
    statusFile = tempfile(pattern = "stream_status_", fileext = ".txt")
    cat("starting", file = statusFile)
    cat("", file = outputFile)

    #clear previous result
    rv$writeResult = NULL

    #get parameters based on provider
    if(input$llmProvider == "openai"){
      api_key = getOpenAIKey()
      model = if(!is.null(input$openaiModel)) input$openaiModel else "gpt-4o-mini"
      rv$writeStreaming = list(
        active = TRUE,
        outputFile = outputFile,
        statusFile = statusFile,
        process = r_bg(
          runStreamingBg,
          args = list(
            provider = "openai",
            prompt = rv$writeOutputPrompt,
            output_file = outputFile,
            status_file = statusFile,
            app_dir = appDir,
            api_key = api_key,
            model = model
          ),
          package = TRUE
        )
      )
    } else if(input$llmProvider == "anthropic"){
      api_key = getAnthropicKey()
      model = if(!is.null(input$anthropicModel)) input$anthropicModel else "claude-3-5-haiku-20241022"
      rv$writeStreaming = list(
        active = TRUE,
        outputFile = outputFile,
        statusFile = statusFile,
        process = r_bg(
          runStreamingBg,
          args = list(
            provider = "anthropic",
            prompt = rv$writeOutputPrompt,
            output_file = outputFile,
            status_file = statusFile,
            app_dir = appDir,
            api_key = api_key,
            model = model
          ),
          package = TRUE
        )
      )
    } else if(input$llmProvider == "ollama"){
      rv$writeStreaming = list(
        active = TRUE,
        outputFile = outputFile,
        statusFile = statusFile,
        process = r_bg(
          runStreamingBg,
          args = list(
            provider = "ollama",
            prompt = rv$writeOutputPrompt,
            output_file = outputFile,
            status_file = statusFile,
            app_dir = appDir,
            host = input$ollamaHost,
            port = input$ollamaPort,
            model = getOllamaModel()
          ),
          package = TRUE
        )
      )
    }
  })

  #observer for write streaming updates (polls without triggering UI rebuild)
  observe({
    streaming = rv$writeStreaming
    if(streaming$active && !is.null(streaming$statusFile) && file.exists(streaming$statusFile)){
      status = tryCatch(readLines(streaming$statusFile, warn = FALSE)[1], error = function(e) "")
      content = tryCatch(
        paste(readLines(streaming$outputFile, warn = FALSE), collapse = "\n"),
        error = function(e) ""
      )

      if(status == "running" || status == "starting"){
        #update content via JavaScript to preserve scroll position
        session$sendCustomMessage("updateStreamContent", list(
          id = "writeStreamingContent",
          content = content
        ))
        invalidateLater(200)  #poll every 200ms
      } else if(status == "success"){
        #streaming completed successfully
        rv$writeResult = list(success = TRUE, content = content)
        rv$writeStreaming = list(active = FALSE, outputFile = NULL, statusFile = NULL, process = NULL)
      } else if(startsWith(status, "error:")){
        #streaming encountered an error
        rv$writeResult = list(success = FALSE, error = substring(status, 7))
        rv$writeStreaming = list(active = FALSE, outputFile = NULL, statusFile = NULL, process = NULL)
      }
    }
  })

  #render raw response UI for Write (only rebuilds when streaming state or result changes)
  output$writeRawResponse <- renderUI({
    streaming = rv$writeStreaming
    result = rv$writeResult

    if(streaming$active){
      #render streaming UI once - content updated via JS observer above
      tagList(
        tags$div(
          style = "padding: 10px; background-color: #d1ecf1; border: 1px solid #bee5eb; border-radius: 4px; margin-bottom: 10px;",
          icon("spinner", class = "fa-spin"),
          " Receiving response..."
        ),
        tags$pre(id = "writeStreamingContent", class = "streaming-output", "")
      )
    } else if(!is.null(result)){
      #show final result
      if(result$success){
        tags$div(
          rclipButton(
            "writeRawResponseClip",
            "Copy raw response",
            result$content,
            icon = icon("copy")
          ),
          tags$pre(class = "streaming-output", style = "margin-top: 10px;", result$content)
        )
      } else {
        tags$div(
          style = "padding: 10px; background-color: #f8d7da; border: 1px solid #f5c6cb; border-radius: 4px;",
          icon("exclamation-circle"),
          " Error: ", result$error
        )
      }
    }
  })

  #render extracted result for Write
  output$writeExtractedResult <- renderUI({
    result = rv$writeResult
    if(is.null(result)){
      return(NULL)
    }

    if(result$success){
      extracted = extract_results(result$content)
      if(!is.null(extracted)){
        tags$div(
          rclipButton(
            "writeExtractedResultClip",
            "Copy result",
            extracted,
            icon = icon("copy")
          ),
          tags$pre(style = "white-space: pre-wrap; margin-top: 10px;", extracted)
        )
      } else {
        tags$div(
          style = "padding: 10px; background-color: #fff3cd; border: 1px solid #ffeaa7; border-radius: 4px;",
          icon("exclamation-triangle"),
          " No <results> tags found in response. The model may not have formatted the output correctly."
        )
      }
    }
  })
  
  
}

# Run the application
shinyApp(ui = ui, server = server)
