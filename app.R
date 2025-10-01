library(shiny)
library(shinyFiles)
library(yaml) 
library(fs)

## ==== pipeine UI ====
ui_pipeline <- fluidPage(
  fluidRow(
    column(
      width = 3,
      ## ---- pipeline controls ----
      wellPanel(
        tags$p(tags$b("Select your output directory")),
        shinyDirButton(id = "output_dir", label = "output", title = "Select an output directory"),
        textOutput("output_dir_status"),
        tags$br(),
        
        tags$p(tags$b("Select your pod5 directory")),
        shinyDirButton(id = "pod5_dir", label = "pod5", title = "Select directory containing your .pod5 files"),
        textOutput("pod5_dir_status"),
        tags$br(),
        
        checkboxInput("using_custom",
                      HTML("<--- Click if you are using a custom basecalling arrangement"),
                      value = FALSE),
        
        conditionalPanel(
          condition = "input.using_custom == true",
          tags$p(tags$b("Select your barcode arrangement file")),
          shinyFilesButton("toml_file", label = "(.toml)", title = "Select your barcode arrangement file" , multiple = FALSE),
          textOutput("toml_file_status"),
          tags$br(),
          
          tags$p(tags$b("Select your barcode sequencing file")),
          shinyFilesButton("fasta_file", label = "(.fasta)", title = "Select your barcode sequencing file", multiple = FALSE),
          textOutput("fasta_file_status"),
          tags$br()
        ),
        
        selectInput("model_acc", "Select a model accuracy for Dorado",
                    choices = c("sup", "fast", "hac")),
        
        conditionalPanel(
          condition = "input.using_custom == false",
          helpText("Commonly used kits:",
                   tags$br(),
                   "Kit Name: ...",
                   tags$br(),
                   "Kit Name: ...",
                   tags$br(),
                   "Kit Name: ...")
        ),
        
        textInput("kit_name", "Input kit name"),
        
        numericInput("min", "Input a minimum value for length filtering", value = NULL),
        numericInput("max", "Input a maximum value for length filtering (optional)", value = NULL),
        
        actionButton("run_pipeline", "Run Pipeline")
      ),
      
      tags$br(), tags$br(),
      
      ## ---- visualization controls ----
      wellPanel(
        tags$p(tags$b("Generate Visualizations from Existing FASTQ")),
        
        actionButton("generate_viz", "Generate Summary Visualizations"),
        
        conditionalPanel(
          condition = "input.generate_viz > 0",
          tags$br(),
          shinyDirButton("fastq_dir", "Select FASTQ Directory", title = "Choose FASTQ directory"),
          textOutput("fastq_dir_status")
        ),
        
        uiOutput("generate_visualizations_ui")
      )
    ),
    
    ## ---- terminal screen ----
    column(
      width = 9,
      tags$h4("Pipeline Output:"),
      verbatimTextOutput("pipeline_output")  
    )
  )
)


## ==== visualize UI ====
ui_visualize <- fluidPage(
  uiOutput("plot1"),
  uiOutput("plot2"),
  uiOutput("plot3"),
  uiOutput("plot4"),
  
  tags$hr(),
  
  fluidRow(
    column(
      width = 12,
      tags$h4("NanoStats Summary"),
      verbatimTextOutput("nanostats_txt")
    )
  )
)


## ==== combined UI ====
ui <- fluidPage(
  titlePanel("Muth Lab Nanopore Analysis Pipeline"),
  tabsetPanel(
    id = "main_tabs",  
    type = "tabs",
    selected = "Pipeline",
    tabPanel("Pipeline", ui_pipeline),
    tabPanel("Visualizations", ui_visualize)
  )
  
)

