 # args -> [file, database]
 # ex. -> $ Rscript generate_db.R yeast6

 # load libraries
library("mongolite")

 # initial variables
args = commandArgs()
db.name = args[6]
ratio = 0.7
split = c("train", "test")
data.train = data.frame()
data.test = data.frame()

Normalize <- function(x) (x - min(x)) / (max(x) - min(x))

 # open mongo connection
conn = mongo(db.name, db.name)
data = conn$find(limit=1)
class.number = ncol(data)
class.name = colnames(data)[class.number]


 # get test and train subsets
class.values = sort(conn$distinct(class.name)) # "negative", "positive"
for (x in 1:length(class.values)) {
	query = paste('{"', class.name, '": "', class.values[x], '"}', sep="")
	data = conn$find(query)

	 # remove rows with empty values
	data[data[,] == ""] = NA
	data = data[complete.cases(data),]

	 # convert non-integer columns to int
	columns.nonint = sapply(data[,-class.number], is.character)
	columns.nonint[class.name] = FALSE
	if (length(columns.nonint[columns.nonint[] == TRUE]) > 0) {
		data[columns.nonint] = lapply(data[columns.nonint], function(x) as.numeric(as.factor(x)))
		data[columns.nonint] = Normalize(data[columns.nonint])
	}

	size = round(nrow(data) * ratio)	
	rand = sample(1:nrow(data), size)
	data.train = rbind(data.train, data[rand,])
	data.test = rbind(data.test, data[-rand,])
}

 # insert test and train subsets into database
for (x in 1:length(split)) {
	collname = paste(db.name, "_", split[x], sep="")
	conn = mongo(collname, db.name)
	if(conn$count() > 0) conn$drop()
	data = eval(as.name(paste("data.", split[x], sep="")))
	conn$insert(data)
}

 # close mongo connection
rm(conn)
