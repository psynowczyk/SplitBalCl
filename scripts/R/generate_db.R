# args -> [
# 	1 * script file,
# 	2 * database name || file name (w/o extension),
# 	3 ? balance ratio (ex. 0.7 || 0 to skip),
# 	4 ? class size limit (ex. 300 || 0 to skip)
# 	5 ? feature selection (c/i ex. true || t || False || F )
# ]
# usage ex. ->
# 	Rscript scripts/R/generate_db.R yeast6

# load libraries
library("mongolite") 	# mongodb connection
library("entropy") 		# Shannon entropy (ChaoShen)

# normalize
normalize <- function(x) (x - min(x)) / (max(x) - min(x))

# discrete probability distribution
dpd <- function(v, ...) (count <- table(v, ..., dnn=NULL)) / sum(count)

# mutual information
mutualInformation <- function(v1, v2) {
   p = dpd(v1, v2)
   p1 = rowSums(p)
   p2 = colSums(p)
   sum(p*log2(p/(p1%o%p2)), na.rm=TRUE)
}

# symmetric uncertainty
symmetricUncertainty <- function(v1, v2) {
	2 * mutualInformation(v1, v2) / (entropy.ChaoShen(v1) + entropy.ChaoShen(v2))
}

# remove irrelevant features
removeIrrelevantFeatures <- function(data) {
	threshold = 0
	su = c()
	data.number.cols = ncol(data)
	for (x in 1:(data.number.cols - 1)) {
		su[x] = symmetricUncertainty(data[, x], as.numeric(as.factor(data[, data.number.cols])))
	}
	su = round(su, 4)
	su[length(su) + 1] = threshold + 0.1
	features = which(su > threshold)
	cat("~ Removed ", (data.number.cols - length(features)), " out of ", data.number.cols, " features\n", sep = "")

	return(data[, features])
}

# main
main <- function() {

	# -- INFORMATONS GATHERING -- #
	writeLines("~ INFORMATONS GATHERING")

	# read and validate command args
	args = commandArgs()
	db.name = args[6]
	if (is.na(db.name)) stop("database / file name is missing (entry arguments)")
	split.ratio = as.numeric(args[7])
	if (is.na(split.ratio) || split.ratio < 0.1) split.ratio = 0.7
	data.limit = as.numeric(args[8])
	feature.selection = as.logical(toupper(args[9]))
	if (is.na(feature.selection)) feature.selection = FALSE
	split.names = c("train", "test")
	data.train = data.frame()
	data.test = data.frame()

	# fetch data from mongo db or file
	conn = mongo(db.name, db.name)
	if (conn$count() > 0) {
		data = conn$find()
	}
	else {
		file.name = paste("datasets/", db.name, ".csv", sep = "")
		if (!file.exists(file.name)) stop("database collection nor dataset file has been found")
		data = read.table(file.name, header=TRUE, dec=".", sep=",", strip.white = TRUE, row.names=NULL)
		conn$insert(data)
	}

	# gather class informatons
	class.number = ncol(data)
	class.label = colnames(data)[class.number]


	# -- FORMAT DATASET -- #
	writeLines("~ DATASET FORMATTING")

	# remove instances with empty values
	data[data[,] == ""] = NA
	data = data[complete.cases(data),]
	# a class might have been removed, find classes names
	class.names = levels(as.factor(data[[class.label]])) # ex. "negative", "positive"
	class.amount = length(class.names)

	# convert non-integer columns
	columns.nonint = sapply(data[, -class.number], is.character)
	columns.nonint[class.label] = FALSE
	if (length(columns.nonint[columns.nonint[] == TRUE]) > 0) {
		data[columns.nonint] = lapply(data[columns.nonint], function(i) as.numeric(as.factor(i)))
		data[columns.nonint] = normalize(data[columns.nonint])
	}
	if (is.na(data.limit) || data.limit < 1) data.limit = nrow(data)


	# -- IRRELEVANT FEATURES REMOVAL -- #
	if (feature.selection) {
		writeLines("~ IRRELEVANT FEATURES REMOVAL")
		data = removeIrrelevantFeatures(data)
		# update class number
		class.number = ncol(data)
	}


	# -- TRAIN & TEST SUBSET OBTAINING -- #
	writeLines("~ TRAIN & TEST SUBSET OBTAINING")

	# assemble parts from each class
	for (i in 1:class.amount) {

		# fetch all instances of i-class
		subdata = subset(data, data[, class.number] == class.names[i])
		subdata.size = nrow(subdata)
		if (subdata.size < data.limit) limit = subdata.size
		else limit = data.limit
		subdata = subset(subdata[1:limit,])

		size = floor(nrow(subdata) * split.ratio)
		rand = sample(1:nrow(subdata), size)
		data.train = rbind(data.train, subdata[rand,])
		data.test = rbind(data.test, subdata[-rand,])
	}


	# insert test and train subsets into database
	for (i in 1:length(split.names)) {

		collection = paste(db.name, "_", split.names[i], sep="")
		conn = mongo(collection, db.name)
		if (conn$count() > 0) conn$drop()
		data = eval(as.name(paste("data.", split.names[i], sep="")))
		data[[class.number]] = as.character(data[[class.number]])
		conn$insert(data)
	}

	# close mongo connection
	rm(conn)
}

main()
writeLines("~ DONE")
