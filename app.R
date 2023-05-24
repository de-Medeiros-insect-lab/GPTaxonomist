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
    tabItems(
      tabItem(
        tabName = "home",
        h2("Welcome!"),
        p(
          "This is an interactive tool to help generating useful prompts for doing taxonomic tasks in chatGPT. Check the menu on the left for different tasks."
        )
      ),
      
      
      
      ###################################### PARSE UI ####################################
      tabItem(
        tabName = "parse",
        h2("Parse descriptions"),
        p(
          "Here we will generate prompts to help parse a taxonomic description in natural language into a table that you can copy and paste in a spreadsheet. This is helpful, for example, to create a morphological character matrix, or to use as a template to describe a new species."
        ),
        p(
          "On the Input tab , provide the description that you want to parse, the language you want it to translate to and a few examples of what you want your table to look like."
        ),
        p(
          "On the Results panel, you get a prompt that you can copy and paste into chatGPT. If your input is too large, we will provide several prompts for you to do it in parts."
        ),
        tabsetPanel(
          type = "tabs",
          tabPanel(
            "Input",
            p("Edit text and table below with your data."),
            textInput(
              "parseLanguage",
              "Language to output",
              value = read_file("defaults/parse/language.txt")
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
            p("If your input description was too long, we automatically split it in smaller chuncks by paragraph so it is possible to use chatGPT."),
            p(
              "Navigate the tabs below to see the prompts generated. Copy and paste them in chatGPT to get the desired result. If GPT response is too long and the response get cut in the middle, use the following to continue:"
            ),
            strong("Continue from the last incomplete row, repeat table headers."),
            uiOutput("parseOutputTabs")
          )
        )
      ),
      
      
      
      ###################################### COMPLETE UI ####################################
      tabItem(
        tabName = "complete",
        h2("Complete table"),
        p(
          "The goal here is to combine a natural language description and a table of characters."
        ),
        tabsetPanel(type = "tabs",
                    tabPanel("Input",
                             textInput(
                               "completeLanguage",
                               "Language to output",
                               value = read_file("defaults/complete/language.txt")
                             ),
                             textAreaInput(
                               "completeDesc",
                               "Description to read",
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
                             p("If your input table was too long, we automatically split it in smaller tables so it is possible to use chatGPT."),
                             p(
                              "Navigate the tabs below to see the prompts generated. Copy and paste them in chatGPT to get the desired result. If GPT response is too long and the response get cut in the middle, use the following to continue:"
                             ),
                             strong("Continue from the last incomplete row, repeat table headers."),
                             uiOutput("completeOutputTabs")
                             ))
      ),
      
      tabItem(
        tabName = "compare",
        h2("Compare descriptions"),
        p("Lorem ipsum."),
        tabsetPanel(type = "tabs",
                    tabPanel("Input"),
                    tabPanel("Result"))
      ),
      tabItem(
        tabName = "table",
        h2("Produce natural language description from table"),
        p("Lorem ipsum."),
        tabsetPanel(type = "tabs",
                    tabPanel("Input"),
                    tabPanel("Result"))
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
      
      
      
      
      
      
    )
  )
)

# Server computations
server <- function(input, output) {
  #read functions
  source("code/functions.R")
  
  #initialize reactive values
  rv = reactiveValues(parseExamplePath = "defaults/parse/example.csv",
                      completeTablePath = "defaults/complete/table.csv"
                      )
  
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
        knitr::kable(rv$parseExampleDF, format = "pipe", escape = FALSE) %>%
          paste0(collapse =
                   "\n")
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
                                    rclipButton(
                                      str_c("parseOutputClip", .x, sep = ""),
                                      "Copy to clipboard",
                                      rv$parseOutputPrompts[[.x]]
                                    ),
                                    verbatimTextOutput(str_c("parseOutputPrompt", .x, sep = "")),
                                    a("Go to chatGPT", href = "https://chat.openai.com", target =
                                        "_blank")
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
                                    rclipButton(
                                      str_c("completeOutputClip", .x, sep = ""),
                                      "Copy to clipboard",
                                      rv$completeOutputPrompts[[.x]]
                                    ),
                                    verbatimTextOutput(str_c("completeOutputPrompt", .x, sep = "")),
                                    a("Go to chatGPT", href = "https://chat.openai.com", target =
                                        "_blank")
                                  ))
    print("a")
  })
  #join output tabs
  observe({
    output$completeOutputTabs = renderUI({
      do.call(navlistPanel, rv$completeOutputTabs)
    })
  })
  
  
  
  
  
}

###########TO DO
########### SPLIT INPUT TABLE IF TOO LONG
########### FIX UI

# Run the application
shinyApp(ui = ui, server = server)
