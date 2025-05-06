# Install and load packages
install.packages("ggplot2")
library(ggplot2)
install.packages("gridExtra")
library(gridExtra)

# Read data from .csv
data <- read.csv("normalised_data.csv")

# Create list for plots
plots <- list()

# Create loop that will produce a separate bell curve for each input variable 
for (i in 1:8) {
  var_name <- names(data)[i]
  plots[[i]] <- ggplot(data, aes_string(x = var_name)) +
    geom_density(fill = "black", alpha = 0.3, color = "black") +
    theme_minimal() +
    labs(title = var_name,
         x = "Normalised Score",
         y = "Density") +
    theme(panel.grid = element_blank(),
          text = element_text(color = "black"),
          axis.text = element_text(color = "black", size = 14),
          axis.title = element_text(size = 20),
          plot.title = element_text(size = 26, hjust = 0.5))
}

# Create a new plot that holds all 8 bell curves
combined_plot <- grid.arrange(
  plots[[1]], plots[[2]], 
  plots[[3]], plots[[4]], 
  plots[[5]], plots[[6]], 
  plots[[7]], plots[[8]], 
  ncol = 2
)
