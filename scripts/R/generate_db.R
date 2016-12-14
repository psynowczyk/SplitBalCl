 # args -> [file, database, collection, class name]
 # ex. -> $ Rscript generate_db.R imbalanced yeast6 Class

 # load libraries
library(mongolite)

 # initial variables
args = commandArgs()
db.name = args[6]
db.collection = args[7]
class.name = args[8]
ratio = 0.7
split = c("train", "test")
data.train = data.frame()
data.test = data.frame()

 # open mongo connection
conn = mongo(db.collection, db.name)

 # get test and train subsets
class.values = sort(conn$distinct(class.name)) # "negative", "positive"
for (x in 1:length(class.values)) {
	query = paste('{"', class.name, '": "', class.values[x], '"}', sep="")
	data = conn$find(query)
	size = round(nrow(data) * 0.7)	
	rand = sample(1:nrow(data), size)
	data.train = rbind(data.train, data[rand,])
	data.test = rbind(data.test, data[-rand,])
}

 # insert test and train subsets into database
for (x in 1:length(split)) {
	collname = paste(db.collection, "_", split[x], sep="")
	conn = mongo(collname, db.name)
	if(conn$count() > 0) conn$drop()
	data = eval(as.name(paste("data.", split[x], sep="")))
	conn$insert(data)
}

 # close mongo connection
rm(conn)
