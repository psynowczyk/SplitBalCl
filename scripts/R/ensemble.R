 # args -> [file, database, subset number, subset number, strategy (max || sum)]
 # ex. -> $ Rscript scripts/R/ensemble.R yeast6 1 2 sum

 # load libraries
library("mongolite")

 # initial variables
args = commandArgs()
db.name = args[6];
bin.number = c(as.numeric(args[7]), as.numeric(args[8]));
strategy = args[9];
conn = mongo(paste(db.name, "_test", sep=""), db.name)
testdata = conn$find()

 # read result seubsets from database
for (index in 1:(length(bin.number))) {
	bin.name = paste("bin_", bin.number[index], sep="")
	 # try to read ens subset, else read result subset
	conn = mongo(paste("ens_", bin.number[index], sep=""), db.name)
	if (conn$count() == 0) conn = mongo(paste("result_", bin.number[index], sep=""), db.name)
	 # check if subset exists, else die
	stopifnot (conn$count() > 0)
	bin = conn$find()
	assign(bin.name, bin)
}
rm(bin)

 # apply strategy
if (strategy == "sum") {
	result = eval(as.name(paste("bin_", bin.number[1], sep=""))) + eval(as.name(paste("bin_", bin.number[2], sep="")))
}
if (strategy == "max") {
	result = pmax(eval(as.name(paste("bin_", bin.number[1], sep=""))), eval(as.name(paste("bin_", bin.number[2], sep=""))))
}
if (strategy == "min") {
	result = pmin(eval(as.name(paste("bin_", bin.number[1], sep=""))), eval(as.name(paste("bin_", bin.number[2], sep=""))))
}
if (strategy == "pro") {
	result = eval(as.name(paste("bin_", bin.number[1], sep=""))) * eval(as.name(paste("bin_", bin.number[2], sep="")))
}

 # return result
conn = mongo(paste("ens_", bin.number[1], sep = ""), db.name)
if (conn$count() > 0) conn$drop()
conn$insert(as.data.frame(result))

 # close mongo connection
rm(conn)
