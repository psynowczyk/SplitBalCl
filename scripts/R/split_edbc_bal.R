# args -> [file, database, bin id (1...x=C1/C2), ?classification algorithm (c5.0)]
# ex. -> $ Rscript scripts/R/split_edbc_bal.R yeast6 1

# load libraries
library("mongolite")
library("entropy")
library("C50")

# normalize
normalize <- function(x) (x - min(x)) / (max(x) - min(x))

# euclidean distance
eucDist <- function(x1, x2) sqrt(sum((x1 - x2) ^ 2))

# main
main <- function() {

	# read and validate command args
	args = commandArgs()
	db.name = args[6]
	if (is.na(db.name)) stop("database name is missing (entry arguments)")
	bin.id = as.numeric(args[7])
	if (is.na(bin.id) || bin.id <= 0) stop("bin ID is missing (entry arguments)")
	model.algorithm = args[8]
	if (is.na(model.algorithm)) model.algorithm = "c5.0"


	# fetch test data from mongo db
	collection = paste(db.name, "_test", sep = "")
	conn = mongo(collection, db.name)
	data.test = conn$find()


	# set mongo connection on train data
	collection = paste(db.name, "_train", sep = "")
	conn = mongo(collection, db.name)


	# gather class informatons
	class.number = ncol(data.test) 					# ex. 8
	class.label = colnames(data.test)[class.number] # ex. "Class"
	class.names = sort(conn$distinct(class.label)) 	# ex. "negative", "neutral", "positive"
	class.amount = length(class.names)				# ex. 3
	class.sizes = c(rep(0, class.amount))  			# ex. 1014, 307, 24
	# fill class.sizes
	for (i in 1:class.amount) {
		query = paste('{"', class.label, '": "', class.names[i], '"}', sep="")
		class.sizes[i] = conn$count(query)
	}
	class.number.shortfall = which(class.sizes == min(class.sizes))[1] 	# which class is the smallest
	class.number.excess = which(class.sizes == max(class.sizes))[1] 	# which class is the biggest


	# compute amount of bins
	bin.amount = floor(class.sizes[class.number.excess] / (class.sizes[class.number.shortfall] * 1.5))
	#floor(sum(floor(class.sizes[-class.number.shortfall] / class.sizes[class.number.shortfall])) / class.amount)
	if (bin.id > bin.amount) stop("bin ID greater than number of bins")


	# fetch shortfall subset
	query = paste('{"', class.label, '": "', class.names[class.number.shortfall], '"}', sep = "")
	bin.data = conn$find(query)


	# build bin
	bin.means = vector("list", class.amount)
	bin.means[[class.number.shortfall]] = normalize(colMeans(bin.data[, -class.number]))


	for (i in 1:class.amount) {

		# skip shortfall class as it's already included
		if (i != class.number.shortfall) {
			
			# ~ shortfall (size <= shortfall * 1.5) copy whole
			if (class.sizes[i] <= round(class.sizes[class.number.shortfall] * 1.5)) {

				# number of instances of i-class for this bin
				bin.limit = 0
				# number of instances of i-class to skip this bin
				bin.skip = 0

			}
			else {
				# ~ underflow (in between) - copy parts
				if (class.sizes[i] / bin.amount < class.sizes[class.number.shortfall] * 1.5) {

					bin.limit = floor(class.sizes[class.number.shortfall] * 1.5)
					bin.skip = ((bin.id - 1) * bin.limit) %% class.sizes[i]

				}
				# ~ overflow - unique parts
				else {
					
					bin.limit = floor(class.sizes[i] / bin.amount)
					
					# rest distribution
					rest = class.sizes[i] - (bin.amount * bin.limit)
					if (rest > 0 && bin.id <= rest) bin.limit = bin.limit + 1
					bin.skip = ((bin.id - 1) * bin.limit)

				}
			}

			# fetch and bind data
			query = paste('{"', class.label, '": "', class.names[i], '"}', sep = "")
			data.fragment = conn$find(query, skip = bin.skip, limit = bin.limit)
			if (nrow(data.fragment) < bin.limit) {
				bin.limit = bin.limit - nrow(data.fragment)
				bin.skip = 0
				data.supplement = conn$find(query, skip = bin.skip, limit = bin.limit)
				data.fragment = rbind(data.fragment, data.supplement)
			}

			bin.data = rbind(bin.data, data.fragment)
			bin.means[[i]] = normalize(colMeans(data.fragment[, -class.number]))

		}
	}


	# classify
	if (model.algorithm == "c5.0") {
		model = C5.0(x = bin.data[, -class.number], y = as.factor(bin.data[, class.number]))
		probs = predict(model, data.test, type = "prob")
	}


	# normalize test data by row
	data.test = t(apply(data.test[, -class.number], 1, normalize))


	# compute average distance (bin.mean_Cx -> data.test[i])
	result = matrix(nrow = nrow(data.test), ncol = class.amount)
	for (i in 1:class.amount) {
		dist = apply(data.test[, -class.number], 1, eucDist, x2 = bin.means[[i]])
		dist = probs[, i] / (dist + 1)
		result[, i] = dist
	}
	colnames(result) = class.names


	# return result
	conn = mongo(paste("result_", bin.id, sep = ""), db.name)
	if (conn$count() > 0) conn$drop()
	conn$insert(as.data.frame(result))

	# close mongo connection
	rm(conn)

}

main()
