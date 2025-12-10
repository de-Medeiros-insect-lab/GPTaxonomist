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

#format a CSV table (for prompt embedding)
format_table_csv = function(df){
  # Use a text connection to capture write.csv output
  tc = textConnection("csv_output", "w", local = TRUE)
  write.csv(df, tc, row.names = FALSE, quote = TRUE)
  close(tc)
  paste(csv_output, collapse = "\n")
}

#format a JSON array of objects (for prompt embedding)
format_table_json = function(df){
  jsonlite::toJSON(df, pretty = TRUE, auto_unbox = TRUE)
}

#get the human-readable format name
get_format_name = function(format){
  switch(format,
         csv = "CSV (comma-separated values)",
         json = "JSON array of objects",
         markdown = "markdown pipe table",
         "markdown pipe table"  # default
  )
}

#format a table according to chosen output format
format_table_for_prompt = function(df, format){
  switch(format,
         csv = format_table_csv(df),
         json = format_table_json(df),
         markdown = format_table(df),
         format_table(df)  # default to markdown
  )
}

#get format-specific output instructions for templates
get_output_format_instructions = function(format){
  switch(format,
         csv = "Produce a CSV table with a header row followed by data rows. Use commas to separate values and quote fields containing commas or special characters.",
         json = "Produce a JSON array where each element is an object representing one row. Use consistent key names matching the column headers.",
         markdown = "Produce a markdown pipe table with headers separated by |. Include a separator row with :--- for left alignment.",
         "Produce a markdown pipe table with headers separated by |."  # default
  )
}

#get format-specific example for parse module
get_parse_format_example = function(format){
  switch(format,
         csv = '"Character","State"
"Adult male, head, color","black"
"Adult male, head, punctation","densely punctate"
"Adult male, wing, length (mm)","4.2-4.8"',
         json = '[
  {"Character": "Adult male, head, color", "State": "black"},
  {"Character": "Adult male, head, punctation", "State": "densely punctate"},
  {"Character": "Adult male, wing, length (mm)", "State": "4.2-4.8"}
]',
         markdown = '| Character | State |
|:---|:---|
| Adult male, head, color | black |
| Adult male, head, punctation | densely punctate |
| Adult male, wing, length (mm) | 4.2-4.8 |',
         # default to markdown
         '| Character | State |
|:---|:---|
| Adult male, head, color | black |
| Adult male, head, punctation | densely punctate |'
  )
}

