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
    tags$head(tags$style(HTML(
      "
        .my-margin {
          margin-left: 10px;
        }
      "
    ))),
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
server <- function(input, output) {
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
                      ollamaModels = NULL
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


  #handle Run Prompt button
  observeEvent(input$parseRunPrompt, {
    withProgress(message = 'Running prompt...', value = 0, {

      #get API key based on provider
      api_key = NULL
      result = NULL

      if(input$llmProvider == "openai"){
        api_key = getOpenAIKey()
        model = if(!is.null(input$openaiModel)) input$openaiModel else "gpt-4o-mini"
        result = call_openai(rv$parseOutputPrompt, api_key, model)
      } else if(input$llmProvider == "anthropic"){
        api_key = getAnthropicKey()
        model = if(!is.null(input$anthropicModel)) input$anthropicModel else "claude-3-5-haiku-20241022"
        result = call_anthropic(rv$parseOutputPrompt, api_key, model)
      } else if(input$llmProvider == "ollama"){
        result = call_ollama(
          rv$parseOutputPrompt,
          input$ollamaHost,
          input$ollamaPort,
          getOllamaModel()
        )
      }

      #store result
      rv$parseResult = result
    })
  })

  #render raw response
  output$parseRawResponse <- renderUI({
    result = rv$parseResult
    if(is.null(result)){
      return(NULL)
    }

    if(result$success){
      tags$div(
        rclipButton(
          "parseRawResponseClip",
          "Copy raw response",
          result$content,
          icon = icon("copy")
        ),
        tags$pre(style = "white-space: pre-wrap; margin-top: 10px;", result$content)
      )
    } else {
      tags$div(
        style = "padding: 10px; background-color: #f8d7da; border: 1px solid #f5c6cb; border-radius: 4px;",
        icon("exclamation-circle"),
        " Error: ", result$error
      )
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


  #handle Run Prompt button
  observeEvent(input$completeRunPrompt, {
    withProgress(message = 'Running prompt...', value = 0, {

      #get API key based on provider
      api_key = NULL
      result = NULL

      if(input$llmProvider == "openai"){
        api_key = getOpenAIKey()
        model = if(!is.null(input$openaiModel)) input$openaiModel else "gpt-4o-mini"
        result = call_openai(rv$completeOutputPrompt, api_key, model)
      } else if(input$llmProvider == "anthropic"){
        api_key = getAnthropicKey()
        model = if(!is.null(input$anthropicModel)) input$anthropicModel else "claude-3-5-haiku-20241022"
        result = call_anthropic(rv$completeOutputPrompt, api_key, model)
      } else if(input$llmProvider == "ollama"){
        result = call_ollama(
          rv$completeOutputPrompt,
          input$ollamaHost,
          input$ollamaPort,
          getOllamaModel()
        )
      }

      #store result
      rv$completeResult = result
    })
  })

  #render raw response
  output$completeRawResponse <- renderUI({
    result = rv$completeResult
    if(is.null(result)){
      return(NULL)
    }

    if(result$success){
      tags$div(
        rclipButton(
          "completeRawResponseClip",
          "Copy raw response",
          result$content,
          icon = icon("copy")
        ),
        tags$pre(style = "white-space: pre-wrap; margin-top: 10px;", result$content)
      )
    } else {
      tags$div(
        style = "padding: 10px; background-color: #f8d7da; border: 1px solid #f5c6cb; border-radius: 4px;",
        icon("exclamation-circle"),
        " Error: ", result$error
      )
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


  #handle Run Prompt button for Compare
  observeEvent(input$compareRunPrompt, {
    withProgress(message = 'Running prompt...', value = 0, {

      #get API key based on provider
      api_key = NULL
      result = NULL

      if(input$llmProvider == "openai"){
        api_key = getOpenAIKey()
        model = if(!is.null(input$openaiModel)) input$openaiModel else "gpt-4o-mini"
        result = call_openai(rv$compareOutputPrompt, api_key, model)
      } else if(input$llmProvider == "anthropic"){
        api_key = getAnthropicKey()
        model = if(!is.null(input$anthropicModel)) input$anthropicModel else "claude-3-5-haiku-20241022"
        result = call_anthropic(rv$compareOutputPrompt, api_key, model)
      } else if(input$llmProvider == "ollama"){
        result = call_ollama(
          rv$compareOutputPrompt,
          input$ollamaHost,
          input$ollamaPort,
          getOllamaModel()
        )
      }

      #store result
      rv$compareResult = result
    })
  })

  #render raw response for Compare
  output$compareRawResponse <- renderUI({
    result = rv$compareResult
    if(is.null(result)){
      return(NULL)
    }

    if(result$success){
      tags$div(
        rclipButton(
          "compareRawResponseClip",
          "Copy raw response",
          result$content,
          icon = icon("copy")
        ),
        tags$pre(style = "white-space: pre-wrap; margin-top: 10px;", result$content)
      )
    } else {
      tags$div(
        style = "padding: 10px; background-color: #f8d7da; border: 1px solid #f5c6cb; border-radius: 4px;",
        icon("exclamation-circle"),
        " Error: ", result$error
      )
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


  #handle Run Prompt button for Write
  observeEvent(input$writeRunPrompt, {
    withProgress(message = 'Running prompt...', value = 0, {

      #get API key based on provider
      api_key = NULL
      result = NULL

      if(input$llmProvider == "openai"){
        api_key = getOpenAIKey()
        model = if(!is.null(input$openaiModel)) input$openaiModel else "gpt-4o-mini"
        result = call_openai(rv$writeOutputPrompt, api_key, model)
      } else if(input$llmProvider == "anthropic"){
        api_key = getAnthropicKey()
        model = if(!is.null(input$anthropicModel)) input$anthropicModel else "claude-3-5-haiku-20241022"
        result = call_anthropic(rv$writeOutputPrompt, api_key, model)
      } else if(input$llmProvider == "ollama"){
        result = call_ollama(
          rv$writeOutputPrompt,
          input$ollamaHost,
          input$ollamaPort,
          getOllamaModel()
        )
      }

      #store result
      rv$writeResult = result
    })
  })

  #render raw response for Write
  output$writeRawResponse <- renderUI({
    result = rv$writeResult
    if(is.null(result)){
      return(NULL)
    }

    if(result$success){
      tags$div(
        rclipButton(
          "writeRawResponseClip",
          "Copy raw response",
          result$content,
          icon = icon("copy")
        ),
        tags$pre(style = "white-space: pre-wrap; margin-top: 10px;", result$content)
      )
    } else {
      tags$div(
        style = "padding: 10px; background-color: #f8d7da; border: 1px solid #f5c6cb; border-radius: 4px;",
        icon("exclamation-circle"),
        " Error: ", result$error
      )
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
