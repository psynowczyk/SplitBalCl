 # args -> [file, database, train collection, test collection, class name, bin number]
 # ex. -> $ Rscript splitbal_binary.R imbalanced yeast6_train yeast6_test Class 1

 # load libraries
library(mongolite)

 # initial variables
args = commandArgs()
db.name = args[6]
db.coll_train = args[7]
db.coll_test = args[8]
class.name = args[9]
bin.number = as.numeric(args[10])

 # open mongo connection
conn = mongo(db.coll_test, db.name)
testdata = conn$find()
conn = mongo(db.coll_train, db.name)

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
limit = class.sizes[2] # 35
skip = ((bin.number - 1) * limit) # 0, 35, 70, ...+35
if (bin.number == bin.count) {
	limit = class.sizes[1] - skip
}

 # read collection and build bin
query = paste('{"', class.name, '": "', class.values[1], '"}', sep="")
bin.negative = conn$find(query, skip=skip, limit=limit)
bin = rbind(bin.negative, bin.positive)

 # classify
#probs = matrix(c(0), nrow = nrow(datasetTe), ncol = length(class))

 # close mongo connection
rm(conn)

