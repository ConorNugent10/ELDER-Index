# Check working directory
getwd()

# Load data
data <- read.csv("data.csv")

# Check
head(data)

# Install and load package
install.packages("stats")
library(stats)

# Get correlations and put into dataframe
cor_test <- cor.test(data$loneliness_index_norm, data$age_uk_index_norm, method = "pearson", conf.level = 0.95)
cor_test