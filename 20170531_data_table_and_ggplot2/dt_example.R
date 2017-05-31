library(data.table)
# create a datatable
dt <- data.table(A = 1:6, 
                 B = letters[1:3], 
                 C = rnorm(2), D = TRUE)

# select rows by number or condition in i
dt[3:5]
dt[A < 3]

# select columns in i
col_name <- names(dt)
dt[[which(col_name == 'A')]]

# select columns in j
dt[, .(A)]
dt[, .(A, B)]

# computing on columns in j
dt[, .(Mean = mean(A), Total = sum(C))]

# doing j by group
dt[, .(Mean = mean(A), Total = sum(C)), by=.(B)]

# function calls in by
dt[, .(Total = sum(C)), by=.(A%%2)]

# grouping only on a subset
dt[C > 0, .(Total = sum(C)), by=.(A%%2)]

# chaining operations together
dt[, .(Total = sum(C)), by=.(A%%2)][order(A)]

# add/update columns in j using :=
dt[, E := A + C]
dt
dt[, c("a", "b") := .(mean(A), rev(B))]
dt

# remove columns using :=
dt[, E := NULL]
dt[, c("a", "b") := NULL]
dt

# testing of speed
types <- LETTERS[1:6]
obs <- 8e+07
temp.df <- data.frame(id = as.factor(seq(from = 1, to = 80000, by = 1)), 
                      percent = round(runif(obs, min = 0, max = 1), digits = 2), 
                      type = as.factor(sample(types, obs, replace = TRUE)))
temp.dt <- data.table(temp.df)
head(temp.dt)

library(dplyr)
# compare calculating speed of 
system.time(test.df <- summarise(group_by(temp.df, id), 
                                 percent_total = sum(percent),
                                 mean_total = mean(percent)))
system.time(test.dt <- temp.dt[, .(percent_total=sum(percent), mean_total=mean(percent)), by=.(id)])

######################
# .SD, shift and set #
######################

# .SD
dt <- data.table(iris)
dt[, lapply(.SD, median), by = Species]

col_name <- grep('Length', names(dt), value = TRUE)
dt[, lapply(.SD, median), .SDcols = col_name, by = Species]
dt[, (paste0('new_', col_name)) := lapply(.SD, mean), .SDcols = col_name]

# subset of row
# using .N
dt[, .(count=.N)]
dt[, .(count=.N), by=.(Species)]
dt[, .(Sepal.Length=Sepal.Length[2:(.N-1)]), by=.(Species)]
# using condition
a = parse(text = "Sepal.Width > mean(Sepal.Width)")
dt[, .(large.Sepal.Length=Sepal.Length[eval(a)])]
dt[, .(large.Sepal.Length=Sepal.Length[Sepal.Length > mean(Sepal.Length)]), by=.(Species)]

# set
# set column names
setnames(dt, paste0('new_', col_name), paste0('mean_', col_name))
# set row order
setorder(dt, -Sepal.Length)
dt
setorder(dt, -Sepal.Length, Sepal.Width)
dt
# set coloumns order
setcolorder(dt, c(1, 3:7, 2))
dt

# shift
# creating some data
n <- 30
dt <- data.table(
  date=rep(seq(as.Date('2010-01-01'), as.Date('2015-01-01'), by='year'), n/6), 
  value=rpois(n, 5),
  group=sort(rep(letters[1:5], n/5))
)
# lag vector
dt[, value_lag := shift(value, 1)]
dt# lead vector
dt[, value_forward := shift(value, 1, type = 'lead')]

# shift with by
dt[, value_lag_by_entity := shift(value, 1), by=group]

#############
# reshaping #
#############
library(ggplot2)
library(tidyr)
test_data <- data.table( date = seq(as.Date("2002-01-01"), by="1 month", length.out=100),
                         var0 = 100 + c(0, cumsum(runif(49, -20, 20))),
                         var1 = 150 + c(0, cumsum(runif(49, -10, 10))))
head(test_data)
# wide to long
# tidyr way
long2 <- gather(test_data, key = col_key, value = var, -date)
# data.table way
long1 <- melt(test_data, id.vars = "date", variable.name = "type", value.name = "v")

test_data %>%
  melt(id.vars = "date", variable.name = "type", value.name = "v") %>%
  ggplot(aes(x=date, y=v, colour=type)) +
  geom_line()

# long to wide
# tidyr way
wide2 <- spread(long2, key = col_key, value = var)
# data.table way
wide1 <- dcast(long1, date ~ type, value.var = "v")

# dcast tricks
dt <- data.table(x=sample(5,20,TRUE), y=sample(2,20,TRUE), 
                z=sample(letters[1:2], 20,TRUE), d1 = runif(20), d2=1L)
head(dt)
# multiple value.var
# see dt[x == 1 & y == 1] if can't understand
dcast(dt, x + y ~ z, fun=sum, value.var=c("d1","d2"))
# multiple fun.aggregate
dcast(dt, x + y ~ z, fun=list(sum, mean), value.var="d1")
# multiple fun.agg and value.var (all combinations)
dcast(dt, x + y ~ z, fun=list(sum, mean), value.var=c("d1", "d2"))
# multiple fun.agg and value.var (one-to-one)
dcast(dt, x + y ~ z, fun=list(sum, mean), value.var=list("d1", "d2"))

# separate columns
test_data <- separate(test_data, date, c("year", "month", "day"), sep = "_")
test_data
test_data <- unite(test_data, date, year, month, day, sep = "/")

######################
# merging data.table #
######################

# set key and merge
Employees <- data.table(id=1:6, name=c("Alice", "Bob", "Carla", "Daniel", "Evelyn", "Ferdinand"), 
                        department=c(11, 11, 12, 12, 13, 21), salary=c(800, 600, 900, 1000, 800, 700))
Departments <- data.table(department=11:14, department.name=c("Production", "Sales", "Marketing", "Research"), manager=c(1, 4, 5, NA))
# set the ON clause as keys of the tables:
setkey(Employees,department)
setkey(Departments,department)

# inner join
# perform the join, eliminating not matched rows from Right
# setkey way
Employees[Departments, nomatch=0]
# data.table merge way
merge(Employees, Departments, by="department")

# left outer join
# setkey way
Departments[Employees]
# data.table merge way
merge(Employees, Departments, by="department", all.x = TRUE)

# right outer join
# setkey way
Employees[Departments]
# data.table merge way
merge(Employees, Departments, by="department", all.y = TRUE)

# full outer join
# data.table merge way
merge(Employees, Departments, by="department", all = TRUE)

################
# rolling join #
################

sales<-data.table(saleID=c("S1","S2","S3","S4","S5"), 
                  saleDate=as.Date(c("2014-2-20","2014-5-1","2014-6-15","2014-7-1","2014-12-31")))
commercials<-data.table(commercialID=c("C1","C2","C3","C4"), 
                        commercialDate=as.Date(c("2014-1-1","2014-4-1","2014-7-1","2014-9-15")))
sales[, rollDate:=saleDate] # Add a column, rollDate equal to saleDate
commercials[, rollDate:=commercialDate] # Add a column, rollDate equal to commercialDate

setkey(sales, "rollDate")
setkey(commercials, "rollDate")

# associating each commercial with the most recent sale prior to the commercial date
sales[commercials, roll=TRUE]
# backward rolling
sales[commercials, roll=-Inf]

# associating each sale with the most recent commercial prior to the saleDate
commercials[sales, roll=TRUE]
# backward rolling
commercials[sales, roll=-Inf]
