# Install and load packages
install.packages("corrplot")
library(corrplot)
install.packages("moments")
library(moments) 

# Check working directory 
getwd()

# Load data from  .csv
df <- read.csv("data.csv")

# Check
head(df)

# Calculate coefficients and put into dataframe
correlation_matrix <- cor(df, method = "pearson")
print(correlation_matrix)

# Round values
correlation_table <- round(correlation_matrix, 3)
print(correlation_table)

# Get VIF values via diagonal solve of inverse correlation matrix
vif_values <- diag(solve(correlation_matrix))

# Then put into dataframe
vif_df <- data.frame(Variable = colnames(df), VIF = vif_values)
print(vif_df)

# Set colour palette as blue to white to red
colour_palette <- colorRampPalette(c("#6BAED6", "white", "#FB8072"))(100)

# Create plot
corrplot(correlation_table, method = "circle", type = "lower", diag = FALSE, col = colour_palette, tl.col = "black", tl.srt = 45, cl.cex = 0.7, addCoef.col = "black", number.cex = 0.7, title = "Correlation Matrix", mar = c(0, 0, 5, 0))     # Title margin

# Get skewness values and put into dataframe
skew_values <- sapply(df, skewness)
skew_values 