## ==== Server ====
server <- function(input, output, session) {
  ## ==== path resolutions and pre-defining ====
  visualization_path <- reactiveVal(NULL)
  
  observeEvent(visualization_path(), {
    req(visualization_path())
    addResourcePath("visualization", visualization_path())
  })
  
  volumes <- c(
    "home" = fs::path_home(),
    "MuthLab_Nanopore_Analysis_Pipeline" = getwd(),
    "Root" = "/"
  )
  
  ## defining file/directory choosers
  shinyDirChoose(input, "output_dir", roots = volumes, session = session)
  shinyDirChoose(input, "pod5_dir", roots = volumes, session = session)
  shinyDirChoose(input, "fastq_dir", roots = volumes, session = session)
  
  
  observe({
    if (isTRUE(input$using_custom)) {
      shinyFileChoose(input, "toml_file", roots = volumes, session = session, filetypes = c('', 'toml'))
      shinyFileChoose(input, "fasta_file", roots = volumes, session = session, filetypes = c('', 'fasta'))
    }
  })
  
  ## path resolving for selected files/directories
  output_dir_path <- reactive({ req(input$output_dir); parseDirPath(volumes, input$output_dir) })
  pod5_dir_path   <- reactive({ req(input$pod5_dir);   parseDirPath(volumes, input$pod5_dir) })
  fastq_dir_path  <- reactive({ req(input$fastq_dir);  parseDirPath(volumes, input$fastq_dir) })
  toml_file_path  <- reactive({ req(input$toml_file);  parseFilePaths(volumes, input$toml_file)$datapath })
  fasta_file_path <- reactive({ req(input$fasta_file); parseFilePaths(volumes, input$fasta_file)$datapath })
  
  ## confirmation text for files/directories
  output$output_dir_status <- renderText({ req(output_dir_path()); paste("Selected output directory:", output_dir_path()) })
  output$pod5_dir_status <- renderText({ req(pod5_dir_path()); paste("Selected pod5 directory:", pod5_dir_path()) })
  output$fastq_dir_status <- renderText({ req(fastq_dir_path()); paste("Selected fastq directory:", fastq_dir_path()) })
  output$toml_file_status <- renderText({ req(toml_file_path()); paste("Selected .toml file:", toml_file_path()) })
  output$fasta_file_status <- renderText({ req(fasta_file_path()); paste("Selected .fasta file:", fasta_file_path()) })
  
  ## ==== trigger pipeline run when button is clicked ====
  observeEvent(input$run_pipeline, {
    ## takes user input and saves to variable
    out_dir <- output_dir_path()
    pod5_dir <- pod5_dir_path()
    run_name <- paste0(format(Sys.time(), "%m-%d_%H.%M.%S", tz = "UTC"), "_run")
    
    toml_path <- if (isTRUE(input$using_custom)) toml_file_path() else NULL
    fasta_path <- if (isTRUE(input$using_custom)) fasta_file_path() else NULL
    
    model_acc <- input$model_acc
    kit_name <- input$kit_name
    minimum <- input$min
    maximum <- input$max
    
    ## writes saved variable to yml file
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
    
    ## runs nextflow script, with messages before and after
    notification <- showNotification("Pipeline running ...", type = "message", duration = NULL)
    result <- system2("nextflow", args = c("run", "main.nf", "-params-file", "params.yml"), stdout = TRUE, stderr = TRUE)
    
    removeNotification(notification)
    showModal(modalDialog(
      title = "Pipeline Complete",
      "Results available in selected directory, and summary visualizations available in visualization tab",
      easyClose = TRUE,
      footer = NULL
    ))
    
    ## saves path to variable for access in visualize tab
    vis_path <- file.path(out_dir, run_name, "visualizations")
    if (dir.exists(vis_path)) {
      visualization_path(vis_path)
      addResourcePath("visualization", vis_path)
    }
    
    
    ## terminal output
    output$pipeline_output <- renderText({ paste(result, collapse = "\n") })
  })
  
  
  
  
  ## ==== trigger visualization generation when button is clicked ====
  observeEvent(fastq_dir_path(), {
    req(fastq_dir_path())
    
    notification <- showNotification("Generating FASTQ visualizations ...", type = "message", duration = NULL)
    result <- system2("nextflow",
                      args = c("run", "main.nf", "-entry", "visualize", "--fastq_dir", fastq_dir_path()),
                      stdout = TRUE, stderr = TRUE)
    
    removeNotification(notification)
    showModal(modalDialog(
      title = "FASTQ Visualizations Complete",
      "Summary visualizations have been successfully generated.",
      easyClose = TRUE,
      footer = NULL
    ))    
    
    ## searches for visualization file recursively, since nextflow entry doesn't have a output_dir parameter
    results_dir <- file.path(getwd(), "pipeline_results")
    subdirs <- list.dirs(results_dir, full.names = TRUE, recursive = FALSE)
    
    if (length(subdirs) > 0) {
      latest_dir <- subdirs[which.max(file.info(subdirs)$mtime)]
      vis_path <- file.path(latest_dir, "visualizations")
      visualization_path(vis_path)
      
      output$pipeline_output <- renderText({ paste(result, collapse = "\n") })
    }
    
    ## terminal output
    output$pipeline_output <- renderText({ paste(result, collapse = "\n") })
    
    ## automatically changes to the visualization tab upon visualization generation
    updateTabsetPanel(session, "Visualizations", selected = NULL)
    
  })
  
  ## ==== nanocomp/nanostats/nanoplot output ====
  output$plot1 <- renderUI({
    req(visualization_path())
    tags$iframe(
      src = "visualization/LengthvsQualityScatterPlot_dot.html",
      width = "100%",
      height = "600px",
      style = "border: none;"
    )
  })
  
  output$plot2 <- renderUI({
    req(visualization_path())
    tags$iframe(
      src = "visualization/NanoComp_lengths_violin.html",
      width = "100%",
      height = "600px",
      style = "border: none;"
    )
  })
  
  output$plot3 <- renderUI({
    req(visualization_path())
    tags$iframe(
      src = "visualization/NanoComp_quals_violin.html",
      width = "100%",
      height = "600px",
      style = "border: none;"
    )
  })
  
  output$plot4 <- renderUI({
    req(visualization_path())
    tags$iframe(
      src = "visualization/Non_weightedHistogramReadlength.html",
      width = "100%",
      height = "600px",
      style = "border: none;"
    )
  })
  
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

