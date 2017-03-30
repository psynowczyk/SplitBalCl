 # args -> [file, database, bin number (1...x=C1/C2)]
 # ex. -> $ Rscript scripts/R/splitbal_binary.R yeast6 1

 # load libraries
library("mongolite")
library("C50")

 # Normalize
Normalize <- function(x) (x - min(x)) / (max(x) - min(x))

 # Euclidean distance
EucDist <- function(x1, x2) sqrt(sum((x1 - x2) ^ 2))

 # initial variables
args = commandArgs()
db.name = args[6]
bin.number = as.numeric(args[7])

if (bin.number <= 0) bin.number = 1
calg = "C5.0"
split = c("train", "test")

 # open mongo connection
collname = paste(db.name, "_", split[2], sep="")
conn = mongo(collname, db.name)
testdata = conn$find()
class.number = ncol(testdata)
class.name = colnames(testdata)[class.number]
collname = paste(db.name, "_", split[1], sep="")
conn = mongo(collname, db.name)

 # find all class values and sizes
class.values = sort(conn$distinct(class.name)) # "negative", "positive"
class.sizes = c(rep(0, length(class.values)))  # 1014, 24
for (x in 1:length(class.values)) {
	query = paste('{"', class.name, '": "', class.values[x], '"}', sep="")
	class.sizes[x] = conn$count(query)
}
bin.positive = conn$find(query)

 # compute bin range
bin.count = floor(class.sizes[1] / class.sizes[2]) # 42
if (bin.number > bin.count) bin.number = bin.count
limit = class.sizes[2] # 24
 # distribiute overflow
if (bin.count * limit != class.sizes[1]) {
	overflow = class.sizes[1] - (bin.count * limit) # 6
	if (bin.number <= overflow) limit = limit + 1
}
skip = ((bin.number - 1) * limit) # 0, 24, 48, ...+24

 # read collection and build bin
query = paste('{"', class.name, '": "', class.values[1], '"}', sep="")
bin.negative = conn$find(query, skip=skip, limit=limit)
bin = rbind(bin.negative, bin.positive)
rm(limit)
rm(skip)

 # classify
if (calg == "C5.0") {
	model = C5.0(x = bin[, -class.number], y = as.factor(bin[, class.number]))
	probs = predict(model, testdata, type = "prob")
}
rm(bin)

 # normalize test data by row
testdata = t(apply(testdata[, -class.number], 1, Normalize))

 # compute distance
result = matrix(nrow = nrow(testdata), ncol = length(class.values))
for (x in 1:length(class.values)) {

	 # compute bin mean values
	bin.mean = eval(as.name(paste("bin.", class.values[x], sep="")))
	bin.mean = Normalize(colMeans(bin.mean[, -class.number]))

	 # compute average distance (bin.mean_Cx -> testdata[i])
	dist = apply(testdata[, -class.number], 1, EucDist, x2=bin.mean)
	dist = probs[, x] / (dist + 1)
	result[, x] = dist
}
rm(bin.mean)
rm(dist)
rm(probs)
colnames(result) = c(class.values)

 # return result
collname.result = paste("result_", bin.number, sep="")
conn = mongo(collname.result, db.name)
if(conn$count() > 0) conn$drop()
conn$insert(as.data.frame(result))

 # close mongo connection
rm(conn)
