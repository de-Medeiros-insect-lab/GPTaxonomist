#some default values
complete_table_word_limit = 10000000
parse_paragraph_word_limit = 10000000

#LLM API default values
ollama_default_host = "127.0.0.1"
ollama_default_port = "11434"
ollama_default_model = "deepseek-r1:1.5b"

#read a table, possibly in several formats
read_table_robust = function(file){
  ext <- tools::file_ext(file)
  df = tryCatch({
    switch(ext,
           csv = read.csv(file),
           tsv = read.delim(file),
           txt = read.delim(file),
           xls = readxl::read_excel(file),
           xlsx = readxl::read_excel(file),
           stop("Unsupported file format")
    )
  }, error = function(e) {
    stop("Error reading file: ", e$message)
  })
  return(df)
  
}

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
    unique_statement = "Only include characters observed in both species descriptions (skip row if one is missing or not observed). "
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


################## LLM API INTEGRATION FUNCTIONS ##################

#extract content between <results> tags
extract_results = function(text) {
  if(is.null(text) || text == "") {
    return(NULL)
  }

  # Extract content from the LAST occurrence of <results> tags
  # This handles cases where the model mentions <results> in thinking
  start_tag = "<results>"
  end_tag = "</results>"

  # Find all occurrences of the start tag
  all_starts = gregexpr(start_tag, text, fixed = TRUE)[[1]]
  if(all_starts[1] == -1) {
    return(NULL)  # No opening tag found
  }

  # Use the last occurrence of the start tag
  last_start = all_starts[length(all_starts)]

  # Find closing tag after the last opening tag
  search_start = last_start + nchar(start_tag)
  remaining_text = substring(text, search_start)
  end_pos = regexpr(end_tag, remaining_text, fixed = TRUE)

  if(end_pos == -1) {
    return(NULL)  # No closing tag found
  }

  # Extract content between tags
  content = substring(remaining_text, 1, end_pos - 1)
  return(trimws(content))
}

#detect API keys in environment variables
detect_api_keys = function(){
  keys = list(
    openai = list(
      value = Sys.getenv("OPENAI_API_KEY"),
      var_name = "OPENAI_API_KEY"
    ),
    anthropic = list(
      value = Sys.getenv("ANTHROPIC_API_KEY"),
      var_name = "ANTHROPIC_API_KEY"
    )
  )

  #mask keys for display (show first 4 and last 4 characters)
  for(provider in names(keys)){
    if(nchar(keys[[provider]]$value) > 8){
      key_val = keys[[provider]]$value
      keys[[provider]]$masked = paste0(
        substr(key_val, 1, 4),
        "...",
        substr(key_val, nchar(key_val) - 3, nchar(key_val))
      )
    } else {
      keys[[provider]]$masked = NULL
    }
  }

  return(keys)
}

#call OpenAI API
call_openai = function(prompt, api_key, model = "gpt-4o-mini"){
  require(httr2)

  if(is.null(api_key) || api_key == ""){
    return(list(success = FALSE, error = "No API key provided"))
  }

  tryCatch({
    response = request("https://api.openai.com/v1/chat/completions") %>%
      req_headers(
        "Authorization" = paste("Bearer", api_key),
        "Content-Type" = "application/json"
      ) %>%
      req_body_json(list(
        model = model,
        messages = list(
          list(role = "user", content = prompt)
        )
      )) %>%
      req_timeout(300) %>%
      req_perform()

    result = response %>% resp_body_json()

    return(list(
      success = TRUE,
      content = result$choices[[1]]$message$content
    ))

  }, error = function(e){
    return(list(
      success = FALSE,
      error = paste("OpenAI API error:", e$message)
    ))
  })
}

#call Anthropic API
call_anthropic = function(prompt, api_key, model = "claude-3-5-haiku-20241022"){
  require(httr2)

  if(is.null(api_key) || api_key == ""){
    return(list(success = FALSE, error = "No API key provided"))
  }

  tryCatch({
    response = request("https://api.anthropic.com/v1/messages") %>%
      req_headers(
        "x-api-key" = api_key,
        "anthropic-version" = "2023-06-01",
        "Content-Type" = "application/json"
      ) %>%
      req_body_json(list(
        model = model,
        max_tokens = 4096,
        messages = list(
          list(role = "user", content = prompt)
        )
      )) %>%
      req_timeout(300) %>%
      req_perform()

    result = response %>% resp_body_json()

    return(list(
      success = TRUE,
      content = result$content[[1]]$text
    ))

  }, error = function(e){
    return(list(
      success = FALSE,
      error = paste("Anthropic API error:", e$message)
    ))
  })
}

#call Ollama API
call_ollama = function(prompt, host = ollama_default_host, port = ollama_default_port, model = ollama_default_model){
  require(httr2)

  if(is.null(host) || host == "" || is.null(port) || port == ""){
    return(list(success = FALSE, error = "No Ollama host/port provided"))
  }

  if(is.null(model) || model == ""){
    return(list(success = FALSE, error = "No Ollama model specified"))
  }

  tryCatch({
    url = paste0("http://", host, ":", port, "/api/generate")

    response = request(url) %>%
      req_headers(
        "Content-Type" = "application/json"
      ) %>%
      req_body_json(list(
        model = model,
        prompt = prompt,
        stream = FALSE
      )) %>%
      req_timeout(300) %>%
      req_perform()

    result = response %>% resp_body_json()

    return(list(
      success = TRUE,
      content = result$response
    ))

  }, error = function(e){
    return(list(
      success = FALSE,
      error = paste("Ollama API error:", e$message)
    ))
  })
}

