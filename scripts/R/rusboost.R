# credits to Stephen Carnagua
# https://github.com/SteveOhh/RUSBoost
# license: GNU General Public License

library("ROCR")
library("e1071")
library("C50")
library("rpart")

rusb <- function (formula, data, iters = 100, coeflearn = "Breiman", calg, sampleFraction, idx) {
	if (!(as.character(coeflearn) %in% c("Freund", "Breiman", "Zhu"))) {
		stop("coeflearn must be 'Freund', 'Breiman' or 'Zhu' ")
	}
	formula <- as.formula(formula)
	vardep <- data[, as.character(formula[[2]])]
	vardep <- vardep[[1]]
	n <- nrow(data)
	indices <- 1:n
	n.negative <- sum(idx)
	negatives <- data[idx,]
	nclasses <- nlevels(vardep)
	trees <- list()
	mweights <- rep(0, iters)

	# Initialize weights. Each 'w'[1:n] is an entry into the overall weights--matrix.weights[w, m].
	w <- rep(1/n, n)
	# Initialize weights matrix
	matrix.weights <- array(0, c(n, iters))

	################ This is where the model hypotheses are created
	for (m in 1:iters) {
		# create a subset index from the 1:n vector, using ALL "Y"s and a SAMPLE of "N"s
		subset.index <- c(sample(indices[idx], n.negative*sampleFraction, replace = FALSE), indices[!idx])
		# this is where the sample is subset in each iteration
		tmp.sample <- data[subset.index,]
		tmp.weights <- w[subset.index]
		t.s.l <- length(tmp.sample[,1])

		### Fit the model using classification alg.
		if (calg == "NB") {
			fit <- naiveBayes(x = tmp.sample[, -ncol(tmp.sample)], y = as.factor(tmp.sample[, ncol(tmp.sample)]))
			flearn <- predict(fit, data, type = "class")
		}
		if (calg == "C5.0") {
			fit <- C5.0(x = tmp.sample[, -ncol(tmp.sample)], y = as.factor(tmp.sample[, ncol(tmp.sample)]))
			flearn <- predict(fit, data, type = "class")
		}
		if (calg == "rpart") {
			inner.tmp.weights <<- tmp.weights
			fit <- rpart(formula = formula, data = tmp.sample, weights = inner.tmp.weights)
			flearn <- predict(fit, newdata = data, type = "class")
		}
		ind <- as.numeric(vardep != flearn)
		err <- as.numeric(w %*% ind)           

		# Compute this iteration's training error metric: c = f(total loss).
		c <- log((1 - err)/err)
		if (coeflearn == "Breiman") {
			c <- (1/2) * c
		}
		if (coeflearn == "Zhu") {
			c <- c + log(nclasses - 1)
		}

		### In the first time through (m=1), w is just 1/n for all obs. Later, a subset of w will have changed.
		matrix.weights[, m] <- w   

		### Key step: recalculate weights, using the same error penalty for each misclassified example
		# So what this does is take current weights and uses a function of them
		# to update the overall weights vector, for use in the next iteration.

		# This only applies to misclassified examples; properly identified ones stay the same.
		update.vector <- w * exp(c * ind)

		# Change the parts of the weight vector which need to be updated.
		w[ind==1] <- update.vector[ind==1]   


		#### Normalize weights once that's done (so the weights become proportions).
		w <- w/sum(w)
		maxerror <- 0.5
		eac <- 0.001
		if (coeflearn == "Zhu") {
			maxerror <- 1 - 1/nclasses
		}

		# Handle 
		# If the total loss is greater than .5, then an inverted hypothesis would work better.
		if (err >= maxerror) {
			weights <- rep(1/n, n)
			maxerror <- maxerror - eac
			c <- log((1 - maxerror)/maxerror)
			if (coeflearn == "Breiman") {
				c <- (1/2) * c
			}
			if (coeflearn == "Zhu") {
				c <- c + log(nclasses - 1)
			}
		}
		# If predictions are perfect, then c = is a constant -3.45...
		if (err == 0) {
			c <- log((1 - eac)/eac)
			if (coeflearn == "Breiman") {
				c <- (1/2) * c
			}
			if (coeflearn == "Zhu") {
				c <- c + log(nclasses - 1)
			}
		}

		# Model hypotheses are stored in 'trees' vector
		trees[[m]] <- fit
		# Models' weights are stored in 'mweights' vector
		mweights[m] <- c
	}
	################ end model hypotheses creation

	# Normalize model weights (so the weights become proportions)
	mweights <- mweights/sum(mweights)

	### simultaneously create 'ensemble' of predictions & variable importance array
	# initialize empty vectors
	pred <- data.frame(rep(0, n))
	#   nvar <- dim(varImp(trees[[1]], surrogates = FALSE, competes = FALSE))[1]
	nvar <- length(data[1,])-1 ##### replace this if I'm able to use the above line.
	imp <- array(0, c(iters, nvar))

	for (m in 1:iters) {
		# predictions
		if (m == 1) {
			pred <- predict(trees[[m]], data, type = "class")
		}
		else {
			pred <- data.frame(pred, predict(trees[[m]], data, type = "class"))
		}
		# importance statistics
		#     k <- varImp(trees[[m]], surrogates = FALSE, competes = FALSE)
		#     imp[m, ] <- k[sort(row.names(k)), ]
	}

	# derive final prediction from the above ensemble
	classfinal <- array(0, c(n, nlevels(vardep)))
	# for each possible class...
	for (i in 1:nlevels(vardep)) {
		# ...output a prediction score, which is a weighted combination of each models' prediction.
		classfinal[, i] <- matrix(as.numeric(pred == levels(vardep)[i]), nrow = n) %*% as.vector(mweights)
	}

	# 'votes' is the same info in 'classfinal', expressed as a proportion
	votes <- classfinal/apply(classfinal, 1, sum)

	# output one predicted class (the class with the largest share of weighted model votes)
	predclass <- rep("O", n)
	for (i in 1:n) {
		predclass[i] <- as.character(levels(vardep)[(order(classfinal[i,], decreasing = TRUE)[1])])
	}

	#   imphyp <- as.vector(as.vector(mweights) %*% imp)
	#   imphyp <- imphyp/sum(imphyp) * 100
	#   names(imphyp) <- sort(row.names(k))

	ans <- list(formula = formula, trees = trees, weights = mweights, votes = classfinal, prob = votes, class = predclass) #, 
	#               importance = imphyp)
	class(ans) <- "rusb"
	ans
}

