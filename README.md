# 💰 Personal Finance Tracker (R + Shiny + MySQL)

A comprehensive personal finance tracking application built using R and Shiny with a MySQL backend. It enables users to manage expenses, set financial goals, forecast future spending, and receive bill reminders — all through a clean, responsive dashboard.

---

## 📸 Screenshots

_Add screenshots here (e.g. dashboard UI, spending chart, bill reminders table)_

---

## 🔧 Technologies Used

- **Frontend**: Shiny, shinydashboard, shinydashboardPlus, shinythemes, Plotly, shinyjs
- **Backend**: R, MySQL, RMySQL
- **Data Handling**: dplyr, openxlsx, lubridate, jsonlite, sodium
- **Forecasting**: Prophet
- **Email Notifications**: blastula
- **Reporting**: rmarkdown, knitr, tinytex
- **API**: Exchange Rate API integration

---

## 🎯 Key Features

- 👤 User registration/login with hashed passwords
- 💸 Add and categorize transactions
- 🎯 Set monthly salary and savings goals
- 📊 Visualize expenses by category, date, or payment mode
- 📅 Set and receive email reminders for upcoming bills
- 🔮 30-day expense forecasting with Prophet
- 📁 Download monthly expense summaries in Excel or PDF
- 🌐 Currency selection with real-time exchange rate conversion

---

## 🛠 Setup Instructions

### Prerequisites

- R 4.x
- RStudio
- MySQL Server
- Git
- Shiny packages (see `libraries.R` or below)

### Required R Libraries

```r
install.packages(c(
  "shiny", "shinydashboard", "shinydashboardPlus", "plotly",
  "RMySQL", "dplyr", "openxlsx", "shinythemes", "rmarkdown",
  "knitr", "httr", "jsonlite", "sodium", "lubridate",
  "prophet", "ggplot2", "tinytex", "shinyjs", "blastula"
))
