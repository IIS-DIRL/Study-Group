# ggplot hands-on demo
library(data.table)
library(ggplot2)

# use dataset: mtcars
head(mtcars)

# basic
ggplot(mtcars, aes(wt, mpg)) + geom_point()

###########
# ggplot -- using stack method to change plots

# aes 
p <- ggplot(mtcars, aes(wt, mpg)) + 
  geom_point()
p 

# color - continous
# theme, ticks, title change
p + 
  geom_point(aes(color = cyl)) + 
  theme_bw() +
  labs(x = "XX", y = "YY") +
  ggtitle('Test123')

# color - discrete
p + 
  geom_point(aes(color = factor(cyl))) + 
  theme_bw() +
  labs(x = "XX", y = "YY") +
  ggtitle('Test123')

# Warning -- the later part will over lap former part
p + 
  geom_point(aes(color = factor(cyl))) + 
  stat_smooth() +
  theme_bw() +
  labs(x = "XX", y = "YY") +
  ggtitle('Test123')

p + 
  stat_smooth() +
  geom_point(aes(color = factor(cyl))) + 
  theme_bw() +
  labs(x = "XX", y = "YY") +
  ggtitle('Test123')

# inital aes to the data laye
ggplot(mtcars, aes(wt, mpg, color = factor(cyl))) + 
  geom_point() + 
  #stat_smooth() +
  theme_bw() +
  labs(x = "XX", y = "YY") +
  ggtitle('Test123')


###########

ggplot(mtcars, aes(wt, mpg)) + 
  geom_point() +
  stat_ellipse()