#get format-specific example for compare module
get_compare_format_example = function(format){
  switch(format,
         csv = '"Characters observed","Species A","Species B"
"Adult male, head, vertex, color","black","reddish-brown"
"Adult male, head, vertex, punctation","densely punctate","sparsely punctate"
"Adult male, wing, fore wing, length (mm)","4.2-4.8","3.8-4.1"',
         json = '[
  {"Characters observed": "Adult male, head, vertex, color", "Species A": "black", "Species B": "reddish-brown"},
  {"Characters observed": "Adult male, head, vertex, punctation", "Species A": "densely punctate", "Species B": "sparsely punctate"},
  {"Characters observed": "Adult male, wing, fore wing, length (mm)", "Species A": "4.2-4.8", "Species B": "3.8-4.1"}
]',
         markdown = '| Characters observed | Species A | Species B |
|:---|:---|:---|
| Adult male, head, vertex, color | black | reddish-brown |
| Adult male, head, vertex, punctation | densely punctate | sparsely punctate |
| Adult male, wing, fore wing, length (mm) | 4.2-4.8 | 3.8-4.1 |',
         # default to markdown
         '| Characters observed | Species A | Species B |
|:---|:---|:---|
| Adult male, head, vertex, color | black | reddish-brown |'
  )
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
fill_parseDescription = function(description, language, example, output_format = "csv"){
  template = read_file('templates/parse_description.txt')

  return(template %>%
           str_replace_all('\\$\\{DESCRIPTION\\}', description) %>%
           str_replace_all('\\$\\{LANGUAGE\\}', language) %>%
           str_replace_all('\\$\\{EXAMPLE\\}', example) %>%
           str_replace_all('\\$\\{OUTPUT_FORMAT\\}', get_format_name(output_format)) %>%
           str_replace_all('\\$\\{OUTPUT_FORMAT_INSTRUCTIONS\\}', get_output_format_instructions(output_format))
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
fill_completeTable = function(description, language, table1, output_format = "csv"){
  template = read_file('templates/complete_table.txt')
  out_table_text = format_table_for_prompt(table1, output_format)


  return(template %>%
           str_replace_all('\\$\\{DESCRIPTION\\}', description) %>%
           str_replace_all('\\$\\{LANGUAGE\\}', language) %>%
           str_replace_all('\\$\\{TABLE\\}', out_table_text) %>%
           str_replace_all('\\$\\{OUTPUT_FORMAT\\}', get_format_name(output_format)) %>%
           str_replace_all('\\$\\{OUTPUT_FORMAT_INSTRUCTIONS\\}', get_output_format_instructions(output_format))
  )
}

#fills up a COMPARE DESCRIPTIONS template
fill_compareDescriptions = function(description1, description2, language, exclude_unique, output_format = "csv"){
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
           str_replace_all('\\$\\{INCLUDE_STATEMENT\\}', unique_statement) %>%
           str_replace_all('\\$\\{OUTPUT_FORMAT\\}', get_format_name(output_format)) %>%
           str_replace_all('\\$\\{OUTPUT_FORMAT_INSTRUCTIONS\\}', get_output_format_instructions(output_format)) %>%
           str_replace_all('\\$\\{OUTPUT_FORMAT_EXAMPLE\\}', get_compare_format_example(output_format))
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
  get_key = function(key_name){
    value = Sys.getenv(key_name)
    if(is.null(value)) value = ""
    return(value)
  }

  keys = list(
    openai = list(
      value = get_key("OPENAI_API_KEY"),
      var_name = "OPENAI_API_KEY"
    ),
    anthropic = list(
      value = get_key("ANTHROPIC_API_KEY"),
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

################## MODEL LISTING FUNCTIONS ##################

#fetch available models from Ollama
fetch_ollama_models = function(host = ollama_default_host, port = ollama_default_port){
  require(httr2)

  if(is.null(host) || host == "" || is.null(port) || port == ""){
    return(list(success = FALSE, models = NULL, error = "No host/port provided"))
  }

  tryCatch({
    url = paste0("http://", host, ":", port, "/api/tags")

    response = request(url) %>%
      req_timeout(10) %>%
      req_perform()

    result = response %>% resp_body_json()

    if(length(result$models) == 0){
      return(list(
        success = FALSE,
        models = NULL,
        error = "No models found. Please install models using 'ollama pull <model-name>'"
      ))
    }

    #extract model names
    model_names = sapply(result$models, function(m) m$name)

    return(list(
      success = TRUE,
      models = model_names,
      error = NULL
    ))

  }, error = function(e){
    return(list(
      success = FALSE,
      models = NULL,
      error = paste("Could not connect to Ollama. Please check that Ollama is running and verify the host address and port are correct.")
    ))
  })
}

#fetch available models from OpenAI
fetch_openai_models = function(api_key){
  require(httr2)

  if(is.null(api_key) || api_key == ""){
    return(list(success = FALSE, models = NULL, error = "No API key provided"))
  }

  tryCatch({
    response = request("https://api.openai.com/v1/models") %>%
      req_headers(
        "Authorization" = paste("Bearer", api_key)
      ) %>%
      req_timeout(15) %>%
      req_perform()

    result = response %>% resp_body_json()

    #extract model IDs
    all_models = sapply(result$data, function(m) m$id)

    #filter for chat-compatible models (gpt-4*, gpt-3.5*, o1*, o3*, chatgpt*)
    chat_models = all_models[grepl("^(gpt-4|gpt-3\\.5|o1|o3|chatgpt)", all_models, ignore.case = TRUE)]

    #exclude deprecated/special variants
    chat_models = chat_models[!grepl("(instruct|vision-preview|realtime|audio)", chat_models, ignore.case = TRUE)]

    #sort alphabetically
    chat_models = sort(chat_models, decreasing = TRUE)

    if(length(chat_models) == 0){
      return(list(
        success = FALSE,
        models = NULL,
        error = "No chat-compatible models found for this API key."
      ))
    }

    return(list(
      success = TRUE,
      models = chat_models,
      error = NULL
    ))

  }, error = function(e){
    return(list(
      success = FALSE,
      models = NULL,
      error = "Could not fetch models from OpenAI. Please check that your API key is valid and that you have available credits."
    ))
  })
}

#fetch available models from Anthropic
fetch_anthropic_models = function(api_key){
  require(httr2)

  if(is.null(api_key) || api_key == ""){
    return(list(success = FALSE, models = NULL, error = "No API key provided"))
  }

  tryCatch({
    response = request("https://api.anthropic.com/v1/models") %>%
      req_headers(
        "x-api-key" = api_key,
        "anthropic-version" = "2023-06-01"
      ) %>%
      req_timeout(15) %>%
      req_perform()

    result = response %>% resp_body_json()

    #extract model IDs
    model_ids = sapply(result$data, function(m) m$id)

    if(length(model_ids) == 0){
      return(list(
        success = FALSE,
        models = NULL,
        error = "No models found for this API key."
      ))
    }

    return(list(
      success = TRUE,
      models = model_ids,
      error = NULL
    ))

  }, error = function(e){
    return(list(
      success = FALSE,
      models = NULL,
      error = "Could not fetch models from Anthropic. Please check that your API key is valid and that you have available credits."
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

################## STREAMING API FUNCTIONS ##################
# These functions stream responses to a file for real-time UI updates

#stream OpenAI response to file (for use in background process)
stream_openai_to_file = function(prompt, api_key, model, output_file, status_file) {
  require(httr2)
  require(jsonlite)

  if(is.null(api_key) || api_key == ""){
    cat("error:No API key provided", file = status_file)
    return(invisible(NULL))
  }

  accumulated = ""
  buffer = ""  # Buffer for incomplete SSE lines

  tryCatch({
    cat("running", file = status_file)
    cat("", file = output_file)

    request("https://api.openai.com/v1/chat/completions") %>%
      req_headers(
        "Authorization" = paste("Bearer", api_key),
        "Content-Type" = "application/json"
      ) %>%
      req_body_json(list(
        model = model,
        messages = list(list(role = "user", content = prompt)),
        stream = TRUE
      )) %>%
      req_timeout(300) %>%
      req_perform_stream(callback = function(chunk) {
        data = rawToChar(chunk)
        buffer <<- paste0(buffer, data)

        # Process complete lines only
        while(grepl("\n", buffer)) {
          newline_pos = regexpr("\n", buffer)[1]
          line = substr(buffer, 1, newline_pos - 1)
          buffer <<- substr(buffer, newline_pos + 1, nchar(buffer))

          if(startsWith(line, "data: ") && line != "data: [DONE]") {
            json_str = substring(line, 7)
            parsed = tryCatch(fromJSON(json_str, simplifyVector = FALSE), error = function(e) NULL)
            if(!is.null(parsed) &&
               !is.null(parsed$choices) &&
               length(parsed$choices) > 0 &&
               !is.null(parsed$choices[[1]]$delta) &&
               !is.null(parsed$choices[[1]]$delta$content)) {
              content = parsed$choices[[1]]$delta$content
              accumulated <<- paste0(accumulated, content)
              cat(accumulated, file = output_file)
            }
          }
        }
        TRUE
      }, buffer_kb = 0.1)

    cat("success", file = status_file)

  }, error = function(e){
    cat(paste0("error:", e$message), file = status_file)
  })

  return(invisible(NULL))
}

#stream Anthropic response to file (for use in background process)
stream_anthropic_to_file = function(prompt, api_key, model, output_file, status_file) {
  require(httr2)
  require(jsonlite)

  if(is.null(api_key) || api_key == ""){
    cat("error:No API key provided", file = status_file)
    return(invisible(NULL))
  }

  accumulated = ""
  buffer = ""  # Buffer for incomplete SSE lines

  tryCatch({
    cat("running", file = status_file)
    cat("", file = output_file)

    request("https://api.anthropic.com/v1/messages") %>%
      req_headers(
        "x-api-key" = api_key,
        "anthropic-version" = "2023-06-01",
        "Content-Type" = "application/json"
      ) %>%
      req_body_json(list(
        model = model,
        max_tokens = 4096,
        messages = list(list(role = "user", content = prompt)),
        stream = TRUE
      )) %>%
      req_timeout(300) %>%
      req_perform_stream(callback = function(chunk) {
        data = rawToChar(chunk)
        buffer <<- paste0(buffer, data)

        # Process complete lines only
        while(grepl("\n", buffer)) {
          newline_pos = regexpr("\n", buffer)[1]
          line = substr(buffer, 1, newline_pos - 1)
          buffer <<- substr(buffer, newline_pos + 1, nchar(buffer))

          if(startsWith(line, "data: ")) {
            json_str = substring(line, 7)
            parsed = tryCatch(fromJSON(json_str, simplifyVector = FALSE), error = function(e) NULL)
            if(!is.null(parsed) && !is.null(parsed$type) && parsed$type == "content_block_delta") {
              if(!is.null(parsed$delta) && !is.null(parsed$delta$text)) {
                content = parsed$delta$text
                accumulated <<- paste0(accumulated, content)
                cat(accumulated, file = output_file)
              }
            }
          }
        }
        TRUE
      }, buffer_kb = 0.1)

    cat("success", file = status_file)

  }, error = function(e){
    cat(paste0("error:", e$message), file = status_file)
  })

  return(invisible(NULL))
}

#stream Ollama response to file (for use in background process)
stream_ollama_to_file = function(prompt, host, port, model, output_file, status_file) {
  require(httr2)
  require(jsonlite)

  if(is.null(host) || host == "" || is.null(port) || port == ""){
    cat("error:No Ollama host/port provided", file = status_file)
    return(invisible(NULL))
  }

  if(is.null(model) || model == ""){
    cat("error:No Ollama model specified", file = status_file)
    return(invisible(NULL))
  }

  accumulated = ""
  buffer = ""  # Buffer for incomplete JSON lines

  tryCatch({
    cat("running", file = status_file)
    cat("", file = output_file)

    url = paste0("http://", host, ":", port, "/api/generate")

    request(url) %>%
      req_headers(
        "Content-Type" = "application/json"
      ) %>%
      req_body_json(list(
        model = model,
        prompt = prompt,
        stream = TRUE
      )) %>%
      req_timeout(300) %>%
      req_perform_stream(callback = function(chunk) {
        data = rawToChar(chunk)
        buffer <<- paste0(buffer, data)

        # Process complete lines only
        while(grepl("\n", buffer)) {
          newline_pos = regexpr("\n", buffer)[1]
          line = substr(buffer, 1, newline_pos - 1)
          buffer <<- substr(buffer, newline_pos + 1, nchar(buffer))

          if(nchar(trimws(line)) > 0) {
            parsed = tryCatch(fromJSON(line, simplifyVector = FALSE), error = function(e) NULL)
            if(!is.null(parsed) && !is.null(parsed$response)) {
              accumulated <<- paste0(accumulated, parsed$response)
              cat(accumulated, file = output_file)
            }
          }
        }
        TRUE
      }, buffer_kb = 0.1)

    cat("success", file = status_file)

  }, error = function(e){
    cat(paste0("error:", e$message), file = status_file)
  })

  return(invisible(NULL))
}

