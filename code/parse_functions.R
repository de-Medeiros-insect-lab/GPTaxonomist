#returns paragraphs in groups containing at most 500 words
group_paragraphs = function(input){
  paragraphs = str_split(input,'\n',simplify = TRUE) %>% as.vector
  
  paragraph_counts = paragraphs %>%
    purrr::map(~length(str_split(.x," ",simplify=TRUE))) %>%
    unlist
  
  groups = floor(cumsum(paragraph_counts) / 500) + 1
  
  out_table = tibble(group = groups, paragraph = paragraphs) %>%
    group_by(group) %>%
    summarise(input = str_c(paragraph, collapse='\n'))
  
  return(pull(out_table,input))
  
}

#fills up description parsing template
fill_parseDescription = function(description, language, example){
  template = read_file('templates/parse_description.txt')
  
  return(template %>%
           str_replace_all('\\$\\{DESCRIPTION\\}', description) %>%
           str_replace_all('\\$\\{LANGUAGE\\}', language) %>%
           str_replace_all('\\$\\{EXAMPLE\\}', example)
           ) 
}

