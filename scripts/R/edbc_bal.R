# args -> [file, database]
# ex. -> $ Rscript scripts/R/edbc_bal.R abalone19

# Load libraries
library("mongolite")
library("entropy")
library("C50")

# -- FEATURE SELECTION -- #

# Discrete probability distribution
DPD <- function(v, ...) {
   (count <- table(v, ..., dnn=NULL)) / sum(count)
}

# Mutual information
MI <- function(v1, v2) {
   p = DPD(v1, v2)
   p1 = rowSums(p)
   p2 = colSums(p)
   sum(p*log2(p/(p1%o%p2)), na.rm=TRUE)
}

# Symmetric uncertainty
SU <- function(v1, v2) {
   2 * MI(v1, v2) / (entropy.ChaoShen(v1) + entropy.ChaoShen(v2))
}

# Select relevant features
SF <- function(data) {
   threshold = 0
   su = c()
   for (x in 1:(ncol(data)-1)) {
      su[x] = SU(data[, x], as.numeric(as.factor(data[, ncol(data)])))
   }
   su = round(su, 4)
   su[length(su) + 1] = threshold + 0.1
   return(which(su > threshold))
}

# Irrelevant feature removal
IFR <- function(data, features) {
   return(data[, features])
}

# -- PROTOTYPE SELECTION -- #

Neighbors <- function(dists, eIdx, k) {
   as.integer(names(sort(dists[eIdx, -eIdx])[1:k]))
}

# Jarvis-Patric clustering
JPC <- function(data, class.name, class.value) {
   result = data[0,]
   sub = subset(data, data[[class.name]] == class.value)
   nrows = nrow(sub)
   opposite.count = nrow(data) - nrows
   ratio = nrows / nrow(data)

   # number of nearest neighbors
   k = floor(ratio * opposite.count)

   # minimal number of shared nearest neighbors
   threshold = floor(k * 0.20)

   # number of clusters ~ prototypes
   clusters.count = k - threshold

   # pre-allocate an empty list for clusters
   clusters = vector("list", clusters.count)
   
   # euclidean distance matrix
   dists = as.matrix(dist(sub[, -ncol(sub)], method = "euclidean", diag = FALSE, upper = FALSE, p = 2))
   
   progress = 0
   all = (nrows * (nrows-1)) / 2
   cat("~ JPC (", class.value, ") 0%", sep = "")

   for (y in 1:(nrows - 1)) {
      step = (y * nrows) / 2
      progress.new = round(step / all * 100)
      if (progress != progress.new) {
         cat("\r~ JPC (", class.value, ") ", progress.new, "%", sep = "")
         progress = progress.new
      }
      neighbors.e1 = Neighbors(dists, y, k)
      for (z in (y+1):nrows) {
         neighbors.e2 = Neighbors(dists, z, k)
         snn = sum(table(c(neighbors.e1, neighbors.e2)) == 2)
         if (snn > threshold) {
            cluster.id = snn - threshold
            if (!(y %in% clusters[[cluster.id]])) {
               clusters[[cluster.id]] = c(clusters[[cluster.id]], y)
            }
            if (!(z %in% clusters[[cluster.id]])) {
               clusters[[cluster.id]] = c(clusters[[cluster.id]], z)
            }
         }
      }
   }
   cat("\n", sep = "")

   # compute prototypes: prototype_x = mean(cluster_x)
   for (y in 1:clusters.count) {
      cluster = sub[clusters[[y]],]
      if (nrow(cluster) > 0) {
         row = data[0,]
         row[1, ncol(row)] = class.value
         row[1, -ncol(row)] = colMeans(cluster[, -ncol(cluster)])
         result = rbind(result, row)
      }
   }

   return(result)
}

# -- DISSIMILARITY TRANSFORMATION -- #

EucDist <- function(x1, x2) sqrt(sum((x1 - x2) ^ 2))

DT <- function(data, prototypes) {
   result = data.frame()
   for (x in 1:nrow(data)) {
      for (y in 1:nrow(prototypes)) {
         result[x, y] = EucDist(data[x, -ncol(data)], prototypes[y, -ncol(prototypes)])
      }
      result[x, (nrow(prototypes) + 1)] = as.character(data[x, ncol(data)])
   }
   return(result)
}

Group <- function(data, groups) {
   list = split(data[, -ncol(data)], as.factor(1:groups))
   result = data.frame()
   for (x in 1:length(list)) {
      group = list[[x]]
      result = rbind(result, colMeans(group))
   }
   result = cbind(result, rep(data[1, ncol(data)], nrow(result)))
   colnames(result) = colnames(data)
   return(result)
}

# -- TESTS -- #

Tests <- function(db.name) {

   split = c("train", "test")

   # open mongo connection
   collname = paste(db.name, "_", split[2], sep="")
   conn = mongo(collname, db.name)
   testdata = conn$find()
   class.number = ncol(testdata)
   class.name = colnames(testdata)[class.number]
   class.values = sort(conn$distinct(class.name))
   collname = paste(db.name, "_", split[1], sep="")
   conn = mongo(collname, db.name)
   traindata = conn$find()

   # Irrelevant feature removal: remove features below relevant threshold
   features = SF(traindata)
   cat("~ Irrelevant features (", ncol(traindata) - length(features), ") selected: ", sep = "")
   cat(colnames(traindata[, -features]), sep = ", ")
   cat("\n~ Relevant features (", length(features), ") are: ", sep = "")
   cat(colnames(traindata[, features]), sep = ", ")
   datasetR = IFR(traindata, features)
   writeLines("\n~ Train data reduced")

   # Prototype selection: Jarvis-Patric clustering
   datasetP = JPC(datasetR, class.name, class.values[1])
   datasetP = rbind(datasetP, JPC(datasetR, class.name, class.values[2]))
   #datasetP = rbind(datasetP, subset(datasetR, datasetR[[class.name]] == class.values[2]))
   writeLines("~ Prototypes selected")

   # Dissimilarity transformation
   datasetD = DT(datasetR, datasetP)
   writeLines("~ Dissimilarity matrix obtained")
   
   # Group balance
   datasetD = rbind(
      Group(
         subset(datasetD, datasetD[, ncol(datasetD)] == class.values[1]),
         nrow(subset(datasetR, datasetR[[class.name]] == class.values[2]))
      ),
      subset(datasetD, datasetD[, ncol(datasetD)] == class.values[2])
   )
   
   # New data reduction
   datasetRn = IFR(testdata, features)
   writeLines("~ Test data reduced")

   # New data dissimilarity transformation
   datasetDt = DT(datasetRn, datasetP)
   writeLines("~ Test data dissimilarity matrix obtained")

   # Build model & get probabilities
   model = C5.0(as.factor(datasetD[, ncol(datasetD)]) ~ ., data = datasetD[, -ncol(datasetD)])
   writeLines("~ Model built")

   probs = predict(model, datasetDt[, -ncol(datasetDt)], type = "prob")
   writeLines("~ Predictions obtained")
   
   # Insert results into database
   conn = mongo("edbc", db.name)
   if(conn$count() > 0) conn$drop()
   conn$insert(as.data.frame(probs))
   cat("~ Results inserted into:", db.name, "-> edbc\n")

   # close mongo connection
   rm(conn)
}
   

# -- RUN TESTS -- #
args = commandArgs()
db.name = args[6]

Tests(db.name)
