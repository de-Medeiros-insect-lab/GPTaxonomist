###### PARSE

UI_parse = tabItem(
  tabName = "parse",
  h2("Parse descriptions"),
  h3("Purpose"),
  p("Generate a prompt to parse a taxonomic description in natural language into a table that can be copied and pasted"),
  h3("Input required"),
  tags$div(
    tags$ul(
      tags$li(tags$b("The output language desired.")," Edit the text box below to change."),
      tags$li(tags$b("The description to parse.")," Edit the text box below to change."),
      tags$li(tags$b("A table with examples.")," only use 5-10 examples. Create a table in csv or excel format and upload it here using the button below.")
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
      p("Upload a data table to change examples."),
      fileInput(
        "parseExampleFile",
        NULL,
        accept = c(".csv", ".tsv", ".txt", ".xls", ".xlsx"),
        buttonLabel = "Upload table..."
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
)

###################################### COMPLETE UI ####################################
UI_complete = tabItem(
  tabName = "complete",
  h2("Complete table"),
  h3("Purpose"),
  p("To generate a prompt to parse a taxonomic description in natural language and add characters to a pre-made table."),
  h3("Input required"),
  tags$div(
    tags$ul(
      tags$li(tags$b("The output language desired."), " Edit the text box below to change."),
      tags$li(tags$b("The description to parse.")," Edit the text box below to change."),
      tags$li(tags$b("A table to be filled out.")," This must include 2 columns: one with character names and another with observed states for an example species. The second column may be blank, but it will work better if not. Create a table in csv or excel and upload it here using the button below.")
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
                       p("Upload a file to change the table."),
                       fileInput(
                         "completeTableFile",
                         NULL,
                         accept = c(".csv", ".tsv", ".txt", ".xls", ".xlsx"),
                         buttonLabel = "Upload table..."
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
              tabPanel("Result",
                       p("Use the prompt below to create a natural language description from a table."),
                       uiOutput("writeOutputUI")
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