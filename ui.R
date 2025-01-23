ui <- navbarPage(
  title = "MarktDash",
  theme = bslib::bs_theme(bootswatch = "flatly"), 
  tags$head(
    tags$style(HTML("
      table.dataTable {
        font-size: 14px;
      }
      table.dataTable thead th {
        font-size: 14px;
      }
    "))
  ),
  # HOME PAGE-----------------------------------
  tabPanel(
    "Home",
    fluidRow(
      column(
        width = 3,
        wellPanel(
          style = "background-color: #2C3E50; color: #EEEEEE; border: 1px solid #cfe0c9;",
          h4("Total Revenue"),
          textOutput("totalRevenue")
        )
      ),
      column(
        width = 3,
        wellPanel(
          style = "background-color: #2C3E50; color: #EEEEEE; border: 1px solid #cfe0c9;",
          h4("Total Customers"),
          textOutput("totalCustomers")
        )
      ),
      column(
        width = 3,
        wellPanel(
          style = "background-color: #2C3E50; color: #EEEEEE; border: 1px solid #cfe0c9;",
          h4("Total Transactions"),
          textOutput("totalTransactions")
        )
      ),
      column(
        width = 3,
        wellPanel(
          style = "background-color: #2C3E50; color: #EEEEEE; border: 1px solid #cfe0c9;",
          h4("Average Product Rating"),
          textOutput("averageRating")
        )
      )
    ),
    fluidRow(
      style = "margin-top: 25px;",
      column(
        width = 6,
        card(
          card_header(
            style = "background-color: #2C3E50; color: #EEEEEE;",
            h5("Revenue by Category")
          ),
          card_body(
            plotlyOutput("categoryRevenuePlot", height = "300px")
          ),
          dateRangeInput(
            "dateRange",
            label = "Date Interval",
            start = "2024-01-01",
            end = "2024-03-01",
            format = "yyyy-mm-dd"
          )
        )
      ),
      column(
        width = 6,
        card(
          card_header(
            style = "background-color: #2C3E50; color: #EEEEEE;",
            h5("Daily Revenue")
          ),
          card_body(
            plotlyOutput("revenuePlot", height = "300px")
          ),
          dateRangeInput(
            "dateRange",
            label = "Date Interval",
            start = "2024-01-01",
            end = "2024-03-01",
            format = "yyyy-mm-dd"
          )
        )
      )
    ),
    fluidRow(
      style = "margin-top: 25px;",
      column(
        width = 6,
        card(
          height = 600,
          card_header(
            style = "background-color: #2C3E50; color: #EEEEEE;",
            h5("Top Products")
          ),
          card_body(
            dataTableOutput("summaryTopProducts", height = "350px")
          )
        )
      ),
      column(
        width = 6,
        card(
          card_header(
            style = "background-color: #2C3E50; color: #EEEEEE;",
            h5("Billing Addresses")
          ),
          card_body(
            leafletOutput("customerMap", height = "550px")
          )
        )
      )
    )
  ),
  
  # PRODUCT PAGE-----------------------------------
  navbarMenu(
    "Product",
    # Product Insights
    tabPanel(
      "Product Insights",
      # Products with Low Stock and Close Expiry
      fluidRow(
        style = "margin-top: 25px;",
        column(
          width = 8,
          card(
            height = 600,
            card_header(
              style = "background-color: #2C3E50; color: #EEEEEE;",
              h4("Products with Low Stock and Close Expiry")
            ),
            card_body(
              plotlyOutput("lowStockBubbleChart", height = "425px")
            ),
            card_footer(
              numericInput("stock_number", "Stocks Left", value = 15, min = 11)
            )
          )
        ),
        column(
          width = 4,
          card(
            height = 600,
            card_header(
              style = "background-color: #2C3E50; color: #EEEEEE;",
              h4("Rating vs. Sale Price")
            ),
            card_body(
              plotlyOutput("ratingSalePriceplot", height = "425px")
            ),
            card_footer(
              sliderInput("rating", "Maximum Rating:", min = 1, max = 5, value = 3, step = 0.5)
            )
          )
        )
      ),
      # All Products
      fluidRow(
        style = "margin-top: 25px;",
        column(
          width = 12,
          card(
            height = 500,
            card_header(
              style = "background-color: #2C3E50; color: #EEEEEE;",
              h4("Products")
            ),
            card_body(
              dataTableOutput("allProducts")
            )
          )
        )
      ),
      sidebarLayout(
        sidebarPanel(
          column(
            width = 12,
            height = 600,
            h4("Filters"),
            selectInput("category", "Product Category", 
                        choices = c("All", dbGetQuery(connect2DB, "SELECT DISTINCT Category FROM Products")$Category)
            ),
            selectInput("top_n", "Number of Top Products", choices = c(10, 25, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000),selected = 10
            ),
            sliderInput("rating", "Maximum Rating:", min = 1, max = 5, value = 3, step = 0.5)
          )
        ),
        mainPanel(
          column(
            width = 12,
            card(
              height = 600,
              card_header(
                style = "background-color: #2C3E50; color: #EEEEEE;",
                h4("Top Products")
              ),
              card_body(
                dataTableOutput("productsTable", height = "350px")
              )
            )
          )
        )
      )
    ),
    # Add Product
    tabPanel(
      "Add Product",
      card(
        card_header(
          style = "background-color: #2C3E50; color: #EEEEEE;",
          h4("Add Product")
        ),
        card_body(
          style = "background-color: #F5F5F5;",
          fluidRow(
            title = "Add Product",
            column(
              width = 6,
              textInput("product_name", "Product Name"),
              selectInput("subcategory", "Category", choices = NULL), 
              textInput("brand", "Brand"), 
              numericInput("sale_price", "Sale Price", value = 0, min = 0)
            ),
            column(
              width = 6,
              numericInput("market_price", "Market Price", value = 0, min = 0),
              selectInput("type", "Type", choices = NULL),
              selectInput("supplier", "Supplier", choices = NULL), 
              dateInput("expiry_date", "Expiry Date"),
              numericInput("stock_number", "Stock Number", value = 0, min = 0)
            )
          ),
          fluidRow(
            column(
              width = 12, 
              actionButton("add_product", "Add Product", style = "background-color: #20C997; color: white;")
            )
          )
        )
      )
    )
  ),

  # INCOME INSIGHTS PAGE------------------------
  tabPanel(
    "Income Insights",
    fluidRow(
      style = "margin-top: 25px;",
      column(
        width = 6,
        card(
          height = 550,
          card_header(
            style = "background-color: #2C3E50; color: #EEEEEE;",
            h4("Revenue by Category")
          ),
          card_body(
            plotlyOutput("categoryRevenuePlot_Income", height = "350px")
          ),
          dateRangeInput(
            "dateRange",
            label = "Date Interval",
            start = "2024-01-01",
            end = "2024-03-01",
            format = "yyyy-mm-dd"
          )
        )
      ),
      column(
        width = 6,
        card(
          height = 550,
          card_header(
            style = "background-color: #2C3E50; color: #EEEEEE;",
            h4("Daily Revenue")
          ),
          card_body(
            plotlyOutput("revenuePlot_Income", height = "350px")
          ),
          dateRangeInput(
            "dateRange",
            label = "Date Interval",
            start = "2024-01-01",
            end = "2024-03-01",
            format = "yyyy-mm-dd"
          )
        )
      )
    )
  ),
  
  # CUSTOMER INSIGHTS PAGE----------------------
  # Customer Insights
  tabPanel(
    "Customer",
    fluidRow(
      style = "margin-top: 25px;",
      column(
        width = 8,
        card(
          card_header(
            style = "background-color: #F1F1F1; color: #2C3E50;",
            h4("Top Purchasing Customers"),
            card_footer(
              numericInput("spent", "Purchasing Threshold", value = 0, min = 0)
            )
          ),
          card_body(
            height = 550,
            dataTableOutput("topPurchasingCustomers")
          )
        )
      ),
      column(
        width = 4,
        card(
          card_header(
            style = "background-color: #2C3E50; color: #EEEEEE;",
            h4("Billing Addresses")
          ),
          card_body(
            height = 630,
            leafletOutput("customerMap_Customer")
          )
        )
      )
    )
  ),
  
  # SUPPLIERS PAGE------------------------------
  tabPanel(
    "Suppliers",
    fluidRow(
      style = "margin-top: 25px;",
      column(
        width = 4,
        card(
          card_header(
            style = "background-color: #2C3E50; color: #EEEEEE;",
            h4("Product Count By Suppliers")
          ),
          card_body(
            height = 500,
            plotlyOutput("suppliersProductHistogram")
          )
        )
      ),
      column(
        width = 8,
        card(
          card_header(
            style = "background-color: #2C3E50; color: #EEEEEE;",
            h4("Suppliers")
          ),
          card_body(
            height = 500,
            dataTableOutput("allSuppliers")
          )
        )
      )
    )
  ),
  
  # TOOLS PAGE----------------------------------
  tabPanel(
    "Tools",
    fluidRow(
      column(
        width = 12,
        card(
          card_header(
            style = "background-color: #2C3E50; color: #EEEEEE;",
            h4("Sales Forecast")
          ),
          card_body(
            plotlyOutput("salesForecastPlot")
          )
        )
      )
    ),
    fluidRow(
      sidebarLayout(
        sidebarPanel(
          h4("Filters"),
          sliderInput("discount_7Day", "Discount for 7 days to expiry:", min = 0, max = 100, value = 25, step = 0.5),
          sliderInput("discount_5Day", "Discount for 5 days to expiry:", min = 0, max = 100, value = 40, step = 0.5),
          sliderInput("discount_3Day", "Discount for 3 days to expiry:", min = 0, max = 100, value = 65, step = 0.5),
          actionButton(
            inputId = "applyDiscounts",
            label = "Apply Discounts",
            style = "background-color: #20C997; color: white; bottom-margin: 25px;"
          )
        ),
        mainPanel(
          column(
            width = 12,
            h4("Apply Discounts on Close Expiry Date"),
            dataTableOutput("showProducts"),
            dataTableOutput("discountedProductsTable"),
          )
        )
      )
    )
  )
)