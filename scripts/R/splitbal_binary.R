 # args -> [file, database, collection, class name, bin number (1...x=C1/C2), output (mongo, file, console)]
 # ex. -> $ Rscript scripts/R/splitbal_binary.R imbalanced yeast6 Class 1 mongo

 # load libraries
library("mongolite")
library("C50")

 # Normalize
Normalize <- function(x) (x - min(x)) / (max(x) - min(x))

 # initial variables
args = commandArgs()
db.name = args[6]
db.collection = args[7]
class.name = args[8]
bin.number = as.numeric(args[9])
output = args[10]
if (bin.number <= 0) bin.number = 1
calg = "C5.0"
split = c("train", "test")

 # open mongo connection
collname = paste(db.collection, "_", split[2], sep="")
conn = mongo(collname, db.name)
testdata = conn$find()
collname = paste(db.collection, "_", split[1], sep="")
conn = mongo(collname, db.name)

 # find all class values and sizes
class.values = sort(conn$distinct(class.name)) # "negative", "positive"
class.sizes = c(rep(0, length(class.values)))  # 1449, 35
for (x in 1:length(class.values)) {
	query = paste('{"', class.name, '": "', class.values[x], '"}', sep="")
	class.sizes[x] = conn$count(query)
}
bin.positive = conn$find(query)

 # compute bin range
bin.count = floor(class.sizes[1] / class.sizes[2]) # 41
if (bin.number > bin.count) bin.number = bin.count
limit = class.sizes[2] # 35
skip = ((bin.number - 1) * limit) # 0, 35, 70, ...+35
if (bin.number == bin.count) limit = class.sizes[1] - skip

 # read collection and build bin
query = paste('{"', class.name, '": "', class.values[1], '"}', sep="")
bin.negative = conn$find(query, skip=skip, limit=limit)
bin = rbind(bin.negative, bin.positive)

 # classify
if (calg == "C5.0") {
	model = C5.0(x = bin[, -ncol(bin)], y = as.factor(bin[, ncol(bin)]))
	probs = predict(model, testdata, type = "prob")
}

 # compute mean distance value (needed at ensemble process)
bin.mean = data.frame()
bin.mean = rbind(bin.mean, Normalize(colMeans(bin.negative[, -ncol(bin.negative)])))
bin.mean = rbind(bin.mean, Normalize(colMeans(bin.positive[, -ncol(bin.positive)])))
colnames(bin.mean) = 1:(ncol(bin) - 1)

 # return result
collname.result = paste(db.collection, "_result_", bin.number, sep="")
collname.mean = paste(db.collection, "_mean_", bin.number, sep="")
dirname = paste("results/", db.collection, "/", sep="")
if (output == "file") {
	if (!dir.exists("results/")) dir.create("results/", mode = "0777")
	if (!dir.exists(dirname)) dir.create(dirname, mode = "0777")
	file.name.probs = paste(dirname, collname.result, sep="")
	file.name.means = paste(dirname, collname.mean, sep="")
	write(t(probs), file=file.name.probs, ncolumns=2)
	write(as.matrix(t(bin.mean)), file=file.name.means, ncolumns=(ncol(bin) - 1))
} else {
	if (output == "console") {
		writeLines("-----: Results :-----")
		print(probs)
		writeLines("-----: Means :-----")
		print(bin.mean)
	} else {
		conn = mongo(collname.result, db.name)
		if(conn$count() > 0) conn$drop()
		conn$insert(as.data.frame(probs))
		conn = mongo(collname.mean, db.name)
		if(conn$count() > 0) conn$drop()
		conn$insert(as.data.frame(bin.mean))
	}
}

 # close mongo connection
rm(conn)
