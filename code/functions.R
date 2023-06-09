#some default values
complete_table_word_limit = 300
parse_paragraph_word_limit = 500

#format a markdown table
format_table = function(df){
  f_table = knitr::kable(df, format = "pipe", escape = FALSE) %>%
    str_replace_all("\\|"," \\| ") %>%
    str_trim() %>%
    str_replace_all(" +", " ") 
  f_table[2] = str_replace_all(f_table[2],"[:-]+",":-")
  f_table %>%
    paste0(collapse ="\n")
}


#returns paragraphs in groups containing at most 500 words
group_paragraphs = function(input, word_limit = parse_paragraph_word_limit){
  paragraphs = str_split(input,'\n',simplify = TRUE) %>% as.vector
  
  paragraph_counts = paragraphs %>%
    purrr::map(~length(str_split(.x," ",simplify=TRUE))) %>%
    unlist
  
  groups = floor(cumsum(paragraph_counts) / word_limit) + 1
  
  out_table = tibble(group = groups, paragraph = paragraphs) %>%
    group_by(group) %>%
    summarise(input = str_c(paragraph, collapse='\n'))
  
  return(pull(out_table,input))
  
}

#fills up PARSE DESCRIPTION template
fill_parseDescription = function(description, language, example){
  template = read_file('templates/parse_description.txt')
  
  return(template %>%
           str_replace_all('\\$\\{DESCRIPTION\\}', description) %>%
           str_replace_all('\\$\\{LANGUAGE\\}', language) %>%
           str_replace_all('\\$\\{EXAMPLE\\}', example)
           ) 
}

#returns table rows in groups containing at most complete_table_word_limit
group_table_rows = function(input_table, word_limit = complete_table_word_limit){
  
  word_counts = input_table %>%
    rowwise() %>%
    mutate(total_words = sum(str_count(c_across(everything()), "\\S+"))) %>%
    ungroup() %>%
    mutate(cum_words = cumsum(total_words),
           groups = floor(cum_words/word_limit) + 1)
  
  out_tables = split(word_counts[1:2],word_counts$groups)
  
  return(out_tables)
  
}

#fills up COMPLETE TABLE template
fill_completeTable = function(description, language, table1){
  template = read_file('templates/complete_table.txt')
  out_table_text = format_table(table1)
  
  
  return(template %>%
           str_replace_all('\\$\\{DESCRIPTION\\}', description) %>%
           str_replace_all('\\$\\{LANGUAGE\\}', language) %>%
           str_replace_all('\\$\\{TABLE\\}', out_table_text)
  ) 
}

#fills up a COMPARE DESCRIPTIONS template
fill_compareDescriptions = function(description1, description2, language, exclude_unique){
  template = read_file('templates/compare_description.txt')
  
  if (exclude_unique){
    unique_statement = "Only include characters observed in both species. "
  } else {
    unique_statement = "Include all characters, fill up with NA if not observed for a species. "
  }
  
  return(template %>%
           str_replace_all('\\$\\{DESCRIPTION1\\}', description1) %>%
           str_replace_all('\\$\\{DESCRIPTION2\\}', description2) %>%
           str_replace_all('\\$\\{LANGUAGE\\}', language) %>%
           str_replace_all('\\$\\{INCLUDE_STATEMENT\\}', unique_statement)
  ) 
}


#fills up a WRITE DESCRIPTION template
fill_writeDescription = function(character_table, template_description, language){
  template = read_file('templates/write_description.txt')
  formatted_table = format_table(character_table)
  
    return(template %>%
           str_replace_all('\\$\\{TEMPLATE_DESCRIPTION\\}', template_description) %>%
           str_replace_all('\\$\\{CHARACTER_TABLE\\}', formatted_table) %>%
           str_replace_all('\\$\\{LANGUAGE\\}', language) 
  ) 
}

