library(shiny)
library(shinyFiles)
library(yaml)
library(fs)



## ==== UI for Pipeline Tab ====
ui_pipeline <- fluidPage(
  sidebarLayout(
    sidebarPanel(
      
      tags$p(tags$b("Select your output directory")),
      shinyDirButton(id = "output_dir", label = "output", title = NULL),
      textOutput("output_dir_status"),
      tags$br(),
      
      tags$p(tags$b("Select your pod5 directory")),
      shinyDirButton(id = "pod5_dir", label = "pod5", title = NULL),
      textOutput("pod5_dir_status"),
      tags$br(),
      
      checkboxInput("using_custom",
                    HTML("<--- Click if you are using a custom basecalling arrangement"),
                    value = FALSE),
      
      conditionalPanel(condition = "input.using_custom == true",
                       tags$p(tags$b("Select your barcode arrangement file")),
                       shinyFilesButton("toml_file", label = "(.toml)", title = NULL, multiple = FALSE),
                       textOutput("toml_file_status"),
                       tags$br(),
                       
                       tags$p(tags$b("Select your barcode sequencing file")),
                       shinyFilesButton("fasta_file", label = "(.fasta)", title = NULL, multiple = FALSE),
                       textOutput("fasta_file_status"),
                       tags$br()
      ),
      
      selectInput("model_acc", "Select a model accuracy for Dorado",
                  choices = c("sup", "fast", "hac")),
      
      textInput("kit_name", "Input kit name"),
      
      conditionalPanel(
        condition = "input.using_custom == false",
        helpText("Commonly used kits:",
                 tags$br(), 
                 "Kit Name: ...",
                 tags$br(), 
                 "Kit Name: ...",
                 tags$br(), 
                 "Kit Name: ...",
        )
      ),
      
      numericInput("min", "Input a minimum value for length filtering", value = NULL),
      
      numericInput("max", "Input a maximum value for length filtering (optional)", value = NULL),
      
      actionButton("run_pipeline", "Run Pipeline")
    ),
    
    mainPanel(
      verbatimTextOutput("pipeline_output")
    )
  )
)


## ==== UI for Visualize Tab ====
ui_visualize <- fluidPage(
  fluidRow(
    column(12,
           imageOutput("plot1", height = "300px"),
           imageOutput("plot2", height = "300px"),
           imageOutput("plot3", height = "300px"),
           imageOutput("plot4", height = "300px")
    )
  ),
  
  tags$hr(),  
  
  fluidRow(
    column(
      width = 12,
      tags$h4("NanoStats Summary"),
      tags$div(
        style = "max-height: 300px; overflow-y: scroll; background-color: #f8f9fa; padding: 10px; border: 1px solid #ccc; white-space: pre-wrap;",
        verbatimTextOutput("nanostats_txt")
      )
    )
  ),
  
  tags$hr(),
  
  # ---- Generate Viz Button and FastQ Selector ----
  fluidRow(
    column(12,
           actionButton("generate_viz", "Generate Summary Visualizations from existing fastqs"),
           conditionalPanel(
             condition = "output.show_fastq_selector == true",
             tags$br(),
             shinyDirButton("fastq_dir", "Select FASTQ Directory", title = "Choose FASTQ directory"),
             textOutput("fastq_dir_status")
           )
    )
  )
)


ui <- fluidPage(
  titlePanel("Muth Lab Nanopore Analysis Pipeline"),
  tabsetPanel(
    tabPanel("Pipeline", ui_pipeline),
    tabPanel("Visualizations", ui_visualize)
  )
)


