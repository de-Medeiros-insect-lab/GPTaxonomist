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
    tags$head(
      tags$style(
        HTML("
        .my-margin {
          margin-left: 10px;
        }
      ")
      )),
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
      
      
      
      ###################################### PARSE UI ####################################
      tabItem(
        tabName = "parse",
        h2("Parse descriptions"),
        h3("Purpose"),
        p("Generate a prompt to parse a taxonomic description in natural language into a table that can be copied and pasted"),
        h3("Input required"),
        tags$div(
          tags$ul(
            tags$li(tags$b("The output language desired.")," Edit the text box below to change."),
            tags$li(tags$b("The description to parse.")," Edit the text box below to change."),
            tags$li(tags$b("A table with examples.")," only use 5-10 examples. Create a table, export it in CSV format and upload it here using the button below.")
          )
          ),

        
        tabsetPanel(
          type = "tabs",
          tabPanel(
            "Input",
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
            p("Upload a CSV file to change examples."),
            fileInput(
              "parseExampleFile",
              NULL,
              accept = ".csv",
              buttonLabel = "Upload csv..."
            ),
            DTOutput("parseTable1")
          ),
          tabPanel(
            "Results",
            p("If your input description was too long, we automatically split it in smaller chuncks by paragraph so it is possible to use chatGPT or Bard."),
            p(
              "Navigate the tabs below to see the prompts generated. 
                              Copy and paste them in chatGPT or Bard to get the desired result. 
                              If GPT response is too long and the response get cut in the middle, use the following to continue:",
              tags$i("Continue from the last incomplete row, repeat table headers.")
            ),
            uiOutput("parseOutputTabs")
          )
        )
      ),
      
      
      
      ###################################### COMPLETE UI ####################################
      tabItem(
        tabName = "complete",
        h2("Complete table"),
        h3("Purpose"),
        p("To generate a prompt to parse a taxonomic description in natural language and add characters to a pre-made table."),
        h3("Input required"),
        tags$div(
          tags$ul(
            tags$li(tags$b("The output language desired."), " Edit the text box below to change."),
            tags$li(tags$b("The description to parse.")," Edit the text box below to change."),
            tags$li(tags$b("A table to be filled out.")," This must include 2 columns: one with character names and another with observed states for an example species. The second column may be blank, but it will work better if not. Create a table, export it in CSV format and upload it here using the button below.")
          )
          ),
        tabsetPanel(type = "tabs",
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
                             p("Upload a CSV file to change the table."),
                             fileInput(
                               "completeTableFile",
                               NULL,
                               accept = ".csv",
                               buttonLabel = "Upload csv..."
                             ),
                             DTOutput("completeTable1")
                             ),
                    tabPanel("Result",
                             p("If your input table was too long, we automatically split it in smaller tables so it is possible to use chatGPT or Bard."),
                             p(
                              "Navigate the tabs below to see the prompts generated. 
                              Copy and paste them in chatGPT or Bard to get the desired result. 
                              If GPT response is too long and the response get cut in the middle, use the following to continue:",
                              tags$i("Continue from the last incomplete row, repeat table headers.")
                             ),
                             uiOutput("completeOutputTabs")
                             ))
      ),
      
      
      ###################################### COMPARE UI ####################################
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
        tabsetPanel(type = "tabs",
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
                    tabPanel("Result",
                             p("Use the prompt below to compare the descriptions and get a table."),
                             uiOutput("compareOutputUI")
                    )
        )
        
      ),
      
      
      ###################################### WRITE UI ####################################
      tabItem(
        tabName = "table",
        h2("Natural language description"),
        h3("Purpose"),
        p("Given input characters and their states in table format, write them out as a natural-language description. This description follows the template provided."),
        h3("Input required"),
        tags$div(
          tags$ul(
            tags$li(tags$b("The output language desired.")," Edit the text box below to change."),
            tags$li(tags$b("Table.")," Provide a table of characters in csv format."),
            tags$li(tags$b("Template description.")," Provide a natural-language description to use as template.")
          )
        ),
        tabsetPanel(type = "tabs",
                    tabPanel("Input",
                             textInput(
                               "writeLanguage",
                               "Language to output",
                               value = read_file("defaults/language.txt")
                             ),
                             fileInput(
                               "writeTableFile",
                               NULL,
                               accept = ".csv",
                               buttonLabel = "Upload csv..."
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
                    tabPanel("Result",
                             p("Use the prompt below to create a natural language description from a table."),
                             uiOutput("writeOutputUI")
                             )
      )
      ),
      tabItem(
        tabName = "parseSpecimenList",
        h2("Parse table to list of examined specimens"),
        p("Lorem ipsum."),
        tabsetPanel(type = "tabs",
                    tabPanel("Input"),
                    tabPanel("Result"))
      ),
      tabItem(
        tabName = "writeSpecimenList",
        h2("Write list of examined specimens from table"),
        p("Lorem ipsum."),
        tabsetPanel(type = "tabs",
                    tabPanel("Input"),
                    tabPanel("Result"))
      )
      
    )))
      
      
      
      
    
  


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
  bardlink = a("Go to Google Bard", href = "https://bard.google.com", target = "_blank", class="btn btn-primary")
  
  
  ######################## PARSE server-side ###########################
  ### Reactive input handling
  #change example table if a new table uploaded
  observeEvent(input$parseExampleFile,
               {
                 rv$parseExamplePath = input$parseExampleFile$datapath
               })
  
  #update parsed example table
  observe({
    rv$parseExampleDF = read_csv(rv$parseExamplePath)
    rv$parseExampleDT = datatable(rv$parseExampleDF,
                                  filter = "none",
                                  options = list(dom = "t", ordering = F))
  })
  #update table in UI
  observe({
    output$parseTable1 = renderDT(datatable(
      read_csv(rv$parseExamplePath),
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
                                      bardlink
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
    rv$completeTableDF = read_csv(rv$completeTablePath)
    rv$completeTableDT = datatable(rv$completeTableDF,
                                  filter = "none",
                                  options = list(ordering = F))
  })
  #update input table in UI
  observe({
    output$completeTable1 = renderDT(datatable(
      read_csv(rv$completeTablePath),
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
                                         bardlink
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
        bardlink
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
    rv$writeTableDF = read_csv(rv$writeTablePath)
    rv$writeTableDT = datatable(rv$writeTableDF,
                                  filter = "none",
                                  options = list(dom = "t", ordering = F))
  })
  #update table in UI
  observe({
    output$writeTable = renderDT(datatable(
      read_csv(rv$writeTablePath),
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
          bardlink
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
