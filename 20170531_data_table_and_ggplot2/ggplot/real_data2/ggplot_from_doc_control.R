library(data.table)
library(ggplot2)
library(gsheet)

setwd("C:\\Users\\Fred yu\\Dropbox\\Side_proj\\study_group\\DataTable_ggplot\\real_data2")

# Color control
color_table <- readRDS("category1_color_table.rds")
color_test <- data.frame(color = color_table$color, row.names = color_table$uni_class, stringsAsFactors = F)
color_test
color_test <- setNames(color_test$color, rownames(color_test))
color_test

# English to Chinese 
xs_ref_name <- read.csv("feature_names.csv", fileEncoding = "BIG-5", stringsAsFactors = F)
xs_ref_name <- data.frame(chn.names = as.character(xs_ref_name$feature.chn), row.names = xs_ref_name$feature.eng, stringsAsFactors = F)
xs_ref_name <- setNames(xs_ref_name$chn.names, rownames(xs_ref_name) )

inspect1 <- readRDS("inspect_wolog.rds")
inspect1 <- inspect1[price.set < 2000, ] # remove bunch books
plot_ref <- readRDS("group_corr.rds")
trend_matrix <- readRDS("trend_matrix.rds")
inspect1 <- inspect1[!is.na(category_lv1_1),]

inspect1[, cate_short := sapply(category_lv1_1, function(x) strsplit(x, split = "_")[[1]][2])]

# ways to get table from google sheet (sometimes it will have problems)
#to_plot <- data.table(gsheet2tbl("https://docs.google.com/spreadsheets/d/1sG9KLCCRl2YwuNkq1OpahS2HuCXrfhP4bdXp7Sm7xMU/edit#gid=660090063"))
#
to_plot <- data.table(fread("corInvest_plotfile.csv",
                            sep = ",", 
                            header = T, 
                            stringsAsFactors = F,
                            encoding = 'UTF-8'))

#to_plot$category <- iconv(to_plot$category, to = "UTF-8")