server <- function(input, output, session) {
  
  visualization_path <- reactiveVal(NULL)
  
  volumes <- c(
    "home" = fs::path_home(),
    "MuthLab_Nanopore_Analysis_Pipeline" = getwd(),
    "Root" = "/"
  )
  
  ## ===== File/Directory Choosers =====
  shinyDirChoose(input, "output_dir", roots = volumes, session = session)
  shinyDirChoose(input, "pod5_dir", roots = volumes, session = session)
  shinyDirChoose(input, "fastq_dir", roots = volumes, session = session)
  
  observe({
    if (isTRUE(input$using_custom)) {
      shinyFileChoose(input, "toml_file", roots = volumes, session = session, filetypes = c('', 'toml'))
      shinyFileChoose(input, "fasta_file", roots = volumes, session = session, filetypes = c('', 'fasta'))
    }
  })
  
  ## ====== Path Resolving for Selected Files/Directories ====
  output_dir_path <- reactive({ req(input$output_dir); parseDirPath(volumes, input$output_dir) })
  pod5_dir_path   <- reactive({ req(input$pod5_dir);   parseDirPath(volumes, input$pod5_dir) })
  fastq_dir_path  <- reactive({ req(input$fastq_dir);  parseDirPath(volumes, input$fastq_dir) })
  toml_file_path  <- reactive({ req(input$toml_file);  parseFilePaths(volumes, input$toml_file)$datapath })
  fasta_file_path <- reactive({ req(input$fasta_file); parseFilePaths(volumes, input$fasta_file)$datapath })
  
  ## ===== Feedback Text for Selected Fles/Directories =====
  output$pod5_dir_status <- renderText({ paste("Selected pod5 directory:", pod5_dir_path()) })
  output$output_dir_status <- renderText({ paste("Selected output directory:", output_dir_path()) })
  output$toml_file_status <- renderText({ paste("Selected .toml file:", toml_file_path()) })
  output$fasta_file_status <- renderText({ paste("Selected .fasta file:", fasta_file_path()) })
  output$fastq_dir_status <- renderText({ paste("Selected FASTQ directory:", fastq_dir_path()) })
  
  # === Logic for  Run Pipeline Click ===
  observeEvent(input$run_pipeline, {
    ## ---- takes user input and saves to variable ----
    out_dir <- output_dir_path()
    pod5_dir <- pod5_dir_path()
    run_name <- paste0(format(Sys.time(), "%m-%d-%Y_%H.%M.%S"), "_run")
    
    toml_path <- if (isTRUE(input$using_custom)) toml_file_path() else NULL
    fasta_path <- if (isTRUE(input$using_custom)) fasta_file_path() else NULL
    
    model_acc <- input$model_acc
    kit_name <- input$kit_name
    minimum <- input$min
    maximum <- input$max
    
    ## ---- writes saved variable to yml file ----
    params_list <- list(
      using_custom = isTRUE(input$using_custom),
      model_acc = model_acc,
      kit_name = kit_name,
      min = minimum,
      max = maximum,
      output_dir = file.path(out_dir, run_name),
      pod5_dir = pod5_dir,
      barcode_arrangement = toml_path,
      barcode_sequences = fasta_path,
      run_name = run_name
    )
    
    yaml::write_yaml(params_list, file = "params.yml")
    
    ## ---- runs nextflow script ----
    showNotification("Parameters saved and pipeline started", type = "message")
    result <- system2("nextflow", args = c("run", "main.nf", "-params-file", "params.yml"), stdout = TRUE, stderr = TRUE)
    
    ## ---- saves path to visualizations for access in Visualize tab ----
    visualization_path(file.path(out_dir, run_name, "visualizations"))
    
    ## ---- terminal output ----
    output$pipeline_output <- renderText({ paste(result, collapse = "\n") })
  })
  
  
  
  show_fastq_selector <- reactiveVal(FALSE)
  
  ## ---- logic on clicking generate visualization buttons ----
  observeEvent(input$generate_viz, {
    show_fastq_selector(TRUE)
  })
  
  output$show_fastq_selector <- reactive({ show_fastq_selector() })
  outputOptions(output, "show_fastq_selector", suspendWhenHidden = FALSE)
  
  ## ---- logic on Generate Summary Visualizations from ... click ----
  observeEvent(input$fastq_dir, {
    req(show_fastq_selector())
    req(fastq_dir_path())
    
    showNotification("Running visualization pipeline...", type = "message")
    
    viz_result <- system2("nextflow",
                          args = c("run", "main.nf", "-entry", "visualize", "--fastq_dir", fastq_dir_path()),
                          stdout = TRUE, stderr = TRUE)
    
    ## search for visualizations folder recursively
    results_dir <- file.path(getwd(), "pipeline_results")
    subdirs <- list.dirs(results_dir, full.names = TRUE, recursive = FALSE)
    
    if (length(subdirs) > 0) {
      latest_dir <- subdirs[which.max(file.info(subdirs)$mtime)]
      vis_path <- file.path(latest_dir, "visualizations")
      visualization_path(vis_path)
    }
    
    output$pipeline_output <- renderText({ paste(viz_result, collapse = "\n") })
  })
  
  # ==== NanoComp/NanoPlot outputs ====
  output$plot1 <- renderImage({
    vis_path <- visualization_path()
    req(vis_path)
    img_path <- file.path(vis_path, "LengthvsQualityScatterPlot_dot.png")
    req(file.exists(img_path))
    list(src = img_path, contentType = "image/png", alt = "Length vs Quality")
  }, deleteFile = FALSE)
  
  output$plot2 <- renderImage({
    vis_path <- visualization_path()
    req(vis_path)
    img_path <- file.path(vis_path, "NanoComp_lengths_violin.png")
    req(file.exists(img_path))
    list(src = img_path, contentType = "image/png", alt = "NanoComp lengths")
  }, deleteFile = FALSE)
  
  output$plot3 <- renderImage({
    vis_path <- visualization_path()
    req(vis_path)
    img_path <- file.path(vis_path, "NanoComp_quals_violin.png")
    req(file.exists(img_path))
    list(src = img_path, contentType = "image/png", alt = "NanoComp quals")
  }, deleteFile = FALSE)
  
  output$plot4 <- renderImage({
    vis_path <- visualization_path()
    req(vis_path)
    img_path <- file.path(vis_path, "Non_weightedHistogramReadlength.png")
    req(file.exists(img_path))
    list(src = img_path, contentType = "image/png", alt = "Histogram")
  }, deleteFile = FALSE)
  
  output$nanostats_txt <- renderText({
    vis_path <- visualization_path()
    req(vis_path)
    
    txt_file <- file.path(vis_path, "NanoStats.txt")
    
    lines <- readLines(txt_file)
    
    cutoff_index <- which(grepl("^Top 5", lines))[1]
    
    if (is.na(cutoff_index)) {
      return(paste(lines, collapse = "\n"))
    }
    
    summary_lines <- lines[1:(cutoff_index - 1)]
    paste(summary_lines, collapse = "\n")
  })
  
}

shinyApp(ui = ui, server = server)
