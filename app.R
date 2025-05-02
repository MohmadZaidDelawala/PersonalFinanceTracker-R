# Required libraries
library(shiny)
library(shinydashboard)
library(shinydashboardPlus)
library(plotly)
library(RMySQL)
library(dplyr)
library(openxlsx)
library(shinythemes)
library(rmarkdown)
library(knitr)
library(httr)
library(jsonlite)
library(sodium)
library(lubridate)
library(prophet)
library(ggplot2)
library(tinytex)
library(shinyjs)
library(blastula)


# Define the main UI structure
ui <- dashboardPage(
  dashboardHeader(
    title = "Personal Finance Tracker",
    titleWidth = 300,
    tags$li(class = "dropdown",
            tags$a(href = "#", icon("bell"), class = "nav-link"),
            tags$a(href = "#", icon("user-circle"), class = "nav-link")
    )
  ),
  dashboardSidebar(
    width = 300,
    tags$head(tags$style(HTML("
      .main-sidebar { 
        background-color: #2d3436; 
        margin-top: 70px;
        height: calc(100vh - 70px);
        border-right: 2px solid #2c3e50;
      }
      .skin-blue .main-header .logo {
        background-color: #2d3436 !important;
        height: 70px;
        line-height: 70px;
      }
      .skin-blue .main-header .navbar {
        background-color: #2d3436 !important;
        height: 70px;
        margin-left: 300px;
      }
      body {
        background-color: #000000 !important;
        overflow: hidden;
      }
      .tab-content {
        height: 100vh;
        overflow: hidden;
      }
      .box {
        background-color: #333333;
        color: #ffffff;
        border-radius: 15px;
        box-shadow: 0 4px 15px rgba(0,0,0,0.1);
        padding: 30px;
        border: 1px solid #e0e0e0;
        margin: 50px auto;
        width: 60%;
        transition: all 0.4s ease-in-out;
        text-align: center;
      }
      .box-header {
        background-color: #00b894;
        color: #ffffff;
        font-size: 20px;
        border-radius: 10px 10px 0 0;
      }
      .btn-primary {
        background-color: #0984e3;
        border-color: #0984e3;
        color: #fff;
        border-radius: 25px;
        padding: 12px 25px;
        font-size: 16px;
        transition: all 0.3s ease;
        margin-top: 15px;
      }
      .btn-primary:hover {
        background-color: #74b9ff;
        border-color: #74b9ff;
        color: white;
        transform: scale(1.05);
      }
      .form-control {
        width: 100%;
        margin-bottom: 10px;
      }
      table.dataTable a {
    color: #ffffff !important;
    text-decoration: none;
    pointer-events: none;
  }
    "))),
    sidebarMenuOutput("sidebar") # Dynamically render sidebar based on login status
  ),
  dashboardBody(
    useShinyjs(),
    uiOutput("main_content") # Dynamically render main content based on login status
  )
)

# Define server logic
server <- function(input, output, session) {
  # Connect to the database
  library(RMySQL)
  
  con <- dbConnect(RMySQL::MySQL(),
                   user = "411691",
                   password = "M.zaid_01",  # Replace with the password you created
                   host = "mysql-mohmadzaid.alwaysdata.net",
                   dbname = "mohmadzaid_personal_finance",
                   port = 3306
  )
  
  
  # Function to add specific columns to existing user-specific bill reminders tables
  add_columns_if_not_exists <- function(user_id, con) {
    table_name <- sprintf("bill_reminders_user_%d", user_id)
    
    # Check if table exists
    check_table_query <- sprintf("SHOW TABLES LIKE '%s'", table_name)
    table_exists <- dbGetQuery(con, check_table_query)
    
    # Only proceed if table exists
    if (nrow(table_exists) > 0) {
      # Check if 'recurrence' column exists
      check_column_query_recurrence <- sprintf("SHOW COLUMNS FROM %s LIKE 'recurrence'", table_name)
      recurrence_column_exists <- dbGetQuery(con, check_column_query_recurrence)
      
      # Check if 'notification_days' column exists
      check_column_query_notification <- sprintf("SHOW COLUMNS FROM %s LIKE 'notification_days'", table_name)
      notification_column_exists <- dbGetQuery(con, check_column_query_notification)
      
      # Check if 'status' column exists
      check_column_query_status <- sprintf("SHOW COLUMNS FROM %s LIKE 'status'", table_name)
      status_column_exists <- dbGetQuery(con, check_column_query_status)
      
      # Add 'recurrence' column if it does not exist
      if (nrow(recurrence_column_exists) == 0) {
        alter_query_recurrence <- sprintf("ALTER TABLE %s ADD COLUMN recurrence VARCHAR(50) DEFAULT 'One-time'", table_name)
        dbSendQuery(con, alter_query_recurrence)
      }
      
      # Add 'notification_days' column if it does not exist
      if (nrow(notification_column_exists) == 0) {
        alter_query_notification <- sprintf("ALTER TABLE %s ADD COLUMN notification_days INT DEFAULT 0", table_name)
        dbSendQuery(con, alter_query_notification)
      }
      
      # Add 'status' column if it does not exist
      if (nrow(status_column_exists) == 0) {
        alter_query_status <- sprintf("ALTER TABLE %s ADD COLUMN status VARCHAR(10) DEFAULT 'Unpaid'", table_name)
        dbSendQuery(con, alter_query_status)
      }
    }
  }
  
  
  send_bill_reminder_email <- function(to_email, subject, body) {
    library(blastula)
    
    email <- compose_email(
      body = md(body)
    )
    
    smtp_send(
      email,
      from = "tiworkac786@gmail.com",
      to = to_email,
      subject = subject,
      credentials = creds_file("gmail_creds")  # ✅ correct syntax
    )
    
  }
  
  
  
  
  
  # Function to create user-specific tables
  create_user_tables <- function(user_id) {
    tables <- c("transactions", "savings_goal", "bill_reminders", "usable_amount")
    for (table in tables) {
      query <- sprintf(
        "CREATE TABLE IF NOT EXISTS %s_user_%d LIKE %s",
        table, user_id, table
      )
      dbSendQuery(con, query)
    }
    
    # Add month column to the savings_goal_user table
    query <- sprintf("ALTER TABLE savings_goal_user_%d ADD COLUMN month VARCHAR(7) NOT NULL", user_id)
    dbSendQuery(con, query)
  }
  
  observe({
    invalidateLater(86400000, session)  # 24 hrs
    
    user_id <- isolate(user_session()$user_id)
    user_email <- isolate(user_session()$email)
    if (is.null(user_id) || is.null(user_email)) return()
    
    today <- Sys.Date()
    
    query <- sprintf("SELECT name, date, notification_days FROM bill_reminders_user_%d WHERE status = 'Unpaid'", user_id)
    reminders <- dbGetQuery(con, query)
    
    reminders <- reminders %>%
      mutate(date = as.Date(date)) %>%
      filter(date - today <= notification_days & date - today >= 0)
    
    for (i in 1:nrow(reminders)) {
      subject <- paste("🔔 Bill Reminder:", reminders$name[i])
      body <- paste0(
        "**Hello, ", user_session()$username, "**\n\n",
        "🔔 Your bill **_", reminders$name[i], "_** is due on **", reminders$date[i], "**.\n",
        "Please make the payment soon.\n\n",
        "_- Your Personal Finance Tracker App_"
      )
      
      
      send_bill_reminder_email(user_email, subject, body)
    }
  })
  
  
  
  # Function to check if a column exists in a table
  column_exists <- function(con, table_name, column_name) {
    query <- sprintf("SHOW COLUMNS FROM %s LIKE '%s'", table_name, column_name)
    result <- dbGetQuery(con, query)
    return(nrow(result) > 0)
  }
  # Apply this function to each user-specific table
  user_ids <- dbGetQuery(con, "SELECT user_id FROM users")$user_id
  
  for (user_id in user_ids) {
    add_columns_if_not_exists(user_id, con)
  }
  
  
  # Reactive value to store user session data
  user_session <- reactiveVal(NULL)
  # ===== 1. DAILY EXPENSE DATA (no transformation) =====
  daily_expense_data <- reactive({
    user_id <- user_session()$user_id
    if (is.null(user_id)) return(NULL)
    
    query <- sprintf("SELECT date, amount FROM transactions_user_%d", user_id)
    df <- dbGetQuery(con, query)
    if (nrow(df) < 10) return(NULL)
    
    df$date <- as.Date(df$date)
    df <- df %>%
      group_by(date) %>%
      summarise(y = sum(amount), .groups = 'drop') %>%
      rename(ds = date)
    
    # Fill missing dates with 0
    full_days <- data.frame(ds = seq(min(df$ds), Sys.Date(), by = "day"))
    filled <- left_join(full_days, df, by = "ds")
    filled$y[is.na(filled$y)] <- 0
    
    return(filled)
  })
  
  
  # ===== 2. FORECAST PLOT (using raw values) =====
  output$expense_forecast_plot <- renderPlotly({
    data <- daily_expense_data()
    if (is.null(data)) return(NULL)
    
    # Train Prophet on raw values
    m <- prophet(data, daily.seasonality = TRUE, weekly.seasonality = TRUE, yearly.seasonality = FALSE)
    future <- make_future_dataframe(m, periods = 30)
    forecast <- predict(m, future)
    
    # Clip negatives if any
    forecast$yhat <- pmax(forecast$yhat, 0)
    forecast$yhat_lower <- pmax(forecast$yhat_lower, 0)
    forecast$yhat_upper <- pmax(forecast$yhat_upper, 0)
    
    # Plot
    p <- ggplot(forecast, aes(x = ds, y = yhat)) +
      geom_line(color = "#0984e3") +
      geom_ribbon(aes(ymin = yhat_lower, ymax = yhat_upper), fill = "#dfe6e9", alpha = 0.4) +
      labs(title = "30-Day Expense Forecast (Daily View)", x = "Date", y = "Predicted Amount (₹)") +
      theme_minimal()
    
    ggplotly(p)
  })
  
  
  # ===== 3. FORECAST SUMMARY TEXT (accurate & raw) =====
  output$forecast_summary <- renderText({
    user_id <- user_session()$user_id  # or hardcode: user_id <- 10
    data <- daily_expense_data()
    if (is.null(data)) return("")
    
    m <- prophet(data, daily.seasonality = TRUE, weekly.seasonality = TRUE)
    future <- make_future_dataframe(m, periods = 30)
    forecast <- predict(m, future)
    
    forecast$yhat <- pmax(forecast$yhat, 0)
    
    # Debug: Print last forecasted values in console
    print(tail(forecast[, c("ds", "yhat")], 10))
    
    total_30_days <- sum(tail(forecast$yhat, 30))
    paste("Estimated total spending for the next 30 days: ₹", format(round(total_30_days, 2), big.mark = ","))
  })
  
  
  
  
  # Render sidebar based on login status
  output$sidebar <- renderMenu({
    if (is.null(user_session())) {
      sidebarMenu(
        menuItem("Register", tabName = "register", icon = icon("user-plus")),
        menuItem("Login", tabName = "login", icon = icon("sign-in-alt"))
      )
    } else {
      sidebarMenu(
        menuItem("Set Salary & Savings", tabName = "salary", icon = icon("dollar-sign")),
        menuItem("Add Transaction", tabName = "add_transaction", icon = icon("plus-circle")),
        menuItem("Total Expenses", tabName = "total_expenses", icon = icon("calculator")),
        menuItem("Visualize Spending", tabName = "visualize_spending", icon = icon("chart-bar")),
        menuItem("Set Bill Reminder", tabName = "set_bill_reminder", icon = icon("bell")),
        menuItem("Expense Forecast", tabName = "forecast", icon = icon("chart-line")),
        menuItem("Display Bill Reminders", tabName = "display_bill_reminders", icon = icon("list-alt")),
        menuItem("Expense Report", tabName = "expense_report", icon = icon("file-alt")),
        menuItem("Erase Data", tabName = "erase_data", icon = icon("trash-alt")),
        menuItem("Currency Settings", tabName = "currency_settings", icon = icon("money-bill-alt")),
        selectInput("currency_select", "Preferred Currency:",
                    choices = c("USD", "EUR", "INR", "AUD", "GBP", "JPY"),
                    selected = "INR"),  # Default currency is USD
        menuItem("Logout", tabName = "logout", icon = icon("sign-out-alt"))
      )
    }
  })
  
  # Render main content based on login status
  output$main_content <- renderUI({
    if (is.null(user_session())) {
      # Display login/register screen with centered box layout
      tabItems(
        tabItem(tabName = "register",
                fluidRow(
                  column(width = 10, offset = 1,
                         div(style = "display: flex; justify-content: center; align-items: center; height: 80vh;",
                             box(title = "Register", width = 12, solidHeader = TRUE,
                                 textInput("register_username", "Username"),
                                 passwordInput("register_password", "Password"),
                                 passwordInput("register_confirm_password", "Confirm Password"),
                                 textInput("register_email", "Email"),
                                 actionButton("register_button", "Register", class = "btn-primary"),
                                 textOutput("register_message")
                             )
                         )
                  )
                )
        ),
        tabItem(tabName = "login",
                fluidRow(
                  column(width = 10, offset = 1,
                         div(style = "display: flex; justify-content: center; align-items: center; height: 80vh;",
                             box(title = "Login", width = 12, solidHeader = TRUE,
                                 textInput("login_username", "Username"),
                                 passwordInput("login_password", "Password"),
                                 actionButton("login_button", "Login", class = "btn-primary"),
                                 textOutput("login_message")
                             )
                         )
                  )
                )
        )
      )
    }
    else {
      # Main Personal Finance Tracker Interface after login
      tabItems(
        tabItem(tabName = "salary",
                fluidRow(
                  column(width = 12,  
                         div(style = "display: flex; justify-content: center; align-items: center; height: 80vh;", 
                             box(title = "Set Salary and Savings Goal", width = 12, solidHeader = TRUE,
                                 dateInput("month_input", "Select Month", value = floor_date(Sys.Date(), "month"), format = "yyyy-mm", startview = "year"),
                                 numericInput("salary_input", "Enter your monthly salary:", value = 0, min = 0),
                                 numericInput("goal_input", "Enter your savings goal:", value = 0, min = 0),
                                 actionButton("set_goal_button", "Set Goal", class = "btn-primary"),
                                 textOutput("goal_status"))
                         )
                  )
                )
        ),
        tabItem(tabName = "add_transaction",
                fluidRow(
                  column(width = 10, offset = 1,
                         div(style = "display: flex; justify-content: center; align-items: center; height: 80vh;",
                             box(title = "Add New Transaction", width = 12, solidHeader = TRUE,
                                 dateInput("date_input", "Transaction Date:", value = Sys.Date()),
                                 selectInput("category_input", "Transaction Category:", 
                                             choices = c("Food", "Travel", "Shopping", "Bill Payment", "Rent", "Other")),
                                 textInput("custom_category_input", "Enter custom category (if other selected):"),
                                 numericInput("amount_input", "Enter transaction amount:", value = 0, min = 0),
                                 selectInput("payment_mode_input", "Select Payment Mode:",
                                             choices = c("Cash", "UPI", "Credit/Debit Card", "Cheque", "Other")),
                                 actionButton("add_transaction_button", "Add Transaction", class = "btn-primary"),
                                 textOutput("transaction_status"))
                         )
                  )
                )
        ),
        tabItem(tabName = "total_expenses",
                fluidRow(
                  column(width = 10, offset = 1,
                         div(style = "display: flex; justify-content: center; align-items: center; height: 80vh;",
                             box(title = "Total Monthly Summary", width = 12, solidHeader = TRUE,
                                 dateInput("expense_month_input", "Select Month for Summary", value = floor_date(Sys.Date(), "month"), format = "yyyy-mm", startview = "year"),
                                 textOutput("total_salary_output"),
                                 textOutput("saving_goal_output"),
                                 textOutput("total_expense_output"),
                                 textOutput("remaining_amount_output"))
                         )
                  )
                )
        ),
        
        
        # Visualize Spending
        tabItem(tabName = "visualize_spending",
                fluidRow(
                  column(width = 10, offset = 1,
                         div(style = "display: flex; justify-content: center; align-items: center; height: 80vh;",
                             box(title = "Visualize Spending", width = 12, solidHeader = TRUE,
                                 selectInput("selected_month", "Select Month:",
                                             choices = NULL,  # Will be dynamically populated
                                             selected = format(Sys.Date(), "%Y-%m")),
                                 
                                 radioButtons("spending_type", "Select Spending Type:",
                                              choices = c("Category-wise", "Date-wise", "Payment Mode-wise","Savings Tracker"),
                                              selected = "Category-wise"),
                                 plotlyOutput("spending_plot"))
                         )
                  )
                )
        ),
        
        # Set Bill Reminder
        tabItem(tabName = "set_bill_reminder",
                fluidRow(
                  column(width = 10, offset = 1,
                         div(style = "display: flex; justify-content: center; align-items: center; height: 80vh;",
                             box(title = "Set Bill Reminder", width = 12, solidHeader = TRUE,
                                 dateInput("bill_date_input", "Enter the bill due date:"),
                                 selectInput("bill_name_input", "Bill Name:", 
                                             choices = c("Mobile Bill", "Electricity Bill", "Credit Card", "Rent", "Other")),
                                 numericInput("bill_amount_input", "Amount:", value = 0, min = 0),
                                 selectInput("recurrence_input", "Recurrence:", choices = c("One-time", "Weekly", "Monthly", "Yearly")),
                                 sliderInput("notification_days_input", "Notify Before (Days):", min = 0, max = 7, value = 3),
                                 actionButton("set_reminder_button", "Set Bill Reminder", class = "btn-primary"),
                                 textOutput("bill_reminder_status")
                             )
                         )
                  )
                )
        ),
        
        # Display Bill Reminders Tab
        
        # Display Bill Reminders Tab
        tabItem(tabName = "display_bill_reminders",
                fluidRow(
                  column(6,
                         box(
                           title = "📋 Bill Reminders",
                           width = 12,
                           solidHeader = TRUE,
                           style = "height: 500px; overflow-y: auto;",
                           selectInput("reminder_month_filter", "📅 Select Month:", choices = NULL, selected = format(Sys.Date(), "%Y-%m")),
                           DT::DTOutput("BillRemindersTable"),
                           br()
                           
                         )
                  ),
                  column(6,
                         box(
                           title = "🗓️ Calendar View",
                           width = 12,
                           solidHeader = TRUE,
                           style = "height: 500px;",
                           actionButton("prev_month", "<< Previous"),
                           actionButton("next_month", "Next >>"),
                           plotlyOutput("reminder_calendar")
                         )
                  )
                )
        ),
        
        
        
        
        # Expense Report Tab
        tabItem(tabName = "expense_report",
                fluidRow(
                  column(width = 10, offset = 1,
                         div(style = "display: flex; justify-content: center; align-items: center; height: 80vh;",
                             box(title = "Expense Report", width = 12, solidHeader = TRUE,
                                 dateInput("report_month_input", "Select Month for Report:", value = Sys.Date(), format = "yyyy-mm", startview = "year"),
                                 div(style = "max-height: 300px; overflow-y: auto;",
                                     tableOutput("expense_report_table")
                                 ),
                                 br(),
                                 div(
                                   downloadButton("download_expense_report", "Download Expense Report (Excel)", class = "btn btn-success"),
                                   downloadButton("download_pdf_report", "Download Expense Report (PDF)", class = "btn btn-info")
                                 )
                             )
                             
                         )
                  )
                )
        ),
        
        tabItem(tabName = "forecast",
                fluidRow(
                  column(width = 10, offset = 1,
                         div(style = "display: flex; justify-content: center; align-items: center; height: 80vh;",
                             box(title = "30-Day Expense Forecast", width = 12, solidHeader = TRUE,
                                 plotlyOutput("expense_forecast_plot"),
                                 br(),
                                 textOutput("forecast_summary")
                             )
                             
                         )
                  )
                )
        ),
        
        
        
        # Erase Data
        tabItem(tabName = "erase_data",
                fluidRow(
                  column(width = 10, offset = 1,
                         div(style = "display: flex; justify-content: center; align-items: center; height: 80vh;",
                             box(title = "Erase Data", width = 12, solidHeader = TRUE,
                                 checkboxGroupInput("erase_options", "Select Options to Erase:",
                                                    choices = c("Erase Transaction", "Erase Saving Goal", "Erase Bill Reminder")),
                                 actionButton("erase_transactions_button", "Erase Data", class = "btn btn-danger"),
                                 textOutput("erase_transactions_status"))
                         )
                  )
                  
                )        
        )
      )
    }
  })
  
  
  
  # Function to add specific columns to existing user-specific bill reminders tables
  add_columns_if_not_exists <- function(user_id, con) {
    table_name <- sprintf("bill_reminders_user_%d", user_id)
    
    # Check if table exists
    check_table_query <- sprintf("SHOW TABLES LIKE '%s'", table_name)
    table_exists <- dbGetQuery(con, check_table_query)
    
    # Only proceed if table exists
    if (nrow(table_exists) > 0) {
      # Check if 'recurrence' column exists
      check_column_query_recurrence <- sprintf("SHOW COLUMNS FROM %s LIKE 'recurrence'", table_name)
      recurrence_column_exists <- dbGetQuery(con, check_column_query_recurrence)
      
      # Check if 'notification_days' column exists
      check_column_query_notification <- sprintf("SHOW COLUMNS FROM %s LIKE 'notification_days'", table_name)
      notification_column_exists <- dbGetQuery(con, check_column_query_notification)
      
      # Check if 'status' column exists
      check_column_query_status <- sprintf("SHOW COLUMNS FROM %s LIKE 'status'", table_name)
      status_column_exists <- dbGetQuery(con, check_column_query_status)
      
      # Add 'recurrence' column if it does not exist
      if (nrow(recurrence_column_exists) == 0) {
        alter_query_recurrence <- sprintf("ALTER TABLE %s ADD COLUMN recurrence VARCHAR(50) DEFAULT 'One-time'", table_name)
        dbSendQuery(con, alter_query_recurrence)
      }
      
      # Add 'notification_days' column if it does not exist
      if (nrow(notification_column_exists) == 0) {
        alter_query_notification <- sprintf("ALTER TABLE %s ADD COLUMN notification_days INT DEFAULT 0", table_name)
        dbSendQuery(con, alter_query_notification)
      }
      
      # Add 'status' column if it does not exist
      if (nrow(status_column_exists) == 0) {
        alter_query_status <- sprintf("ALTER TABLE %s ADD COLUMN status VARCHAR(10) DEFAULT 'Unpaid'", table_name)
        dbSendQuery(con, alter_query_status)
      }
    }
  }
  
  
  
  # Function to create user-specific tables
  create_user_tables <- function(user_id) {
    tables <- c("transactions", "savings_goal", "bill_reminders", "usable_amount")
    for (table in tables) {
      query <- sprintf(
        "CREATE TABLE IF NOT EXISTS %s_user_%d LIKE %s",
        table, user_id, table
      )
      dbSendQuery(con, query)
    }
    
    # Add month column to the savings_goal_user table
    # Ensure month column exists
    dbExecute(con, sprintf("ALTER TABLE savings_goal_user_%d ADD COLUMN IF NOT EXISTS month VARCHAR(7) NOT NULL", user_id))
    dbExecute(con, sprintf("ALTER TABLE usable_amount_user_%d ADD COLUMN IF NOT EXISTS month VARCHAR(7) NOT NULL", user_id))
  }
  
  
  # Function to check if a column exists in a table
  column_exists <- function(con, table_name, column_name) {
    query <- sprintf("SHOW COLUMNS FROM %s LIKE '%s'", table_name, column_name)
    result <- dbGetQuery(con, query)
    return(nrow(result) > 0)
  }
  
  
  # Registration Handler with user-specific table creation
  observeEvent(input$register_button, {
    username <- input$register_username
    password <- input$register_password
    confirm_password <- input$register_confirm_password
    email <- input$register_email
    
    if (password != confirm_password) {
      output$register_message <- renderText("Passwords do not match.")
      return()
    }
    
    hashed_password <- sodium::password_store(password)
    
    existing_user <- dbGetQuery(con, sprintf("SELECT * FROM users WHERE username = '%s'", username))
    if (nrow(existing_user) > 0) {
      output$register_message <- renderText("Username already exists.")
    } else {
      # Insert new user record
      query <- sprintf("INSERT INTO users (username, password, email) VALUES ('%s', '%s', '%s')", 
                       username, hashed_password, email)
      dbExecute(con, query)
      
      # Get new user's ID and create personalized tables
      user_id <- dbGetQuery(con, "SELECT LAST_INSERT_ID() AS user_id")$user_id[1]
      create_user_tables(user_id)
      
      output$register_message <- renderText("Registration successful. You can now log in.")
    }
  })
  
  # Login Handler
  observeEvent(input$login_button, {
    username <- input$login_username
    password <- input$login_password
    
    user <- dbGetQuery(con, sprintf("SELECT * FROM users WHERE username = '%s'", username))
    
    if (nrow(user) == 1 && sodium::password_verify(user$password[1], password)) {
      user_session(list(user_id = user$user_id[1], username = username,email = user$email[1]))
      output$login_message <- renderText("Login successful.")
    } else {
      output$login_message <- renderText("Invalid username or password.")
    }
  })
  
  
  # Function to set a savings goal (user-specific)
  set_user_savings_goal <- function(user_id, salary, goal, month) {
    if (goal >= 0) {
      query <- sprintf("INSERT INTO savings_goal_user_%d (user_id, month, salary, goal) VALUES (%d, '%s', %f, %f)",
                       user_id, user_id, month, salary, goal)
      dbSendQuery(con, query)
      
      usable_amt <- salary - goal
      
      # Total expenses should only be for the selected month!
      expense_query <- sprintf("SELECT IFNULL(SUM(amount), 0) AS total_expense FROM transactions_user_%d WHERE DATE_FORMAT(date, '%%Y-%%m') = '%s'", user_id, month)
      total_expense <- dbGetQuery(con, expense_query)$total_expense
      
      remaining_amt <- usable_amt - total_expense
      insert_user_usable_amount(user_id, usable_amt, remaining_amt, month)
    }
  }
  
  
  
  
  # Function to add a transaction (user-specific)
  add_user_transaction <- function(user_id, date, category, amount, payment_mode) {
    month <- format(as.Date(date), "%Y-%m")  # Extract month from date
    usable_amt <- get_user_usable_amount(user_id, month)
    total_expense <- get_user_total_expenses(user_id, month)
    remaining_amt <- usable_amt - total_expense
    
    print(paste("Debug - Remaining amount:", remaining_amt))
    
    if (amount > 0 && amount <= remaining_amt) {
      query <- sprintf(
        "INSERT INTO transactions_user_%d (date, category, amount, payment_mode, user_id) VALUES ('%s', '%s', %.2f, '%s', %d)",
        user_id, date, category, amount, payment_mode, user_id
      )
      
      print(paste("Executing query:", query))
      
      tryCatch({
        dbSendQuery(con, query)
        update_user_remaining_amount(user_id, remaining_amt - amount, month)
      }, error = function(e) {
        print(paste("❌ DB Error:", e$message))
      })
    } else {
      print("❌ Transaction not added: amount exceeds remaining usable amount.")
    }
  }
  
  
  
  # Function to get total expenses (user-specific)
  get_user_total_expenses <- function(user_id, month) {
    query <- sprintf("SELECT IFNULL(SUM(amount), 0) AS total FROM transactions_user_%d WHERE DATE_FORMAT(date, '%%Y-%%m') = '%s'", user_id, month)
    result <- dbGetQuery(con, query)
    return(result$total)
  }
  
  # Function to get usable amount from user-specific usable_amount table
  get_user_usable_amount <- function(user_id, month) {
    query <- sprintf("SELECT usable_amount FROM usable_amount_user_%d WHERE month = '%s' ORDER BY id DESC LIMIT 1", user_id, month)
    result <- dbGetQuery(con, query)
    return(ifelse(nrow(result) > 0, result$usable_amount, 0))
  }
  
  
  # Function to insert usable amount and remaining amount (user-specific)
  insert_user_usable_amount <- function(user_id, usable_amt, remaining_amt, month) {
    query <- sprintf("INSERT INTO usable_amount_user_%d (usable_amount, remaining_amount, user_id, month) VALUES (%.2f, %.2f, %d, '%s')", 
                     user_id, usable_amt, remaining_amt, user_id, month)
    dbSendQuery(con, query)
  }
  
  #no duplicate salary and goals
  observeEvent(input$month_input, {
    user_id <- user_session()$user_id
    selected_month <- format(input$month_input, "%Y-%m")
    
    # Check if goal already exists
    query <- sprintf("SELECT salary, goal FROM savings_goal_user_%d WHERE month = '%s'", user_id, selected_month)
    result <- dbGetQuery(con, query)
    
    if (nrow(result) > 0) {
      # Disable inputs and button
      updateNumericInput(session, "salary_input", value = result$salary[1])
      updateNumericInput(session, "goal_input", value = result$goal[1])
      shinyjs::disable("salary_input")
      shinyjs::disable("goal_input")
      shinyjs::disable("set_goal_button")
      
      output$goal_status <- renderText(sprintf("Already set: ₹%s salary, ₹%s savings goal", 
                                               format(result$salary[1], big.mark = ","),
                                               format(result$goal[1], big.mark = ",")))
    } else {
      # Enable everything if no data exists
      shinyjs::enable("salary_input")
      shinyjs::enable("goal_input")
      shinyjs::enable("set_goal_button")
      output$goal_status <- renderText("")
    }
  })
  
  
  
  # Function to update remaining amount (user-specific)
  update_user_remaining_amount <- function(user_id, remaining_amt, month) {
    query <- sprintf("UPDATE usable_amount_user_%d SET remaining_amount = %.2f WHERE month = '%s'", user_id, remaining_amt, month)
    dbSendQuery(con, query)
  }
  
  observe({
    user <- user_session()
    if (!is.null(user)) {
      user_id <- user$user_id
      query <- sprintf("SELECT DISTINCT DATE_FORMAT(date, '%%Y-%%m') AS month FROM bill_reminders_user_%d ORDER BY month DESC", user_id)
      months <- dbGetQuery(con, query)$month
      if (length(months) > 0) {
        updateSelectInput(session, "reminder_month_filter", choices = months, selected = max(months))
      }
    }
  })
  
  
  
  observe({
    user_id <- user_session()$user_id
    if (!is.null(user_id)) {
      query <- sprintf("SELECT DISTINCT DATE_FORMAT(date, '%%Y-%%m') AS month FROM transactions_user_%d ORDER BY month DESC", user_id)
      months <- dbGetQuery(con, query)$month
      updateSelectInput(session, "selected_month", choices = months, selected = max(months))
    }
  })
  
  output$spending_plot <- renderPlotly({
    user_id <- user_session()$user_id
    selected_month <- input$selected_month
    
    if (is.null(user_id) || is.null(selected_month)) return(NULL)
    
    if (input$spending_type == "Category-wise") {
      query <- sprintf("SELECT category, SUM(amount) AS total_amount FROM transactions_user_%d WHERE DATE_FORMAT(date, '%%Y-%%m') = '%s' GROUP BY category", user_id, selected_month)
      df <- dbGetQuery(con, query)
      if (nrow(df) == 0) return(NULL)
      plot_ly(df, labels = ~category, values = ~total_amount, type = 'pie') %>%
        layout(title = paste("Spending by Category -", selected_month))
      
    } else if (input$spending_type == "Date-wise") {
      query <- sprintf("SELECT date, SUM(amount) AS total_amount FROM transactions_user_%d WHERE DATE_FORMAT(date, '%%Y-%%m') = '%s' GROUP BY date", user_id, selected_month)
      df <- dbGetQuery(con, query)
      if (nrow(df) == 0) return(NULL)
      plot_ly(df, x = ~date, y = ~total_amount, type = 'bar') %>%
        layout(title = paste("Spending by Date -", selected_month), xaxis = list(title = "Date"), yaxis = list(title = "Total Amount"))
      
    } else if (input$spending_type == "Payment Mode-wise") {
      query <- sprintf("SELECT payment_mode, SUM(amount) AS total_amount FROM transactions_user_%d WHERE DATE_FORMAT(date, '%%Y-%%m') = '%s' GROUP BY payment_mode", user_id, selected_month)
      df <- dbGetQuery(con, query)
      if (nrow(df) == 0) return(NULL)
      plot_ly(df, x = ~payment_mode, y = ~total_amount, type = 'bar') %>%
        layout(title = paste("Spending by Payment Mode -", selected_month), xaxis = list(title = "Payment Mode"), yaxis = list(title = "Total Amount"))
    }else if (input$spending_type == "Savings Tracker") {
      # 1. Get planned savings
      savings_query <- sprintf("SELECT month, salary, goal FROM savings_goal_user_%d", user_id)
      planned <- dbGetQuery(con, savings_query)
      
      # 2. Get actual expenses
      expenses_query <- sprintf("
      SELECT DATE_FORMAT(date, '%%Y-%%m') AS month, SUM(amount) AS total_expense
      FROM transactions_user_%d
      GROUP BY month
    ", user_id)
      actual <- dbGetQuery(con, expenses_query)
      
      # 3. Merge and calculate actual savings
      combined <- merge(planned, actual, by = "month", all.x = TRUE)
      combined$total_expense[is.na(combined$total_expense)] <- 0
      combined$actual_savings <- combined$salary - combined$total_expense
      
      # 4. Return plotly chart
      plot_ly(combined, x = ~month) %>%
        add_trace(y = ~goal, name = "Planned Savings", type = 'bar') %>%
        add_trace(y = ~actual_savings, name = "Actual Savings", type = 'bar') %>%
        layout(barmode = 'group',
               title = "Planned vs Actual Savings Per Month",
               yaxis = list(title = "Amount (₹)"),
               xaxis = list(title = "Month"))
    }
    
    
  })
  
  
  # Function to set a bill reminder (user-specific)
  set_user_bill_reminder <- function(user_id, date, name, amount, recurrence) {
    query <- sprintf("INSERT INTO bill_reminders_user_%d (date, name, amount, recurrence, user_id) VALUES ('%s', '%s', %.2f, '%s', %d)", 
                     user_id, date, name, amount, recurrence, user_id)
    dbSendQuery(con, query)
  }
  
  
  # Function to display bill reminders (user-specific)
  get_user_bill_reminders <- function(user_id) {
    query <- sprintf("SELECT date, name, amount FROM bill_reminders_user_%d", user_id)
    result <- dbGetQuery(con, query)
    return(result)
  }
  
  
  # Reactive value to track the selected month
  selected_month <- reactiveVal(Sys.Date())
  
  # Update selected_month when navigating
  observeEvent(input$prev_month, { selected_month(selected_month() %m-% months(1)) })
  observeEvent(input$next_month, { selected_month(selected_month() %m+% months(1)) })
  
  get_filtered_reminders <- function(user_id, date_filter, status_filter, selected_month) {
    current_date <- Sys.Date()
    conditions <- list()
    
    # Add month filter
    if (!is.null(selected_month)) {
      conditions <- c(conditions, sprintf("DATE_FORMAT(date, '%%Y-%%m') = '%s'", selected_month))
    }
    
    # Add date filter
    date_query <- switch(date_filter,
                         "Next 7 Days" = sprintf("date BETWEEN '%s' AND '%s'", current_date, current_date + 7),
                         "This Week" = sprintf("YEARWEEK(date, 1) = YEARWEEK('%s', 1)", current_date),
                         "This Month" = sprintf("MONTH(date) = MONTH('%s') AND YEAR(date) = YEAR('%s')", current_date, current_date),
                         "All" = NULL)
    
    if (!is.null(date_query)) {
      conditions <- c(conditions, date_query)
    }
    
    # Add status filter
    if (status_filter != "All") {
      conditions <- c(conditions, sprintf("status = '%s'", status_filter))
    }
    
    where_clause <- if (length(conditions) > 0) paste("WHERE", paste(conditions, collapse = " AND ")) else ""
    
    query <- sprintf("SELECT * FROM bill_reminders_user_%d %s", user_id, where_clause)
    dbGetQuery(con, query)
  }
  
  
  
  
  
  # Render reminders table based on selected filter with scrollable table when necessary
  output$BillRemindersTable <- DT::renderDT({
    user_id <- user_session()$user_id
    if (is.null(user_id) || is.null(input$reminder_month_filter)) return(NULL)
    
    selected_month <- input$reminder_month_filter
    
    query <- sprintf(
      "SELECT * FROM bill_reminders_user_%d WHERE DATE_FORMAT(date, '%%Y-%%m') = '%s'",
      user_id, selected_month
    )
    
    reminders <- dbGetQuery(con, query)
    if (nrow(reminders) == 0) return(NULL)
    
    DT::datatable(
      reminders,
      escape = FALSE,  # allow rendering of raw HTML (e.g., prevent auto-linking)
      options = list(
        pageLength = 10,
        scrollY = "300px",
        dom = 'tip',
        columnDefs = list(list(className = 'dt-left', targets = "_all"))
      ),
      class = "cell-border stripe hover nowrap"
    )
  })
  
  
  
  
  # Function to get recurring reminders for a given month
  get_monthly_reminders <- function(user_id, month_start) {
    reminders <- dbGetQuery(con, sprintf("SELECT date, name, amount, recurrence FROM bill_reminders_user_%d", user_id))
    recurring_reminders <- reminders %>%
      mutate(
        date = as.Date(date),
        day = day(date)
      ) %>%
      filter(
        (recurrence == "Monthly" & between(date, month_start, month_start + months(1) - days(1))) |
          (recurrence == "Weekly" & between(date, month_start, month_start + months(1) - days(1)))
      )
    recurring_reminders
  }
  
  # Render calendar with reminders using plotly
  output$reminder_calendar <- renderPlotly({
    user_id <- user_session()$user_id
    month_start <- floor_date(selected_month(), "month")
    month_days <- days_in_month(month_start)
    
    # Fetch reminders including recurring ones
    reminders <- get_monthly_reminders(user_id, month_start)
    
    # Create calendar data for the selected month
    calendar_data <- data.frame(
      Day = 1:month_days,
      Reminder = ifelse(1:month_days %in% reminders$day, reminders$name[match(1:month_days, reminders$day)], "")
    )
    
    # Plotly calendar view
    plot_ly(
      type = "table",
      header = list(values = list("Day", "Reminder"), align = c("center", "center"), fill = list(color = "lightgray")),
      cells = list(
        values = rbind(calendar_data$Day, calendar_data$Reminder),
        align = c("center", "left"),
        height = 30,
        fill = list(color = c("white", "whitesmoke"))
      )
    ) %>%
      layout(title = paste("Bill Reminders for", format(month_start, "%B %Y")))
  })
  
  
  # Server Logic for Setting a Bill Reminder with Recurrence and Notification
  observeEvent(input$set_reminder_button, {
    user_id <- user_session()$user_id
    bill_date <- input$bill_date_input
    bill_name <- input$bill_name_input
    amount <- input$bill_amount_input
    recurrence <- input$recurrence_input
    notify_before <- input$notification_days_input
    
    # Insert bill reminder with recurrence and notification days
    query <- sprintf(
      "INSERT INTO bill_reminders_user_%d (user_id, date, name, amount, recurrence, notification_days, status) 
   VALUES (%d, '%s', '%s', %.2f, '%s', %d, 'Unpaid')",
      user_id, user_id, bill_date, bill_name, amount, recurrence, notify_before
    )
    
    dbExecute(con, query)
    
    output$bill_reminder_status <- renderText("Bill reminder set successfully with recurrence and notifications.")
  })
  
  
  
  # Mark Reminder as Paid
  observeEvent(input$paid, {
    button_id <- str_extract(names(input)[input == 1], "\\d+$")
    if (!is.na(button_id)) {
      dbExecute(con, sprintf("UPDATE bill_reminders_user_%d SET status = 'Paid' WHERE id = %s", user_id, button_id))
      showNotification("Bill marked as paid.", type = "message")
    }
  })
  
  
  
  
  
  
  # Function to generate expense report (user-specific)
  get_user_expense_report <- function(user_id) {
    query <- sprintf("SELECT * FROM transactions_user_%d", user_id)
    result <- dbGetQuery(con, query)
    return(result)
  }
  
  # Function to erase data (user-specific)
  erase_user_data <- function(user_id, options) {
    tryCatch({
      if ("Erase All" %in% options) {
        dbSendQuery(con, sprintf("DELETE FROM transactions_user_%d", user_id))
        dbSendQuery(con, sprintf("DELETE FROM savings_goal_user_%d", user_id))
        dbSendQuery(con, sprintf("DELETE FROM bill_reminders_user_%d", user_id))
        dbSendQuery(con, sprintf("DELETE FROM usable_amount_user_%d", user_id))
      } else {
        if ("Erase Transaction" %in% options) {
          dbSendQuery(con, sprintf("DELETE FROM transactions_user_%d", user_id))
        }
        if ("Erase Saving Goal" %in% options) {
          dbSendQuery(con, sprintf("DELETE FROM savings_goal_user_%d", user_id))
        }
        if ("Erase Bill Reminder" %in% options) {
          dbSendQuery(con, sprintf("DELETE FROM bill_reminders_user_%d", user_id))
        }
      }
    }, error = function(e) {
      cat("Error erasing data:", e$message, "\n")
    })
  }
  
  # Render functions and additional event handlers
  
  output$total_expenses_output <- renderText({
    user_id <- user_session()$user_id
    total_expenses <- get_user_total_expenses(user_id)
    paste("Total Expenses: ₹", format(total_expenses, big.mark = ",", scientific = FALSE))
  })
  
  output$remaining_amount_output <- renderText({
    user_id <- user_session()$user_id
    remaining_amt <- get_user_usable_amount(user_id) - get_user_total_expenses(user_id)
    paste("Remaining Amount: ₹", format(remaining_amt, big.mark = ",", scientific = FALSE))
  })
  
  
  
  
  
  
  # Event handlers
  # Update or Insert Salary and Savings Goal
  observeEvent(input$set_goal_button, {
    user_id <- user_session()$user_id
    selected_month <- format(input$month_input, "%Y-%m")
    salary <- input$salary_input
    goal <- input$goal_input
    
    # Check if an entry already exists for the selected month
    existing_entry <- dbGetQuery(con, sprintf("SELECT * FROM savings_goal_user_%d WHERE month = '%s'", user_id, selected_month))
    
    if (nrow(existing_entry) > 0) {
      # Update existing entry
      query <- sprintf("UPDATE savings_goal_user_%d SET salary = %f, goal = %f WHERE month = '%s'", user_id, salary, goal, selected_month)
      dbExecute(con, query)
      output$goal_status <- renderText("Updated salary and savings goal for the selected month.")
    } else {
      # Insert new entry
      set_user_savings_goal(user_id, salary, goal, selected_month)
      output$goal_status <- renderText("Set salary and savings goal for the selected month.")
    }
  })
  
  
  # Fetch and display total salary, savings goal, expenses, and remaining amount for selected month
  observeEvent(input$expense_month_input, {
    user_id <- user_session()$user_id
    selected_month <- format(input$expense_month_input, "%Y-%m")
    
    # Fetch total salary and savings goal for the selected month
    goal_data <- dbGetQuery(con, sprintf("SELECT salary, goal FROM savings_goal_user_%d WHERE month = '%s'", user_id, selected_month))
    
    # Fetch total expenses for the selected month
    expense_data <- dbGetQuery(con, sprintf("SELECT IFNULL(SUM(amount), 0) AS total_expense FROM transactions_user_%d WHERE DATE_FORMAT(date, '%%Y-%%m') = '%s'", user_id, selected_month))
    total_expense <- ifelse(nrow(expense_data) > 0, expense_data$total_expense, 0)
    
    if (nrow(goal_data) > 0) {
      salary <- goal_data$salary[1]
      goal <- goal_data$goal[1]
      remaining_amount <- salary - goal - total_expense
      
      output$total_salary_output <- renderText(paste("Total Salary for Selected Month: ₹", format(salary, big.mark = ",")))
      output$saving_goal_output <- renderText(paste("Saving Goal for Selected Month: ₹", format(goal, big.mark = ",")))
      output$total_expense_output <- renderText(paste("Total Expenses for Selected Month: ₹", format(total_expense, big.mark = ",")))
      output$remaining_amount_output <- renderText(paste("Remaining Amount: ₹", format(remaining_amount, big.mark = ",")))
    } else {
      output$total_salary_output <- renderText("No salary and savings goal set for this month.")
      output$saving_goal_output <- renderText("")
      output$total_expense_output <- renderText(paste("Total Expenses for Selected Month: ₹", format(total_expense, big.mark = ",")))
      output$remaining_amount_output <- renderText("")
    }
  })
  
  
  observeEvent(input$add_transaction_button, {
    user_id <- user_session()$user_id
    
    if (is.null(user_id)) {
      output$transaction_status <- renderText("⚠️ Error: You must be logged in to add a transaction.")
      return()
    }
    
    date <- input$date_input
    category <- ifelse(input$category_input == "Other", input$custom_category_input, input$category_input)
    amount <- as.numeric(input$amount_input)
    payment_mode <- input$payment_mode_input
    
    print(paste("Debug - User ID:", user_id))  # ✅ log to console
    print(paste("Debug - Amount:", amount))    # ✅ log to console
    
    add_user_transaction(user_id, date, category, amount, payment_mode)
    output$transaction_status <- renderText("✅ Transaction added successfully.")
  })
  
  
  observeEvent(input$erase_transactions_button, {
    user_id <- user_session()$user_id
    options <- input$erase_options
    erase_user_data(user_id, options)
    output$erase_transactions_status <- renderText("Selected data has been erased successfully.")
  })
  
  # Total expenses output, now using user-specific function
  output$total_expenses_output <- renderText({
    user_id <- user_session()$user_id
    total_expenses <- get_user_total_expenses(user_id)
    paste("Total Expenses: ₹", format(total_expenses, big.mark = ",", scientific = FALSE))
  })
  
  # Remaining amount output, now using user-specific functions
  output$remaining_amount_output <- renderText({
    user_id <- user_session()$user_id
    remaining_amt <- get_user_usable_amount(user_id) - get_user_total_expenses(user_id)
    paste("Remaining Amount: ₹", format(remaining_amt, big.mark = ",", scientific = FALSE))
  })
  
  
  
  
  
  
  # Expense Report download for Excel
  output$download_expense_report <- downloadHandler(
    filename = function() {
      paste("expense_report", Sys.Date(), ".xlsx", sep = "")
    },
    content = function(file) {
      user_id <- user_session()$user_id
      result <- get_user_expense_report(user_id)
      write.xlsx(result, file, row.names = FALSE)
    }
  )
  
  output$download_pdf_report <- downloadHandler(
    filename = function() {
      selected_month_str <- format(input$report_month_input, "%Y-%m")
      paste0("expense_report_", selected_month_str, ".pdf")
    },
    
    content = function(file) {
      user_id <- user_session()$user_id
      username <- user_session()$username
      selected_month <- input$report_month_input
      
      selected_month_str <- format(selected_month, "%Y-%m")
      
      # Fetch data for the selected month
      salary_goal_query <- sprintf("SELECT salary, goal FROM savings_goal_user_%d WHERE month = '%s'", user_id, selected_month_str)
      goal_data <- dbGetQuery(con, salary_goal_query)
      
      transaction_query <- sprintf("SELECT * FROM transactions_user_%d WHERE DATE_FORMAT(date, '%%Y-%%m') = '%s'", user_id, selected_month_str)
      transactions <- dbGetQuery(con, transaction_query)
      
      total_expense <- sum(transactions$amount)
      salary <- ifelse(nrow(goal_data) > 0, goal_data$salary[1], 0)
      goal <- ifelse(nrow(goal_data) > 0, goal_data$goal[1], 0)
      remaining <- salary - goal - total_expense
      
      # Create visualizations
      category_plot <- tempfile(fileext = ".png")
      date_plot <- tempfile(fileext = ".png")
      payment_mode_plot <- tempfile(fileext = ".png")
      
      if (nrow(transactions) > 0) {
        # Category Pie Chart
        category_data <- transactions %>% group_by(category) %>% summarise(total = sum(amount))
        png(category_plot, width = 800, height = 600)
        pie(category_data$total, labels = category_data$category, main = "Spending by Category", col = rainbow(nrow(category_data)))
        dev.off()
        
        # Date-wise Bar Chart
        date_data <- transactions %>% group_by(date) %>% summarise(total = sum(amount))
        png(date_plot, width = 800, height = 600)
        barplot(date_data$total, names.arg = date_data$date, main = "Spending by Date", las = 2, col = "steelblue")
        dev.off()
        
        # Payment Mode Chart
        payment_data <- transactions %>% group_by(payment_mode) %>% summarise(total = sum(amount))
        png(payment_mode_plot, width = 800, height = 600)
        barplot(payment_data$total, names.arg = payment_data$payment_mode, main = "Spending by Payment Mode", las = 2, col = "darkgreen")
        dev.off()
      }
      
      # Use the enhanced Rmd
      tempReport <- file.path(tempdir(), "enhanced_expense_report.Rmd")
      file.copy("C:\\Users\\patel\\Documents\\enhanced_expense_report .Rmd", tempReport, overwrite = TRUE)
      
      
      rmarkdown::render(
        input = tempReport,
        output_file = file,
        params = list(
          username = username,
          month = selected_month_str,
          salary = salary,
          goal = goal,
          total_expense = total_expense,
          remaining = remaining,
          transactions = transactions,
          category_plot = category_plot,
          date_plot = date_plot,
          payment_mode_plot = payment_mode_plot
        ),
        envir = new.env(parent = globalenv())
      )
    }
  )
  
  
  
  # Function to fetch exchange rate with improved error handling
  get_exchange_rate <- function(target_currency) {
    api_key <- "5271156e99e0786a250e214f"  # Your provided API key
    url <- paste0("https://v6.exchangerate-api.com/v6/", api_key, "/latest/INR")
    response <- tryCatch(GET(url), error = function(e) {
      showNotification("Failed to connect to the exchange rate API.", type = "error")
      return(NULL)
    })
    
    if (!is.null(response) && status_code(response) == 200) {
      data <- content(response, "parsed")
      rate <- data$conversion_rates[[target_currency]]
      if (is.null(rate)) {
        showNotification("Currency conversion rate not available.", type = "error")
        return(1)  # Default rate to 1 if conversion fails
      }
      return(rate)
    } else {
      showNotification("Failed to fetch exchange rate. Please check your API key or try again later.", type = "error")
      return(1)
    }
  }
  
  # Reactive value to store the exchange rate for the selected currency
  exchange_rate <- reactiveVal(1)
  
  # Observe currency selection and fetch new exchange rate
  observeEvent(input$currency_select, {
    selected_currency <- input$currency_select
    rate <- get_exchange_rate(selected_currency)
    exchange_rate(rate)
  })
  
  # Monthly summary with currency conversion applied
  observeEvent(input$expense_month_input, {
    user_id <- user_session()$user_id
    selected_month <- format(input$expense_month_input, "%Y-%m")
    
    # Fetch total salary and savings goal for the selected month
    goal_data <- dbGetQuery(con, sprintf("SELECT salary, goal FROM savings_goal_user_%d WHERE month = '%s'", user_id, selected_month))
    
    # Fetch total expenses for the selected month
    expense_data <- dbGetQuery(con, sprintf("SELECT IFNULL(SUM(amount), 0) AS total_expense FROM transactions_user_%d WHERE DATE_FORMAT(date, '%%Y-%%m') = '%s'", user_id, selected_month))
    total_expense <- ifelse(nrow(expense_data) > 0, expense_data$total_expense, 0)
    
    # Apply currency conversion
    conversion_rate <- exchange_rate()
    
    if (nrow(goal_data) > 0) {
      # Convert all amounts to selected currency
      salary_converted <- goal_data$salary[1] * conversion_rate
      goal_converted <- goal_data$goal[1] * conversion_rate
      total_expense_converted <- total_expense * conversion_rate
      remaining_amount_converted <- salary_converted - goal_converted - total_expense_converted
      
      # Render text outputs with converted values
      output$total_salary_output <- renderText(paste("Total Salary for Selected Month:", format(salary_converted, big.mark = ","), input$currency_select))
      output$saving_goal_output <- renderText(paste("Saving Goal for Selected Month:", format(goal_converted, big.mark = ","), input$currency_select))
      output$total_expense_output <- renderText(paste("Total Expenses for Selected Month:", format(total_expense_converted, big.mark = ","), input$currency_select))
      output$remaining_amount_output <- renderText(paste("Remaining Amount:", format(remaining_amount_converted, big.mark = ","), input$currency_select))
    } else {
      # If no salary and savings goal set for the month
      output$total_salary_output <- renderText("No salary and savings goal set for this month.")
      output$saving_goal_output <- renderText("")
      output$total_expense_output <- renderText(paste("Total Expenses for Selected Month:", format(total_expense * conversion_rate, big.mark = ","), input$currency_select))
      output$remaining_amount_output <- renderText("")
    }
  })
  
  # Update exchange rate at session start to INR as default
  exchange_rate(get_exchange_rate("INR"))
  
  
  
  onStop(function() {
    dbDisconnect(con)
  })
}

# Run the application
shinyApp(ui = ui, server = server)