# scatter plots for real highly correlated or strange cor#
for (idx in 1:nrow(to_plot)) {
  print(to_plot[idx,])
  
  if (to_plot[idx,]$category != "") {
    temp <- copy(inspect1[category_lv1_1 == to_plot[idx,]$category, ])
  } else {
    eval(parse(text = paste0("cats_to_get <- plot_ref$", to_plot[idx,]$y_index, "[vars == '", to_plot[idx,]$x_index, "' & pvalue <=.01,]$cate")))
    temp <- copy(inspect1)
    temp <- temp[category_lv1_1 %in% cats_to_get,]
    rm(cats_to_get)
  }
  setnames(temp, c(to_plot[idx,]$x_index, to_plot[idx, ]$y_index), c("xx", "yy"))
  temp[, `:=`(category_lv1_1 = sapply(category_lv1_1, function(x) strsplit(x, split = "_")[[1]][2]))]
  # basic plot
  if (to_plot[idx,]$type == "xy") {
    x_jitter <- with(to_plot[idx ], (x_max - x_min) * 0.05)
    
    if (to_plot[idx,]$y_log == T) {
      y_jitter <- with(temp, (max(log10(yy+1),na.rm = T) - min(log10(yy+1), na.rm = T)) * 0.05 )
    } else {
      y_jitter <- with(temp, (max(yy,na.rm = T) - min(yy, na.rm = T)) * 0.01)
    }
    
    p <- ggplot(temp[yy > 0,], 
                aes(x = xx, y = yy )) + 
      geom_point(alpha = 0.4, color = 'tomato3', 
                 position = position_jitter(width = x_jitter, height = y_jitter))
    rm(x_jitter)
  } else if(to_plot[idx,]$type == "box") {
    # create q25, med, q75 table
    test_table <- temp[, .(med = as.numeric(median(yy, na.rm = T)), 
                           q25 = quantile(yy, 0.25, na.rm = T), 
                           q75 = quantile(yy, 0.75, na.rm = T),
                           n = .N), 
                       .(xx, cate_short)]
    
    ord_table <- reshape(test_table[, .(cate_short, f = factor(xx), med)], 
                         idvar = "cate_short", timevar = "f", direction = "wide")
    ord_table[, `:=`(med_diff = (med.1 - med.0), direc_sign = sign(med.1-med.0))]
    ord_table <- ord_table[order(med_diff, decreasing = T),]
    test_table$cate_short <- factor(test_table$cate_short, levels = ord_table$cate_short)
    
    p <- ggplot(test_table, aes(x = factor(xx), color = factor(xx), fill = factor(xx) )) + 
      geom_boxplot(stat = "identity", show.legend = F, alpha = 0.3, outlier.colour = NA, lwd = 1.2,
                   aes(middle = med, lower = q25, ymin = q25, upper = q75, ymax = q75)) + 
      facet_wrap(~cate_short, scales = "free_y") + scale_x_discrete(labels = c("否", "是"))
    
    rm(test_table, ord_table)
  }
  
  x_min <- ifelse(!is.na(to_plot[idx,]$x_min), to_plot[idx, ]$x_min, min(temp$xx+1, na.rm = T) )
  x_max <- ifelse(!is.na(to_plot[idx,]$x_max), to_plot[idx, ]$x_max, max(temp$xx, na.rm = T) )
  # decide log scale
  if (to_plot[idx, ]$x_log == TRUE) {
    # decide x plot range
    p <- p + scale_x_continuous(trans = "log10")
    
  }
  if (to_plot[idx, ]$y_log == TRUE) {
    p <- p + scale_y_continuous(trans = "log10") 
  } 
  
  # change label texting
  #temp_cor <- round(with(temp, cor.test(xx, yy)$estimate),2)
  y_chn <- xs_ref_name[to_plot[idx,]$y_index]
  x_chn <- xs_ref_name[to_plot[idx,]$x_index]
  if (to_plot[idx,]$type == "xy") {
    eval(parse(
      text = paste0("temp_cor <- plot_ref$", 
                    to_plot[idx,]$y_index, "[cate == '", to_plot[idx,]$category, 
                    "' & vars == '", to_plot[idx,]$x_index, "',]$corr")))
    temp_cor <- round(temp_cor, 2)
    if (to_plot[idx,]$lm_method == "lm") {
      p <- p + geom_smooth(method = "lm", alpha = 0.2, size = 2)
    } else if (to_plot[idx, ]$lm_method == "loess") {
      p <- p + geom_smooth(method = "loess", alpha = 0.2, span = 1.25, size = 2)
    }
    
    p <- p + 
      ggtitle(paste0(y_chn , " ~ ", x_chn, ", cor = ", sprintf("%.2f", temp_cor), " (", temp$category_lv1_1, ")" )) +
      theme_bw() + 
      labs(x = x_chn, y = paste0(y_chn, " ", to_plot[idx, ]$y_unit))
    
    # decide scale
    if (to_plot[idx, ]$y_index == "diversity") {
      # p <- p + coord_cartesian(xlim = c(x_min, x_max), ylim = c(quantile(temp$yy, 0.05, na.rm = T),1))
      p <- p + coord_cartesian(xlim = c(x_min, x_max), ylim = quantile(temp$yy, c(0.05,0.95), na.rm = T))
    } else {
      # p <- p + coord_cartesian(xlim = c(x_min, x_max), ylim = c(1, max(temp$yy,na.rm = T)))
      p <- p + coord_cartesian(xlim = c(x_min, x_max), ylim = quantile(temp$yy, c(0.05, 0.95), na.rm = T))
    }
    # decide theme
    if (to_plot[idx, ]$do_normalize == T) {
      p <- p + theme(plot.title = element_text(hjust = 0.5, size = 20),
                     axis.title = element_text(size = 15),
                     #axis.line = element_line(arrow = arrow(length = unit(0.1, "inches"))),
                     axis.ticks = element_blank(),
                     axis.text.y = element_blank())
    } else {
      p <- p + theme(plot.title = element_text(hjust = 0.5, size = 20),
                     axis.title = element_text(size = 15),
                     #axis.line = element_line(arrow = arrow(length = unit(0.1, "inches"))),
                     axis.ticks = element_blank()
                     )
    }
    
    # ggsave(p, 
    #        file = paste0(plt_outDir_corInvest, to_plot[idx,]$y_index, "_", to_plot[idx,]$x_index, "_", gsub(to_plot[idx,]$category, pattern = "/", replacement = "") , ".png"),
    #        dpi = 800, width = 25, height = 18, units = "cm")
    
  } else if (to_plot[idx,]$type == "box") {
    p <- p + ggtitle(paste0(y_chn , " ~ ", x_chn)) + 
      theme_bw() + 
      labs(x = x_chn, " ", y = paste0(y_chn, to_plot[idx, ]$y_unit))
    # decide normalize
    if (to_plot[idx, ]$do_normalize == T) {
      p <- p + theme(plot.title = element_text(hjust = 0.5, size = 20),
                     axis.title = element_text(size = 15),
                     strip.background = element_rect(fill = "papayawhip"),
                     strip.text = element_text(size = 12),
                     axis.ticks = element_blank(),
                     axis.text.y = element_blank())
    } else {
      p <- p + theme(plot.title = element_text(hjust = 0.5, size = 20),
                     axis.title = element_text(size = 15),
                     strip.background = element_rect(fill = "papayawhip"),
                     strip.text = element_text(size = 12),
                     axis.ticks = element_blank())
    }
    # decide theme
    
    # ggsave(p, file = paste0(plt_outDir_corInvest, to_plot[idx,]$y_index, "_", to_plot[idx,]$x_index, ".png"),
    #        dpi = 800, width = 25, height = 18, units = "cm")
  }
  rm(x_min, x_max)
}
