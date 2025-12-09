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
                      writeResponse = NULL
                      )

  chatGPTlink = a("Go to chatGPT", href = "https://chat.openai.com", target = "_blank", class="btn btn-primary")
  claudeLink = a("Go to Claude AI", href = "https://claude.ai", target = "_blank", class="btn btn-primary")


  ######################## CONFIG server-side ###########################
  #detect API keys on startup
  observe({
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

  #display configuration status
  output$configStatus = renderUI({
    if(input$llmProvider == "none"){
      tags$div(
        style = "padding: 15px; background-color: #d1ecf1; border: 1px solid #bee5eb; border-radius: 4px;",
        icon("info-circle"),
        " You are in copy-only mode. Generated prompts will include copy buttons and links to external LLM services."
      )
    } else if(input$llmProvider == "openai"){
      api_key = if(!is.null(input$openaiApiKey) && input$openaiApiKey != ""){
        input$openaiApiKey
      } else {
        rv$detectedKeys$openai$value
      }

      if(!is.null(api_key) && api_key != ""){
        tags$div(
          style = "padding: 15px; background-color: #d4edda; border: 1px solid #c3e6cb; border-radius: 4px;",
          icon("check-circle"),
          " OpenAI API configured. You can run prompts directly in the application using model: gpt-4o-mini"
        )
      } else {
        tags$div(
          style = "padding: 15px; background-color: #fff3cd; border: 1px solid #ffeaa7; border-radius: 4px;",
          icon("exclamation-triangle"),
          " Please provide an API key to enable direct prompt execution."
        )
      }
    } else if(input$llmProvider == "anthropic"){
      api_key = if(!is.null(input$anthropicApiKey) && input$anthropicApiKey != ""){
        input$anthropicApiKey
      } else {
        rv$detectedKeys$anthropic$value
      }

      if(!is.null(api_key) && api_key != ""){
        tags$div(
          style = "padding: 15px; background-color: #d4edda; border: 1px solid #c3e6cb; border-radius: 4px;",
          icon("check-circle"),
          " Anthropic API configured. You can run prompts directly in the application using model: claude-3-5-haiku-20241022"
        )
      } else {
        tags$div(
          style = "padding: 15px; background-color: #fff3cd; border: 1px solid #ffeaa7; border-radius: 4px;",
          icon("exclamation-triangle"),
          " Please provide an API key to enable direct prompt execution."
        )
      }
    } else if(input$llmProvider == "ollama"){
      tags$div(
        style = "padding: 15px; background-color: #d4edda; border: 1px solid #c3e6cb; border-radius: 4px;",
        icon("check-circle"),
        paste0(" Ollama configured at ", input$ollamaHost, ":", input$ollamaPort, " using model: ", input$ollamaModel)
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
        api_key = if(!is.null(input$openaiApiKey) && input$openaiApiKey != ""){
          input$openaiApiKey
        } else {
          rv$detectedKeys$openai$value
        }
        result = call_openai(rv$parseOutputPrompt, api_key)
      } else if(input$llmProvider == "anthropic"){
        api_key = if(!is.null(input$anthropicApiKey) && input$anthropicApiKey != ""){
          input$anthropicApiKey
        } else {
          rv$detectedKeys$anthropic$value
        }
        result = call_anthropic(rv$parseOutputPrompt, api_key)
      } else if(input$llmProvider == "ollama"){
        result = call_ollama(
          rv$parseOutputPrompt,
          input$ollamaHost,
          input$ollamaPort,
          input$ollamaModel
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
        api_key = if(!is.null(input$openaiApiKey) && input$openaiApiKey != ""){
          input$openaiApiKey
        } else {
          rv$detectedKeys$openai$value
        }
        result = call_openai(rv$completeOutputPrompt, api_key)
      } else if(input$llmProvider == "anthropic"){
        api_key = if(!is.null(input$anthropicApiKey) && input$anthropicApiKey != ""){
          input$anthropicApiKey
        } else {
          rv$detectedKeys$anthropic$value
        }
        result = call_anthropic(rv$completeOutputPrompt, api_key)
      } else if(input$llmProvider == "ollama"){
        result = call_ollama(
          rv$completeOutputPrompt,
          input$ollamaHost,
          input$ollamaPort,
          input$ollamaModel
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
        api_key = if(!is.null(input$openaiApiKey) && input$openaiApiKey != ""){
          input$openaiApiKey
        } else {
          rv$detectedKeys$openai$value
        }
        result = call_openai(rv$compareOutputPrompt, api_key)
      } else if(input$llmProvider == "anthropic"){
        api_key = if(!is.null(input$anthropicApiKey) && input$anthropicApiKey != ""){
          input$anthropicApiKey
        } else {
          rv$detectedKeys$anthropic$value
        }
        result = call_anthropic(rv$compareOutputPrompt, api_key)
      } else if(input$llmProvider == "ollama"){
        result = call_ollama(
          rv$compareOutputPrompt,
          input$ollamaHost,
          input$ollamaPort,
          input$ollamaModel
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
        api_key = if(!is.null(input$openaiApiKey) && input$openaiApiKey != ""){
          input$openaiApiKey
        } else {
          rv$detectedKeys$openai$value
        }
        result = call_openai(rv$writeOutputPrompt, api_key)
      } else if(input$llmProvider == "anthropic"){
        api_key = if(!is.null(input$anthropicApiKey) && input$anthropicApiKey != ""){
          input$anthropicApiKey
        } else {
          rv$detectedKeys$anthropic$value
        }
        result = call_anthropic(rv$writeOutputPrompt, api_key)
      } else if(input$llmProvider == "ollama"){
        result = call_ollama(
          rv$writeOutputPrompt,
          input$ollamaHost,
          input$ollamaPort,
          input$ollamaModel
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

###########TO DO
########### SPLIT INPUT TABLE IF TOO LONG
########### FIX UI

# Run the application
shinyApp(ui = ui, server = server)