predict.rusb <- function (object, newdata, newmfinal = length(object$trees), ...) {
	if (newmfinal > length(object$trees) | newmfinal < 1) stop("newmfinal must be 1<newmfinal<mfinal")
	formula <- object$formula
	vardep <- newdata[, as.character(object$formula[[2]])]
	n <- nrow(newdata)
	nclases <- nlevels(vardep)
	pesos <- rep(1/n, n)
	newdata <- data.frame(newdata, pesos)
	pond <- object$weights[1:newmfinal]
	pred <- data.frame(rep(0, n))
	for (m in 1:newmfinal) {
		if (m == 1) {
			pred <- predict(object$trees[[m]], newdata, type = "class")
		}
		else {
			pred <- data.frame(pred, predict(object$trees[[m]], newdata, type = "class"))
		}
	}
	classfinal <- array(0, c(n, nlevels(vardep)))
	for (i in 1:nlevels(vardep)) {
		classfinal[, i] <- matrix(as.numeric(pred == levels(vardep)[i]), 
		nrow = n) %*% pond
	}
	predclass <- rep("O", n)
	for (i in 1:n) {
		predclass[i] <- as.character(levels(vardep)[(order(classfinal[i, ], decreasing = TRUE)[1])])
	}
	table <- table(predclass, vardep, dnn = c("Predicted Class", "Observed Class"))
	error <- 1 - sum(predclass == vardep)/n
	votosporc <- classfinal/apply(classfinal, 1, sum)
	output <- list(formula = formula, votes = classfinal, prob = votosporc, class = predclass, confusion = table, error = error)
}

## Tests

files = c(
	"cleveland-0_vs_4.dat",
	"ecoli1.dat",
	"ecoli2.dat",
	"ecoli3.dat",
	"ecoli4.dat",
	"glass1.dat",
	"glass2.dat",
	"glass4.dat",
	"haberman.dat",
	"iris0.dat",
	"new-thyroid1.dat",
	"new-thyroid2.dat",
	"page-blocks-1-3_vs_4.dat",
	"poker-9_vs_7.dat",
	"shuttle-6_vs_2-3.dat",
	"shuttle-c2-vs-c4.dat",
	"winequality-white-9_vs_4.dat",
	"yeast-1_vs_7.dat"
)
calgs = c("NB", "C5.0")
iters = 10
reps = 30

results = matrix(c(0), nrow = length(files), ncol = (length(calgs)*2))

for (file in 1:length(files)) {
	dir = paste("datasets/", files[file], sep = "")
	dataset = read.table(dir, header=TRUE, dec=".", sep=",", strip.white = TRUE)
	class = sort(levels(dataset$Class))
	
	for (rep in 1:reps) {
		datasetTr = dataset[0,]
		datasetTe = dataset[0,]
		for (x in 1:length(class)) {
			sub = subset(dataset, dataset$Class == class[x])
			size = round(nrow(sub) * 0.7)
			rand = sample(1:nrow(sub), size)
			datasetTr = rbind(datasetTr, sub[rand,])
			datasetTe = rbind(datasetTe, sub[-rand,])
		}
		IR = (nrow(datasetTr[which(datasetTr$Class == class[2]),]) * 1.65) / nrow(datasetTr[which(datasetTr$Class == class[1]),])
		idx = datasetTr$Class == class[1]
		for (calg in 1:length(calgs)) {
			# Bench
			if (calgs[calg] == "NB") {
				model = naiveBayes(x = datasetTr[, -ncol(datasetTr)], y = as.factor(datasetTr[, ncol(datasetTr)]))
				probs = predict(model, datasetTe, type = "raw")
			}
			if (calgs[calg] == "C5.0") {
				model = C5.0(x = datasetTr[, -ncol(datasetTr)], y = as.factor(datasetTr[, ncol(datasetTr)]))
				probs = predict(model, datasetTe, type = "prob")
			}
			if (calg == "rpart") {
				model = rpart(Class ~ ., data = datasetTr)
				probs = predict(model, newdata = datasetTe, type = "prob")
			}
			pred = prediction(probs[, 2], as.numeric(as.factor(datasetTe$Class))-1)
			perf = performance(pred, "auc")
			results[file, calg] = results[file, calg] + as.numeric(slot(perf, "y.values")[1])
			# RUSBoost
			train = rusb(Class ~ ., data = datasetTr, iters = iters, coeflearn = "Breiman", calg = calgs[calg], sampleFraction = IR, idx)
			prd = predict.rusb(train, datasetTe, newmfinal = length(train$trees))
			# Compute AUC
			pred = prediction(prd$prob[, 2], as.numeric(as.factor(datasetTe$Class))-1)
			perf = performance(pred, "auc")
			results[file, (calg+length(calgs))] = results[file, (calg+length(calgs))] + as.numeric(slot(perf, "y.values")[1])
		}
	}
}

#######
results = results / reps
round(results, 2)
round(colMeans(results), 2)
