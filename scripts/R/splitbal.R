# args -> [database, collection, className, binNumber]
# ex. -> $ Rscript splitbal.R wine_white quality quality 1

# load libraries
library(mongolite)

# initial variables
args = commandArgs()
database = args[6]
collection = args[7]
className = args[8]
binNumber = as.numeric(args[9])

# open mongo connection
conn = mongo(collection, database)

# find all class values and sizes
classValues = sort(conn$distinct(className))
classSizes = c(rep(0, length(classValues)))
for (x in 1:length(classValues)) {
	query = paste('{"', className, '": ', classValues[x], '}', sep="")
	classSizes[x] = conn$count(query)
}

## compare class sizes in order to proceed with bin creation process

# read collection
#dataset = mongo$find('{"foo": "bar"}', skip=skip, limit=limit)

# close mongo connection
rm(conn)

