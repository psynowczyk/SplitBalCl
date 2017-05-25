# args -> [file, database | file, ?ratio (1-test/train), ?limit]
# ex. -> $ Rscript scripts/R/generate_db.R yeast6

# load libraries
library("mongolite")

# normalize
normalize <- function(x) (x - min(x)) / (max(x) - min(x))

# main
main <- function() {

	# read and validate command args
	args = commandArgs()
	db.name = args[6]
	if (is.na(db.name)) stop("database / file name is missing (entry arguments)")
	split.ratio = as.numeric(args[7])
	if (is.na(split.ratio) || split.ratio < 0.1) split.ratio = 0.7
	data.limit = as.numeric(args[8])
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
	class.names = levels(as.factor(data[[class.label]])) # ex. "negative", "positive"

	# remove instances with empty values
	data[data[,] == ""] = NA
	data = data[complete.cases(data),]

	# convert non-integer columns
	columns.nonint = sapply(data[, -class.number], is.character)
	columns.nonint[class.label] = FALSE
	if (length(columns.nonint[columns.nonint[] == TRUE]) > 0) {
		data[columns.nonint] = lapply(data[columns.nonint], function(i) as.numeric(as.factor(i)))
		data[columns.nonint] = normalize(data[columns.nonint])
	}
	if (is.na(data.limit)) data.limit = nrow(data)


	# set test and train subsets
	for (i in 1:length(class.names)) {

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
