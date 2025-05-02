# 💰 Personal Finance Tracker (R + Shiny + MySQL)

A comprehensive personal finance tracking application built using R and Shiny with a MySQL backend. It enables users to manage expenses, set financial goals, forecast future spending, and receive bill reminders — all through a clean, responsive dashboard.

---

## 📸 Screenshots

<table>
  <tr>
    <td align="center">
      <img src="https://github.com/MohmadZaidDelawala/PersonalFinanceTracker-R/blob/main/screenshot/Screenshot%202025-04-07%20160506.png?raw=true" width="400"/><br/>
      <sub><b>🖥️ Registration Page</b></sub>
    </td>
    <td align="center">
      <img src="https://github.com/MohmadZaidDelawala/PersonalFinanceTracker-R/blob/main/screenshot/Screenshot%202025-04-07%20160522.png?raw=true" width="400"/><br/>
      <sub><b>🔐 Login Page</b></sub>
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="https://github.com/MohmadZaidDelawala/PersonalFinanceTracker-R/blob/main/screenshot/Screenshot%202025-04-07%20160637.png?raw=true" width="400"/><br/>
      <sub><b>📊 Forecast Visualization</b></sub>
    </td>
    <td align="center">
      <img src="https://github.com/MohmadZaidDelawala/PersonalFinanceTracker-R/blob/main/screenshot/Screenshot%202025-04-07%20160738.png?raw=true" width="400"/><br/>
      <sub><b>📁 Spending Reports</b></sub>
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="https://github.com/MohmadZaidDelawala/PersonalFinanceTracker-R/blob/main/screenshot/Screenshot%202025-04-07%20161522.png?raw=true" width="400"/><br/>
      <sub><b>💸 Set Bill Reminders</b></sub>
    </td>
    <td align="center">
      <img src="https://github.com/MohmadZaidDelawala/PersonalFinanceTracker-R/blob/main/screenshot/Screenshot%202025-04-07%20161546.png?raw=true" width="400"/><br/>
      <sub><b>📁 View Bill Reminder Table</b></sub>
    </td>
  </tr>
</table>

---


## 🛠 Technologies Used

| Area        | Tools/Libraries                     |
|-------------|--------------------------------------|
| UI          | Shiny, shinydashboard, Plotly        |
| Backend     | RMySQL, dplyr, sodium                |
| Forecasting | Prophet, lubridate                   |
| Reporting   | rmarkdown, openxlsx, knitr           |
| Alerts      | blastula (email reminders)           |
| Styling     | shinythemes, custom CSS              |

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

---
## 👤 Author

**Mohmadzaid Delawala**  
📧 Email: patelzaid987@gmail.com  
🔗 [LinkedIn](https://www.linkedin.com/in/mohmadzaid-delawala-a12763222/)  
🖥️ [GitHub](https://github.com/MohmadZaidDelawala)

