server <- function(input, output, session) {
  # HOME PAGE-----------------------------------
  # Total Revenue
  output$totalRevenue <- renderText({
    query <- "SELECT SUM(TotalAmount) AS TotalRevenue FROM Transactions;"
    data <- dbGetQuery(connect2DB, query)
    paste0("$", format(round(data$TotalRevenue, 2), big.mark = ","))
  })
  
  # Total Customers
  output$totalCustomers <- renderText({
    query <- "SELECT COUNT(*) AS TotalCustomers FROM Customers;"
    data <- dbGetQuery(connect2DB, query)
    data$TotalCustomers
  })
  
  # Total Transactions
  output$totalTransactions <- renderText({
    query <- "SELECT COUNT(*) AS TotalTransactions FROM Transactions;"
    data <- dbGetQuery(connect2DB, query)
    data$TotalTransactions
  })
  
  # Average Product Rating
  output$averageRating <- renderText({
    query <- "SELECT AVG(Rating) AS AverageRating FROM Products;"
    data <- dbGetQuery(connect2DB, query)
    round(data$AverageRating, 2)
  })
  
  # Revenue by Category Plot
  output$categoryRevenuePlot <- renderPlotly({
    query <- sprintf("
      SELECT p.Category, SUM(td.Quantity * td.UnitPrice) AS TotalRevenue
      FROM Products p
      JOIN TransactionDetails td ON p.ProductCode = td.ProductCode
      JOIN Transactions t ON td.TransactionID = t.TransactionID
      WHERE DATE(t.TransactionDate) BETWEEN '%s' AND '%s'
      GROUP BY p.Category;",
              input$dateRange[1],
              input$dateRange[2]
    )
    
    data <- dbGetQuery(connect2DB, query)
    
    palette <- brewer.pal(n = min(11, nrow(data)), name = "Set3")
    data$CategoryColor <- palette[as.numeric(factor(data$Category))]
    
    plot <- ggplot(data, aes(x = reorder(Category, TotalRevenue), y = TotalRevenue, fill = Category)) +
            geom_bar(stat = "identity") +
            scale_fill_manual(values = palette) +
            coord_flip() +
            labs(x = "Category", y = "Total Revenue", fill = "Category") +
            theme_minimal()
    
    ggplotly(plot)
  })
  
  # Daily Revenue Plot
  output$revenuePlot <- renderPlotly({
    query <- sprintf("
      SELECT DATE(TransactionDate) AS Day, SUM(TotalAmount) AS TotalRevenue
      FROM Transactions
      WHERE DATE(TransactionDate) BETWEEN '%s' AND '%s'
      GROUP BY DATE(TransactionDate)
      ORDER BY DATE(TransactionDate);",
                     input$dateRange[1],
                     input$dateRange[2]  
    )
    
    data <- dbGetQuery(connect2DB, query)
    
    # Object for revenue plot
    revenue_plot <- ggplot(data, aes(x = as.Date(Day), y = TotalRevenue)) +
                    geom_line(color = "darkgreen") +
                    labs(x = "Date", y = "Total Revenue") +
                    theme_minimal() +
                    theme(axis.text.x = element_text(angle = 45, hjust = 1))
    
    ggplotly(revenue_plot)
  })
  
  # Top Products Table
  output$summaryTopProducts <- renderDataTable({
    query <- "
      SELECT p.ProductCode, substr(ProductName, 1, 20) AS ProductName, SUM(td.Quantity) AS TotalSold
      FROM Products p
      JOIN TransactionDetails td ON p.ProductCode = td.ProductCode
      GROUP BY p.ProductCode
      ORDER BY TotalSold DESC"
    
    dbGetQuery(connect2DB, query)
  })
  
  # Billing Addresses
  # BILLING ADDRESSES MAP
  output$customerMap <- renderLeaflet({
    query <- "
    SELECT c.CustomerID, c.Latitude, c.Longitude, SUM(t.TotalAmount) AS TotalSpent 
    FROM Customers c
    JOIN Transactions t ON c.CustomerID = t.CustomerID
    WHERE Latitude IS NOT NULL AND Longitude IS NOT NULL
    GROUP BY c.CustomerID, c.Latitude, c.Longitude
    "
    customer_locations <- dbGetQuery(connect2DB, query)
    
    customer_locations$Latitude <- as.numeric(customer_locations$Latitude)
    customer_locations$Longitude <- as.numeric(customer_locations$Longitude)
    customer_locations$TotalSpent <- as.numeric(customer_locations$TotalSpent)
    
    max_radius <- 30
    min_radius <- 8
    
    customer_locations$ScaledRadius <- scales::rescale(
      customer_locations$TotalSpent, to = c(min_radius, max_radius)
    )
    
    color_palette <- colorNumeric(
      palette = viridisLite::viridis(9),
      domain = customer_locations$TotalSpent
    )
    
    # Leaflet map
    leaflet(customer_locations) %>%
      addTiles() %>%
      addCircleMarkers(
        ~Longitude, ~Latitude,
        label = ~paste("Customer ID:", CustomerID, "Total Spent:", TotalSpent),
        radius = ~ScaledRadius,
        color = ~color_palette(TotalSpent),
        fillColor = ~color_palette(TotalSpent),
        fillOpacity = 0.6
      ) %>%
      addLegend(
        "bottomright",
        pal = color_palette,
        values = ~TotalSpent,
        title = "Total Spent",
        labFormat = labelFormat(prefix = "$")
      ) %>%
      setView(lng = -105.9378, lat = 35.6870, zoom = 13) # Ensure %>% is here
  })
  
  # PRODUCT PAGE--------------------------------
  # TOP SOLD AND RATE/CATEGORY FILTERED PRODUCTS DATATABLE
  output$productsTable <- renderDataTable({
    req(input$category, input$top_n, input$rating)
    
    # Product information table
    query <- sprintf("
    SELECT
      p.ProductCode,
      substr(p.ProductName, 1, 20) AS ProductName, 
      SUM(td.Quantity) AS TotalSold, 
      p.Rating,
      p.Category
    FROM Products p
    JOIN TransactionDetails td ON p.ProductCode = td.ProductCode
    WHERE 
      ('%s' = 'All' OR p.Category = '%s') AND 
      p.Rating <= %f
    GROUP BY p.ProductCode
    ORDER BY TotalSold DESC
    LIMIT %d;", input$category, input$category, input$rating, as.numeric(input$top_n))
    
    dbGetQuery(connect2DB, query)
  })
  
  # BUBBLE CHART FOR LOW STOCKS AND CLOSE EXPIRY DATE
  output$lowStockBubbleChart <- renderPlotly({
    query <- sprintf(
      "SELECT 
        p.ProductCode,
        p.ProductName,
        p.StockNumber, 
        p.ExpiryDate
      FROM Products p
      WHERE p.StockNumber < %s;", input$stock_number
    )
    
    low_stock_data <- dbGetQuery(connect2DB, query)
    
    updateNumericInput(session, "stock_number")
    
    # Assigning proper types 
    low_stock_data <- low_stock_data %>%
      mutate(
        ProductCode = as.character(ProductCode),
        StockNumber = as.numeric(StockNumber),
        ExpiryDate = as.character.Date(ExpiryDate)
      )
    
    # Bubble chart
    bubble_chart <- ggplot(low_stock_data, aes(
      x = ExpiryDate,             
      y = StockNumber,              
      size = StockNumber,           
      color = ExpiryDate,            
      label = ProductCode, 
      productName = ProductName)) +
      geom_point(alpha = 0.7) +
      labs(x = "Expiry Date", y = "Stock Number", size = "Stock Number", color = "Expiry Date") +
      theme_minimal() +
      theme(axis.text.x = element_blank(), # Ticks were much crowded
            axis.ticks.x = element_blank())
    
    ggplotly(bubble_chart, tooltip = c("x", "y", "label", "productName"))
  })
  
  # Products DataTable
  output$allProducts <- renderDataTable({
    query <- "SELECT * FROM Products;"
    dbGetQuery(connect2DB, query)
  })
  
  # Rating vs SalePrice Scatter Plot
  output$ratingSalePriceplot <- renderPlotly({
    query <- sprintf("SELECT Rating, SalePrice FROM Products
      WHERE Rating IS NOT NULL AND Rating <= %f
                     LIMIT 5000;", input$rating
    ) 
    data <- dbGetQuery(connect2DB, query)
    
    plot <- ggplot(data, aes(x = Rating, y = SalePrice, color = SalePrice)) +
      geom_point(size = 3, alpha = 0.7) +
      scale_color_gradient(low = "#FFB347", high = "#2C3E50")+
      labs(
        x = "Rating",
        y = "Sale Price",
        color = "Sale Price"
      ) +
      theme_minimal()
    
    ggplotly(plot)
  })
  
  # ADD PRODUCT TO DATABASE
  subcategory_choices <- dbGetQuery(connect2DB, "SELECT DISTINCT SubCategory FROM products ORDER BY SubCategory")$SubCategory
  type_choices <- dbGetQuery(connect2DB, "SELECT DISTINCT Type FROM products ORDER BY Type")$Type
  supplier_choices <- dbGetQuery(connect2DB, "SELECT DISTINCT Supplier FROM products ORDER BY Supplier")$Supplier
  
  updateSelectInput(session, "subcategory", choices = subcategory_choices)
  updateSelectInput(session, "type", choices = type_choices)
  updateSelectInput(session, "supplier", choices = supplier_choices)
  
  
  observeEvent(input$add_product, {
    last_code_query <- "SELECT MAX(ProductCode) AS LastProductCode FROM products"
    last_code_result <- dbGetQuery(connect2DB, last_code_query)
    last_product_code <- as.numeric(last_code_result$LastProductCode) + 1
    
    query <- sprintf(
      "INSERT INTO products (ProductCode, ProductName, SubCategory, Brand, SalePrice, MarketPrice, Type, Supplier, ExpiryDate, StockNumber) 
      VALUES ('%s', '%s', '%s', '%s', %s, %s, '%s', '%s', '%s', %s)",
      last_product_code,
      input$product_name,
      input$subcategory,
      input$brand,
      input$sale_price,
      input$market_price,
      input$type,
      input$supplier,
      as.character(input$expiry_date),
      input$stock_number
    )
    
    dbExecute(connect2DB, query)
    
    showNotification(sprintf("Product %s added successfully.", last_product_code), type = "message")
  })
  
  # INCOME INSIGHTS PAGE------------------------
  # REVENUE BY CATEGORY PLOT
  output$categoryRevenuePlot_Income <- renderPlotly({
    query <- sprintf("
      SELECT p.Category, SUM(td.Quantity * td.UnitPrice) AS TotalRevenue
      FROM Products p
      JOIN TransactionDetails td ON p.ProductCode = td.ProductCode
      JOIN Transactions t ON td.TransactionID = t.TransactionID
      WHERE DATE(t.TransactionDate) BETWEEN '%s' AND '%s'
      GROUP BY p.Category;",
                     input$dateRange[1],
                     input$dateRange[2],
                     input$category
    )
    
    data <- dbGetQuery(connect2DB, query)
    
    palette <- brewer.pal(n = min(11, nrow(data)), name = "Set3")
    data$CategoryColor <- palette[as.numeric(factor(data$Category))]
    
    plot <- ggplot(data, aes(x = reorder(Category, TotalRevenue), y = TotalRevenue, fill = Category)) +
      geom_bar(stat = "identity") +
      scale_fill_manual(values = palette) +
      coord_flip() +
      labs(x = "Category", y = "Total Revenue", fill = "Category") +
      theme_minimal()
    
    ggplotly(plot)
  })
  
  # DAILY REVENUE PLOT
  output$revenuePlot_Income <- renderPlotly({
    query <- sprintf("
      SELECT DATE(TransactionDate) AS Day, SUM(TotalAmount) AS TotalRevenue
      FROM Transactions
      WHERE DATE(TransactionDate) BETWEEN '%s' AND '%s'
      GROUP BY DATE(TransactionDate)
      ORDER BY DATE(TransactionDate);",
                     input$dateRange[1],
                     input$dateRange[2]  
    )
    
    data <- dbGetQuery(connect2DB, query)
    
    # Object for revenue plot
    revenue_plot <- ggplot(data, aes(x = as.Date(Day), y = TotalRevenue)) +
      geom_line(color = "darkgreen") +
      labs(x = "Date", y = "Total Revenue") +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
    
    ggplotly(revenue_plot)
  })
  
  # CUSTOMER INSIGHTS PAGE----------------------
  # TOP PURCHASING CUSTOMERS
  output$topPurchasingCustomers<- renderDataTable({
    query <- sprintf("
      SELECT c.CustomerID, c.CustomerName, c.CustomerEmail, c.CustomerPhone, SUM(t.TotalAmount) AS TotalSpent
      FROM Customers c
      JOIN Transactions t ON c.CustomerID = t.CustomerID
      GROUP BY c.CustomerID
      HAVING TotalSpent > %s
      ORDER BY TotalSpent DESC;",
                     input$spent
    )
    
    data <- dbGetQuery(connect2DB, query)
  })
  
  # BILLING ADDRESSES MAP
  output$customerMap_Customer <- renderLeaflet({
    query <- "
    SELECT c.CustomerID, c.Latitude, c.Longitude, SUM(t.TotalAmount) AS TotalSpent 
    FROM Customers c
    JOIN Transactions t ON c.CustomerID = t.CustomerID
    WHERE Latitude IS NOT NULL AND Longitude IS NOT NULL
    GROUP BY c.CustomerID, c.Latitude, c.Longitude
    "
    customer_locations <- dbGetQuery(connect2DB, query)
    
    customer_locations$Latitude <- as.numeric(customer_locations$Latitude)
    customer_locations$Longitude <- as.numeric(customer_locations$Longitude)
    customer_locations$TotalSpent <- as.numeric(customer_locations$TotalSpent)
    
    max_radius <- 30
    min_radius <- 8
    
    customer_locations$ScaledRadius <- scales::rescale(
      customer_locations$TotalSpent, to = c(min_radius, max_radius)
    )
    
    color_palette <- colorNumeric(
      palette = viridisLite::viridis(9),
      domain = customer_locations$TotalSpent
    )
    
    # Leaflet map
    leaflet(customer_locations) %>%
      addTiles() %>%
      addCircleMarkers(
        ~Longitude, ~Latitude,
        label = ~paste("Customer ID:", CustomerID, "Total Spent:", TotalSpent),
        radius = ~ScaledRadius,
        color = ~color_palette(TotalSpent),
        fillColor = ~color_palette(TotalSpent),
        fillOpacity = 0.6
      ) %>%
      addLegend(
        "bottomright",
        pal = color_palette,
        values = ~TotalSpent,
        title = "Total Spent",
        labFormat = labelFormat(prefix = "$")
      ) %>%
      setView(lng = -105.9378, lat = 35.6870, zoom = 13) # Ensure %>% is here
  })
  

  
  # SUPPLIERS PAGE------------------------------
  output$suppliersProductHistogram <- renderPlotly({
    query <- "
      SELECT s.SupplierName, COUNT(p.ProductCode) AS ProductCount
      FROM Suppliers s
      JOIN Products p ON s.SupplierCode = p.Supplier
      GROUP BY s.SupplierName
      ORDER BY ProductCount DESC;
    "
    
    data <- dbGetQuery(connect2DB, query)
    
    plot <- ggplot(data, aes(x = SupplierName, y = ProductCount, fill = ProductCount, label = ProductCount)) +
      geom_bar(stat = "identity") +
      scale_fill_viridis_c(option = "viridis", direction = 1) +
      labs(x = "Supplier", y = "Product Count", title = "Product Count by Supplier", fill = "Product Count") +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
    
    ggplotly(plot)
  })
  
  # Suppliers DataTable
  output$allSuppliers <- renderDataTable({
    query <- "SELECT * FROM Suppliers;"
    dbGetQuery(connect2DB, query)
  })
  
  # TOOLS PAGE----------------------------------
  # FORECAST OF SALES
  output$salesForecastPlot <- renderPlotly({
    query <- "
      SELECT DATE(TransactionDate) AS TransactionDate, SUM(TotalAmount) AS TotalSales
      FROM Transactions
      GROUP BY DATE(TransactionDate)" 
     
    daily_sales <- dbGetQuery(connect2DB, query)
    
    # Prophet requires columns "ds" (dates) and "y" (values to forecast)
    colnames(daily_sales) <- c("ds", "y") 
    daily_sales$ds <- as.Date(daily_sales$ds) 
    
    # Training Prophet Model
    model <- prophet(
      yearly.seasonality = TRUE,
      weekly.seasonality = TRUE, 
      daily.seasonality = FALSE
    )
    
    model <- add_seasonality(model, name = 'monthly', period = 30, fourier.order = 5)
    model <- fit.prophet(model, daily_sales)
    
    # Forecast for the Next Year
    future <- make_future_dataframe(model, periods = 365)  # Create future dates for 1 year
    forecast <- predict(model, future)  # Generate forecast
    
    # Actual and Forecast is merged
    daily_sales$Type <- "Actual"
    forecast_data <- forecast[, c("ds", "yhat")]
    colnames(forecast_data) <- c("ds", "y")
    forecast_data$Type <- "Forecast"
    combined_data <- rbind(daily_sales[, c("ds", "y", "Type")], forecast_data[, c("ds", "y", "Type")])
    
    palette <- brewer.pal(n = 3, name = "Dark2")
    
    # Plot of Actual and Forecast Sales
    plot <- plot_ly(combined_data, x = ~ds, y = ~y, color = ~Type, colors = palette) %>%
      add_lines() %>%
      layout(
        title = "Daily Sales Forecast for 2025",
        xaxis = list(title = "Date", showgrid = TRUE, gridcolor = "#A9A9A9"),
        yaxis = list(title = "Total Sales", showgrid = TRUE, gridcolor = "#A9A9A9"),
        legend = list(orientation = "h")
      )
  })
  
  
  # Update Discounts of Products with Close Expiry Dates
  show_table <- reactiveVal(TRUE) # Initialize table visibility
  # 
  output$showProducts<- renderDataTable({
    if(show_table()){ # Render placeholder table for expiry dates
      showProducts_query <- "
        SELECT ProductCode, ProductName, ExpiryDate, StockNumber, MarketPrice, SalePrice
        FROM Products
        WHERE ExpiryDate <= DATE('now', '+7 days');"
      dbGetQuery(connect2DB, showProducts_query)
    } else {
      return(NULL)
    }
  })
  
  observeEvent(input$applyDiscounts, {
      show_table(FALSE) # Hide placeholder table
      # Query products with close expiry dates
      query <- "
      SELECT 
        ProductCode, 
        ProductName, 
        ExpiryDate, 
        StockNumber, 
        MarketPrice
      FROM Products
      WHERE ExpiryDate <= DATE('now', '+7 days');
    "

      close_expiry_data <- dbGetQuery(connect2DB, query)
      
      # SalePrice calculation based on discount
      close_expiry_data <- close_expiry_data %>%
        mutate(
          Discount = case_when(
            as.Date(ExpiryDate) <= Sys.Date() + 3 ~ (input$discount_3Day / 100), 
            as.Date(ExpiryDate) <= Sys.Date() + 5 ~ (input$discount_5Day / 100),
            TRUE ~ (input$discount_7Day / 100) 
          ),
          SalePrice = MarketPrice * (1 - Discount)
        )
      
      # Updating SalePrice in database
      dbExecute(connect2DB, sprintf(
        "UPDATE Products 
       SET SalePrice = CASE ProductCode %s END 
       WHERE ProductCode IN (%s);",
        paste(sprintf("WHEN '%s' THEN %.2f", close_expiry_data$ProductCode, close_expiry_data$SalePrice), collapse = " "),
        paste(sprintf("'%s'", close_expiry_data$ProductCode), collapse = ",")
      ))
      
      # Show discounted products' table
      output$discountedProductsTable <- renderDataTable({
        datatable(
          close_expiry_data %>% select(ProductCode, ProductName, ExpiryDate, StockNumber, MarketPrice, SalePrice),
          options = list(pageLength = 10, autoWidth = TRUE),
          rownames = FALSE
        )
      })
      showNotification("Sale prices updated successfully for close expiry products.", type = "message")
  })

} 