 # args -> [file, database, collection, class name, bin number (1...x=C1/C2), output (mongo, file, console)]
 # ex. -> $ Rscript splitbal_binary.R imbalanced yeast6 Class 1 mongo

 # load libraries
library(mongolite)
library(C50)

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

 # return result
collname = paste(db.collection, "_result_", bin.number, sep="")
filename = paste("results/", collname, sep="")
if (output == "file") {
	if (!dir.exists("results/")) dir.create("results/", mode = "0777")
	write(t(probs), file=filename, ncolumns=2)
} else {
	if (output == "console") {
		writeLines("RESULTS")
		print(probs)
	} else {
		conn = mongo(collname, db.name)
		if(conn$count() > 0) conn$drop()
		conn$insert(as.data.frame(probs))
	}
}

 # close mongo connection
rm(conn)

