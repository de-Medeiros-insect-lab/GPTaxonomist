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
library(tidyverse)
library(DT)

#load UI pages
source("./code/UI.R")


ui <- dashboardPage(
  dashboardHeader(title = "GPTaxonomist"),
  
  dashboardSidebar(
    sidebarMenu(
      id = "sidebar",
      rclipboardSetup(),
      menuItem("Home", tabName = "home", icon = icon("home")),
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
      p("Bruno de Medeiros, 2023", align = "center"),
      
      HTML(
        paste0(
          "<br>",
          '<a href="https://www.fieldmuseum.org/about/staff/profile/bruno-de-medeiros" target="_blank"><img style = "display: block; margin-left: auto; margin-right: auto; position: relative" src="Field_Logo_Std_Blue_CMYK.png", width = "186"></a>',
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
      tabItem(
        tabName = "home",
        h2("Welcome!"),
        p(
          "This is an interactive tool to help generating useful prompts for doing taxonomic tasks using large language models such as chatGPT and Bard. Check the menu on the left for different tasks."
        ),
        p(
          "All tasks include default values as examples, change them to use your own data as input."
        )
      ),
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
  #read functions
  source("code/functions.R")
  
  #initialize reactive values
  rv = reactiveValues(parseExamplePath = "defaults/parse/example.csv",
                      completeTablePath = "defaults/complete/table.csv",
                      writeTablePath = "defaults/write/input_table.csv"
                      )
  
  chatGPTlink = a("Go to chatGPT", href = "https://chat.openai.com", target = "_blank", class="btn btn-primary")
  claudeLink = a("Go to Claude AI", href = "https://claude.ai", target = "_blank", class="btn btn-primary")
  
  
  
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
      options = list(dom = "t", ordering =
                       F)
    ))
    
  })
  ### Generating output
  #process parsing input and produce text blocks
  observe({
    rv$parseParagraphs = group_paragraphs(input$parseDesc)
    
    rv$parseOutputPrompts = purrr::map(
      rv$parseParagraphs,
      ~ fill_parseDescription(
        .x,
        input$parseLanguage,
        format_table(rv$parseExampleDF)
      )
    )
  })
  #create rendered output prompts
  observe({
    lapply(1:length(rv$parseOutputPrompts), function(i) {
      local({
        local_i <- i
        output[[str_c("parseOutputPrompt", local_i, sep = "")]] <-
          renderText({
            rv$parseOutputPrompts[[local_i]]
          })
      })
    })
  })
  #dynamically create output tabs
  observe({
    rv$parseOutputTabs = lapply(1:length(rv$parseOutputPrompts),
                                function(.x)
                                  tabPanel(
                                    title = str_c("Prompt", .x, sep = " "),
                                    value = str_c("Prompt", .x, sep = ""),
                                    fluidRow(
                                      class = "my-margin",
                                      rclipButton(
                                        str_c("parseOutputClip", .x, sep = ""),
                                        "Copy to clipboard",
                                        rv$parseOutputPrompts[[.x]]
                                        ),
                                      chatGPTlink,
                                      claudeLink
                                    ),
                                    fluidRow(class = "my-margin",
                                             verbatimTextOutput(str_c("parseOutputPrompt", .x, sep = ""))),
                                  ))
  })
  #join output tabs
  observe({
    output$parseOutputTabs = renderUI({
      do.call(navlistPanel, rv$parseOutputTabs)
    })
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
  #process COMPLETE input and produce text blocks
  observe({
    
    rv$completeTableRows = group_table_rows(rv$completeTableDF)
    
    rv$completeOutputPrompts = purrr::map(
      rv$completeTableRows,
      ~ fill_completeTable(input$completeDesc,input$completeLanguage,.x))
  })
  #create rendered output prompts
  observe({
    lapply(1:length(rv$completeOutputPrompts), function(i) {
      local({
        local_i <- i
        output[[str_c("completeOutputPrompt", local_i, sep = "")]] <-
          renderText({
            rv$completeOutputPrompts[[local_i]]
          })
      })
    })
  })
  #dynamically create output tabs
  observe({
    rv$completeOutputTabs = lapply(1:length(rv$completeOutputPrompts),
                                   function(.x)
                                     tabPanel(
                                       title = str_c("Prompt", .x, sep = " "),
                                       value = str_c("Prompt", .x, sep = ""),
                                       fluidRow(
                                         class = "my-margin",
                                         rclipButton(
                                           str_c("completeOutputClip", .x, sep = ""),
                                           "Copy to clipboard",
                                           rv$completeOutputPrompts[[.x]]
                                         ),
                                         chatGPTlink,
                                         claudeLink
                                       ),
                                       fluidRow(class = "my-margin",
                                                verbatimTextOutput(str_c("completeOutputPrompt", .x, sep = ""))
                                       )
                                       
                                     ))
  })
  #join output tabs
  observe({
    output$completeOutputTabs = renderUI({
      do.call(navlistPanel, rv$completeOutputTabs)
    })
  })
  
  
  
  
  ######################## COMPARE server-side ###########################
  observe({
    
    rv$compareOutputPrompt = fill_compareDescriptions(
      description1 = input$compareDesc1,
      description2 = input$compareDesc2,
      language = input$compareLanguage,
      exclude_unique = input$compareSelectExclude
    )
    output$compareOutputPrompt = renderText(rv$compareOutputPrompt)
    output$compareOutputUI = renderUI({
      fluidPage(
        fluidRow("This function does not check input size. If your prompt is too long, consider reducing the input descriptions. For example, by comparing paragraphs instead of whole descriptions."),
        fluidRow(
          rclipButton(
          "compareOutputClip",
          "Copy to clipboard",
          rv$compareOutputPrompt
          ),
        chatGPTlink,
        claudeLink
      ),
      fluidRow(verbatimTextOutput("compareOutputPrompt"))
      )
    }
    )
    
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
    
    rv$writeOutputPrompt = fill_writeDescription(
      character_table = rv$writeTableDF,
      template_description = input$writeTemplate,
      language = input$writeLanguage
    )
    output$writeOutputPrompt = renderText(rv$writeOutputPrompt)
    output$writeOutputUI = renderUI({
      fluidPage(
        fluidRow("This function does not check input size. If your prompt is too long, consider reducing the input. For example, by using as template a single paragraph at a time."),
        fluidRow(
          rclipButton(
            "writeOutputClip",
            "Copy to clipboard",
            rv$writeOutputPrompt
          ),
          chatGPTlink,
          claudeLink
        ),
        fluidRow(verbatimTextOutput("writeOutputPrompt"))
      )
    }
    )
    
  })
  
  
}

###########TO DO
########### SPLIT INPUT TABLE IF TOO LONG
########### FIX UI

# Run the application
shinyApp(ui = ui, server = server)
