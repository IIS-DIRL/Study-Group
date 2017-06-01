library(data.table)
library(stringi)
# for plot
library(ggplot2)
library(scales)

###
# PATH should change to this folder #
###

# real dataset
df.allshop.info <- readRDS("real_data.rds")

View(df.allshop.info)

################
# scatter plot #
################
p <- ggplot(df.allshop.info, aes(x = n.favorite, 
                                 y = n.share)) +
  geom_point()

p

p <- p + geom_point(aes(color = cate.minor)); p

p <- p + theme_bw(); p

# make axis logged
p + scale_x_log10()

# restrict data limit
p + scale_x_log10() + coord_cartesian(ylim = c(0, 50)) + stat_smooth()

p + scale_x_log10() + scale_y_continuous() + stat_smooth()
##############
## Watchout ##
# range restriction used in scale_y_continous will affect the computation !
##############

############
# bar plot #
############
# counts to percentile
# p <- ggplot(df.allshop.info, aes(x = cate.minor)) 
# 
# p + geom_bar(fill = 'blue')
# 
# p <- p + geom_bar(fill = 'blue', aes(y = (..count..)/sum(..count..))); p
# 
# p + 
#   theme_bw() + 
#   coord_flip() + 
#   scale_y_continuous(labels = percent, breaks = seq(0, 1, 0.1))  +
#   labs(x = "minor category", y = "percentage")

## counts to percentile & reorder bar plot
tmp <- df.allshop.info[, .(n = .N), .(cate.minor)]
tmp[, y := n / sum(n)]

ggplot(tmp, aes(x = cate.minor, y = y)) +
  geom_bar(fill = 'blue', stat = 'identity') +
  theme_bw() + 
  coord_flip() + 
  scale_y_continuous(labels = percent, breaks = seq(0, 1, 0.1))  +
  labs(x = "minor category", y = "percentage")

ggplot(tmp, aes(x = reorder(cate.minor, y, median) , y = y )) +
  geom_bar(fill = 'blue', stat = 'identity') +
  theme_bw() + 
  coord_flip() + 
  scale_y_continuous(labels = percent, breaks = seq(0, 1, 0.1))  +
  labs(x = "minor category", y = "percentage")
# reorder x by y, based on mean (descending/ascending)

###################
#### heat map #####
###################
# heat map and add text
cor.colname <- c("avg.cost", "n.scoring", "scoring.mix", "scoring.delicious",
                 "scoring.atom", "n.view", "n.favorite", "n.share")
df.allshop.info[, (cor.colname) := lapply(.SD, function(x) as.numeric(as.character(x)) ),
                .SDcols = cor.colname]
cor.matrix <- psych::corr.test(df.allshop.info[, cor.colname, with = F])
cor.matrix.r <- cor.matrix$r
cor.matrix.p <- cor.matrix$p

# melt data into plot-able dataframe
plt.r <- melt(data = cor.matrix.r, id.vars = "avg.cost", value.name = "cor")
plt.p <- melt(data = cor.matrix.p, id.vars = "avg.cost", value.name = "sig")
plt.tmp <- merge(plt.r, plt.p, by = c("Var1", "Var2"))
rm(plt.r, plt.p)

ggplot(plt.tmp, aes(Var1, Var2, fill = cor)) + 
  geom_tile() + theme_bw() +
  geom_text(aes(label = paste0(sprintf("%.2f", round(cor,3)), 
                               "\n", 
                               sprintf("%.2f", round(sig,3))))) +
  scale_fill_gradient2(low = "blue", high = "red")

# let p-value become stars & plot it
plt.tmp$p.star <- cut(plt.tmp$sig, 
                      breaks = c(-Inf, 0.001, 0.01, 0.05, 1),
                      labels = c("***", "**", "*", ""), 
                      include.lowest = F, right = T)

ggplot(plt.tmp, aes(Var1, Var2, fill = cor)) + 
  geom_tile() + theme_bw() +
  geom_text(aes(label = paste0(sprintf("%.2f", round(cor,3)), 
                               p.star))) +
  scale_fill_gradient2(low = "blue", mid = "white", high = "red")



################
# ecdf & facet #
################
# orignal
ggplot(df.allshop.info, aes(x = avg.cost)) +
  stat_ecdf(aes(color = factor(cate.minor)), geom = "line", size = 5) +
  theme_bw() + 
  labs(y = "cumulative n") +
  geom_hline(yintercept = 0.5, lty = 2, color = "red") +
  scale_y_continuous(labels = percent) + 
  scale_color_discrete("cate.minor")

# facet-like
ggplot(df.allshop.info, aes(x = avg.cost)) +
  stat_ecdf(aes(color = factor(cate.minor)), geom = "line") +
  theme_bw() + labs(y = "cumulative n") +
  geom_hline(yintercept = 0.5, lty = 2, color = "red") +
  scale_y_continuous(labels = percent) + 
  scale_color_discrete("cate.minor") +
  facet_wrap(~cate.minor)
