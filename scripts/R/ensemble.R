 # args -> [file, database, collection, input, output]
 # ex. -> $ Rscript scripts/R/ensemble.R imbalanced yeast6 mongo mongo

 # load libraries
library("mongolite")
library("ROCR")

 # initial variables
args = commandArgs()
db.name = args[6];
db.collection = args[7];
input = args[8];
output = args[9];
collname.test = paste(db.collection, "_test", sep="")
conn = mongo(collname.test, db.name)
testdata = conn$find()
ensemble.rules = c("MaxDistance", "SumDistance")
ensemble.result = matrix(c(0), nrow = nrow(testdata), ncol = (length(ensemble.rules) * 2))
ensemble.auc = matrix(c(0), nrow = 1, ncol = length(ensemble.rules))
colnames(ensemble.auc) = ensemble.rules

 # Euclidean distance
EucDist <- function(x1, x2) sqrt(sum((x1 - x2) ^ 2))

 # Confidence
Conf <- function(data, prob) {
   result = data.frame()
   labels = as.numeric(as.factor(data[, ncol(data)]))-1
   for (x in 1:nrow(data)) {
      if (!is.vector(prob)) result = rbind(result, c(as.numeric(prob[x, 2]), labels[x]))
      if (is.vector(prob)) result = rbind(result, c(as.numeric(prob[x]), labels[x]))
   }
   return(result)
}

 # iterate over results
bin.number = 1
while(bin.number > 0) {
	 # read next results seubset from database
	if (input == "mongo") {
		collname.result = paste(db.collection, "_result_", bin.number, sep="")
		collname.mean = paste(db.collection, "_mean_", bin.number, sep="")
		conn = mongo(collname.result, db.name)
		 # check if subset exists
		if (conn$count() > 0) {
			bin = conn$find()
			conn = mongo(collname.mean, db.name)
			bin.mean = conn$find()
			bin.number = bin.number + 1
		}
		else {
			bin.number = 0
		}
	}
	 # read next results seubset from file
	if (input == "file") {
		collname.result = paste("results/", db.collection, "/", db.collection, "_result_", bin.number, sep = "")
		collname.mean = paste("results/", db.collection, "/", db.collection, "_mean_", bin.number, sep = "")
		 # check if subset exists
		if (file.exists(collname.result)) {
			bin = read.table(collname.result, header=FALSE, dec=".", sep=" ", strip.white = TRUE)
			colnames(bin) = c("negative","positive")
			bin.mean = read.table(collname.mean, header=FALSE, dec=".", sep=" ", strip.white = TRUE)
			colnames(bin.mean) = 1:(ncol(bin.mean))
			bin.number = bin.number + 1
		}
		else {
			bin.number = 0
		}
	}
	 # if subset exists iterate over probabilities
	if (bin.number > 0) {
		for(index in 1:nrow(bin)) {
			 # compute average distance:
			dist.negative = EucDist(bin.mean[1,], testdata[index, -ncol(testdata)]) + 1
			dist.positive = EucDist(bin.mean[2,], testdata[index, -ncol(testdata)]) + 1
			result.temp.negative = bin[index, 1] / dist.negative
			result.temp.positive = bin[index, 2] / dist.positive
			for (rule in 1:length(ensemble.rules)) {
				 # MaxDistance
				col = (2 * (rule - 1)) + 1
				if (ensemble.rules[rule] == "MaxDistance") {
					if (ensemble.result[index, col] < result.temp.negative) ensemble.result[index, 1] = result.temp.negative
					if (ensemble.result[index, (col+1)] < result.temp.positive) ensemble.result[index, 2] = result.temp.positive
				}
				 # SumDistance
				if (ensemble.rules[rule] == "SumDistance") {
					ensemble.result[index, col] = ensemble.result[index, 1] + result.temp.negative
					ensemble.result[index, (col+1)] = ensemble.result[index, 2] + result.temp.positive
				}
			}
		}
	}
}

 # Compute AUC
for (rule in 1:length(ensemble.rules)) {
	col = (2 * (rule - 1)) + 1
	conf = Conf(testdata, ensemble.result[, col:(col+1)])
	pred = prediction(conf[, 1], conf[, 2])
	perf = performance(pred, "auc")
	ensemble.auc[1, rule] = as.numeric(slot(perf, "y.values")[1])
}

 # return result
collname.result = paste(db.collection, "_ensemble", sep = "")
collname.auc = paste(db.collection, "_auc", sep = "")
dirname = paste("results/", db.collection, "/", sep = "")

if (output == "file") {
	if (!dir.exists("results/")) dir.create("results/", mode = "0777")
	if (!dir.exists(dirname)) dir.create(dirname, mode = "0777")
	file.name.ensemble = paste(dirname, collname.result, sep = "")
	file.name.auc = paste(dirname, collname.auc, sep = "")
	write(t(ensemble.result), file = file.name.ensemble, ncolumns = (ncol(ensemble.result)))
	write.table(ensemble.auc, file = file.name.auc, row.names = FALSE, col.names = TRUE)
}
if (output == "console") {
	writeLines("-----: Results :-----")
	print(ensemble.result)
	writeLines("-----: AUCs :-----")
	print(ensemble.auc)
}
if (output == "mongo") {
	conn = mongo(collname.result, db.name)
	if(conn$count() > 0) conn$drop()
	conn$insert(as.data.frame(ensemble.result))
	conn = mongo(collname.auc, db.name)
	if(conn$count() > 0) conn$drop()
	conn$insert(as.data.frame(ensemble.auc))
}

 # close mongo connection
rm(conn)
