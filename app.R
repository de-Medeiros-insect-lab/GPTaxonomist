#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
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
  dashboardHeader(title='GPTaxonomist'),
  
  dashboardSidebar(
    sidebarMenu(
      id='sidebar',
      rclipboardSetup(),
      menuItem('Home', tabName = 'home', icon = icon('home')),
      menuItem('Parse Description', tabName = 'parse', icon = icon('list')),
      menuItem('Compare Descriptions', tabName = 'compare', icon = icon('code-compare')),
      menuItem('Table to description', tabName = 'table', icon = icon('table')),
      
      HTML(paste0(
        "<br>",
        "<a href='https://www.fieldmuseum.org/about/staff/profile/bruno-de-medeiros' target='_blank'><img style = 'display: block; margin-left: auto; margin-right: auto;' src='Field_Logo_Std_Blue_CMYK.png', width = '186'></a>",
        "<br>"
      ))
      )),
  
  dashboardBody(
    tabItems(
      tabItem(tabName = "home",
              h2("Welcome!"),
              p("This is an interactive tool to help generating useful prompts for doing taxonomic tasks in chatGPT. Check the menu on the left for different tasks.")
      ),
      
      tabItem(tabName = "parse",
              h2("Parse descriptions"),
              p("Here we will generate prompts to help parse a taxonomic description in natural language into a table that you can copy and paste in a spreadsheet. This is helpful, for example, to create a morphological character matrix, or to use as a template to describe a new species."),
              p("On the left panel, provide the description that you want to parse, the language you want it to translate to and a few examples of what you want your table to look like."),
              p("On the right panel, you will get a generate prompt that you can copy and paste into chatGPT. If your input is too large, we will provide several prompts for you to do it in parts."),
              fluidRow(
                box(h3("Input"),
                    p("Edit text and table below with your data."),
                    textInput("parseLanguage", 
                              "Language to output", 
                              value = read_file("defaults/parse/language.txt")),
                    textAreaInput("parseDesc", 
                              "Description to parse",
                              value = read_file("defaults/parse/description.txt"),
                              rows = 10),
                    strong('Examples'),
                    p('Upload a CSV file to change examples.'),
                    fileInput('parseExampleFile',NULL,accept = '.csv'),
                    DTOutput("table1"),
                    ),
                box(h3("Results"),
                    uiOutput("parseOutputTabs")
                    )
                )
      )
    )
  )
)

# Server computations
server <- function(input, output) {
  #read functions
  source('code/parse_functions.R')
  
  #initialize reactive values
  rv = reactiveValues(parseExamplePath = "defaults/parse/example.csv")
  
  ############DESCRIPTION parsing
  
  ### Reactive input handling
  #change example table if a new table uploaded
  observeEvent(input$parseExampleFile, 
               {rv$parseExamplePath = input$parseExampleFile$datapath
               })
  
  #update parsed example table
  observe({
    rv$parseExampleDF = read_csv(rv$parseExamplePath)
    rv$parseExampleDT = datatable(rv$parseExampleDF,
                                  filter = 'none',
                                  options = list(dom = 't', ordering=F))   
  })
  
  #update table in UI
  observe({
    output$table1 = renderDT(datatable(read_csv(rv$parseExamplePath),
                                       filter = 'none',
                                       options = list(dom = 't', ordering=F))   )
    
  })
  
  
  ### Generating output
  #process parsing input and produce text blocks
  observe({
    rv$parseParagraphs = group_paragraphs(input$parseDesc) 
    
    rv$parseOutputPrompts = purrr::map(rv$parseParagraphs,
                                    ~fill_parseDescription(.x,
                                                           input$parseLanguage,
                                                           knitr::kable(rv$parseExampleDF, format = 'pipe', escape = FALSE) %>% 
                                                             paste0(collapse='\n')
                                                           )
                                    )
  })
  
  observe({
    for (i in length(rv$parseOutputPrompts)){
      output[[str_c('parseOutputPrompt',i,sep='')]] = renderText(rv$parseOutputPrompts[[i]])
    }
  })
  
  observe({
    rv$parseOutputTabs = purrr::map(1:length(rv$parseOutputPrompts),
    ~tabPanel(title = str_c('Prompt',.x,sep=''),
              verbatimTextOutput(str_c('parseOutputPrompt',.x,sep='')
                                 )
              )
    )
  })
  
  
  observe({
    output$parseOutputTabs = renderUI({
      do.call(navlistPanel,rv$parseOutputTabs)
    })
    
  })
  
  
  


  #outputs
  
  
  
  
  
}

# Run the application 
shinyApp(ui = ui, server = server)
