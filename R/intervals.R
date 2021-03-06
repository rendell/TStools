##### *This function constructs intervals for the given data* #####
intervals <- function(data,intType=c("standard","2sd","hm","mad","qr"),centre=NULL,
                      level=0.95,df=NULL,k=NULL){
# Default centre = mean(data)
# k is number of parameters of model, needed in order to estimate df correctly.

    intType <- substr(intType[1],1,1);

#### {If matrix is provided} ####
    if(is.matrix(data)){
        nCols <- ncol(data);
        nObs <- nrow(data);
        upper <- lower <- rep(NA,nCols);
        if(is.null(centre)){
            centre <- colMeans(data);
        }
        else if(length(centre)!=nCols){
            centre <- rep(centre[1],nCols);
        }
        centre <- matrix(centre,nObs,nCols,byrow=TRUE);
#### Standard intervals ####
        if(intType=="s"){
            if(is.null(df)){
                if(is.null(k)){
                    k <- 1;
                }
                df <- nObs - k;
            }
            quantValues <- qt(c((1-level)/2,(1+level)/2),df=df);
            variances <- apply((data-centre)^2,2,sum,na.rm=TRUE)/df;
            lower <- centre + quantValues[1] * sqrt(variances);
            upper <- centre + quantValues[2] * sqrt(variances);
        }
#### 2 sd intervals ####
        else if(intType=="2"){
            nLeft <- colSums(data<centre);
            nRight <- colSums(data>centre);
            if(is.null(df)){
                if(is.null(k)){
                    k <- 1;
                }
                df <- rbind(nLeft-k*nLeft/nObs,nRight-k*nRight/nObs);
            }
            quantValues <- qt(c((1-level)/2,(1+level)/2),df=df);
            variances <- matrix(NA,2,nCols);
            variances[1,] <- apply(((data-centre)^2)*(data<centre),2,sum,na.rm=TRUE)/df[1,];
            variances[2,] <- apply(((data-centre)^2)*(data>centre),2,sum,na.rm=TRUE)/df[2,];
            lower <- centre + quantValues[1,] * sqrt(variances[1,]);
            upper <- centre + quantValues[2,] * sqrt(variances[2,]);
        }
#### hm with centre intervals ####
        else if(intType=="h"){
            if(is.null(df)){
                if(is.null(k)){
                    k <- 1;
                }
                df <- nObs - k;
            }
            hsmN <- gamma(0.75)*pi^(-0.5)*2^(-0.75);
            quantValues <- qt(c((1-level)/2,(1+level)/2),df=df);
            hmValues <- apply(data-centre,2,hm,C=0);
            lower <- centre + quantValues[1] * Im(hmValues)^2 / hsmN^2;
            upper <- centre + quantValues[2] * Re(hmValues)^2 / hsmN^2;
        }
#### MAD intervals ####
        else if(intType=="m"){
            nLeft <- colSums(data<centre);
            nRight <- colSums(data>centre);
            if(is.null(df)){
                if(is.null(k)){
                    k <- 1;
                }
                df <- rbind(nLeft-k*nLeft/nObs,nRight-k*nRight/nObs);
            }
            quantValues <- qt(c((1-level)/2,(1+level)/2),df=df);
            variances <- matrix(NA,2,nCols);
            variances[1,] <- apply((abs(data-centre))*(data<centre),2,sum,na.rm=TRUE)/df[1,];
            variances[2,] <- apply((abs(data-centre))*(data>centre),2,sum,na.rm=TRUE)/df[2,];
            lower <- centre + quantValues[1,] * variances[1,] / 0.798;
            upper <- centre + quantValues[2,] * variances[2,] / 0.798;
        }
        else if(intType=="q"){
            QFunction <- function(C,alpha){
                values <- C[1]*t^C[2]
                return((1-alpha)*sum(abs(data[data<values]-values))+alpha*sum(abs(data[data<values]-values)));
            }
            t <- matrix(c(1:nCols),byrow=TRUE,nrow=nObs,ncol=nCols);
            C <- rep(1,2);
            res1 <- nlminb(C,QFunction,alpha=(1-level)/2);
            res2 <- nlminb(C,QFunction,alpha=(1+level)/2);
            lower <- res1$par[1]*t^res1$par[2];
            upper <- res2$par[1]*t^res2$par[2]
        }
    }
#### {Only 1 series} ####
    else{
        nObs <- length(data);
        if(is.null(centre)){
            centre <- mean(data,na.rm=TRUE);
        }
#### Standard method ####
        if(intType=="s"){
            if(is.null(df)){
                if(is.null(k)){
                    k <- 1;
                }
                df <- nObs - k;
            }
            quantValues <- qt(c((1-level)/2,(1+level)/2),df=df);
            variances <- sum((data-centre)^2,na.rm=TRUE)/df;
            lower <- centre + quantValues[1] * sqrt(variances);
            upper <- centre + quantValues[2] * sqrt(variances);
        }
#### 2 sd method ####
        else if(intType=="2"){
            nLeft <- sum(data<centre);
            nRight <- sum(data>centre);
            if(is.null(df)){
                if(is.null(k)){
                    k <- 1;
                }
                df <- c(nLeft-k*nLeft/nObs,nRight-k*nRight/nObs);
            }
            quantValues <- qt(c((1-level)/2,(1+level)/2),df=df);
            variances <- rep(NA,2);
            variances[1] <- sum(((data-centre)^2)*(data<centre),na.rm=TRUE)/df[1];
            variances[2] <- sum(((data-centre)^2)*(data>centre),na.rm=TRUE)/df[2];
            lower <- centre + quantValues[1] * sqrt(variances[1]);
            upper <- centre + quantValues[2] * sqrt(variances[2]);
        }
#### hm intervals ####
        else if(intType=="h"){
            if(is.null(df)){
                if(is.null(k)){
                    k <- 1;
                }
                df <- nObs - k;
            }
            hsmN <- gamma(0.75)*pi^(-0.5)*2^(-0.75);
            quantValues <- qt(c((1-level)/2,(1+level)/2),df=df);
            hmValues <- hm(data,C=centre)*nObs/df;
            lower <- centre + quantValues[1] * Im(hmValues)^2 / hsmN^2;
            upper <- centre + quantValues[2] * Re(hmValues)^2 / hsmN^2;
        }
#### MAD method ####
        else if(intType=="m"){
            nLeft <- sum(data<centre);
            nRight <- sum(data>centre);
            if(is.null(df)){
                if(is.null(k)){
                    k <- 1;
                }
                df <- c(nLeft-k*nLeft/nObs,nRight-k*nRight/nObs);
            }
            quantValues <- qt(c((1-level)/2,(1+level)/2),df=df);
            variances <- rep(NA,2);
            variances[1] <- sum((abs(data-centre))*(data<centre),na.rm=TRUE)/df[1];
            variances[2] <- sum((abs(data-centre))*(data>centre),na.rm=TRUE)/df[2];
            lower <- centre + quantValues[1] * variances[1] / 0.798;
            upper <- centre + quantValues[2] * variances[2] / 0.798;
        }
        else if(intType=="q"){
            QFunction <- function(C,alpha){
                return((1-alpha)*sum(abs(data[data<C]-C))+alpha*sum(abs(data[data>C]-C)));
            }
            res1 <- nlminb(median(data),QFunction,alpha=(1-level)/2);
            res2 <- nlminb(median(data),QFunction,alpha=(1+level)/2);
            lower <- res1$par;
            upper <- res2$par;
        }
    }
    return(list(lower=lower,upper=upper));
}

##### *This function simulates data and constructs intervals* #####
intervalsSimulator <- function(randomizer=c("norm","lnorm","pois","unif","t","beta"),
                               centre=c("mean","median","ham"),
                               obs=1000,level=0.95,silent=FALSE,...){
    randomizer <- randomizer[1];
    centre <- centre[1];
    
    hamCF <- function(C,x){
        valueCF <- mean(sqrt(abs(x-C)));
        return(valueCF);
    }

    if(all(randomizer!=c("norm","lnorm","pois","unif","t","beta"))){
        stop("Unknown randomizer!");
    }
    
    if(all(centre!=c("mean","median","ham"))){
        stop("Unknown centre!");
    }

    if(length(list(...))!=0){
        x <- eval(parse(text=paste0("r",randomizer,"(",obs,",",paste0(list(...),collapse=","),")")));
        quantA <- eval(parse(text=paste0("q",randomizer,"(c(",(1-level)/2,",",(1+level)/2,"),",paste0(list(...),collapse=","),")")));
    }
    else{
        if(any(randomizer==c("norm","lnorm"))){
            x <- eval(parse(text=paste0("r",randomizer,"(",obs,",",0,",",1,")")));
            quantA <- eval(parse(text=paste0("q",randomizer,"(c(",(1-level)/2,",",(1+level)/2,"),",0,",",1,")")));
        }
        else if(randomizer=="unif"){
            x <- eval(parse(text=paste0("r",randomizer,"(",obs,",",0,",",10,")")));
            quantA <- eval(parse(text=paste0("q",randomizer,"(c(",(1-level)/2,",",(1+level)/2,"),",0,",",10,")")));
        }
        else if(randomizer=="pois"){
            x <- eval(parse(text=paste0("r",randomizer,"(",obs,",",2,")")));
            quantA <- eval(parse(text=paste0("q",randomizer,"(c(",(1-level)/2,",",(1+level)/2,"),",2,")")));
        }
        else if(randomizer=="t"){
            x <- eval(parse(text=paste0("r",randomizer,"(",obs,",",15,")")));
            quantA <- eval(parse(text=paste0("q",randomizer,"(c(",(1-level)/2,",",(1+level)/2,"),",15,")")));
        }
        else if(randomizer=="beta"){
            x <- eval(parse(text=paste0("r",randomizer,"(",obs,",",0.5,",",0.5,")")));
            quantA <- eval(parse(text=paste0("q",randomizer,"(c(",(1-level)/2,",",(1+level)/2,"),",0.5,",",0.5,")")));
        }
    }

    if(centre=="mean"){
        centre <- mean(x);
    }
    else if(centre=="median"){
        centre <- median(x);
    }
    else{
        centre <- nlminb(median(x),hamCF,x=x)$par;
    }

    methodsNames <- c("Standard","2 SD","HM","MAD");
    nMethods <- length(methodsNames);
    
    quant <- matrix(NA,2,nMethods,dimnames=list(c("lower","upper"),methodsNames));
    quant[,1] <- unlist(intervals(x,intType="s",centre=centre,level=level));
    quant[,2] <- unlist(intervals(x,intType="2",centre=centre,level=level));
    quant[,3] <- unlist(intervals(x,intType="h",centre=centre,level=level));
    quant[,4] <- unlist(intervals(x,intType="m",centre=centre,level=level));
    
    quant <- cbind(quant,quantA);
    colnames(quant)[nMethods+1] <- "Theoretical";
    
    ### Overall coverage ####
    coverage <- rep(NA,nMethods);
    names(coverage) <- methodsNames;
    coverage[1] <- sum((x < quant[2,1]) & x > quant[1,1])/obs;
    coverage[2] <- sum((x < quant[2,2]) & x > quant[1,2])/obs;
    coverage[3] <- sum((x < quant[2,3]) & x > quant[1,3])/obs;
    coverage[4] <- sum((x < quant[2,4]) & x > quant[1,4])/obs;
    
    #### Distances ####
    distances <- matrix(NA,3,nMethods,dimnames=list(c("lower","upper","overall"),methodsNames));
    distances[1:2,1] <- abs(quantA - quant[,1]);
    distances[1:2,2] <- abs(quantA - quant[,2]);
    distances[1:2,3] <- abs(quantA - quant[,3]);
    distances[1:2,4] <- abs(quantA - quant[,4]);
    distances[3,] <- colMeans(distances[1:2,]);
    
    #### Width of intervals ####
    width <- coverage;
    width[1] <- quant[2,1] - quant[1,1];
    width[2] <- quant[2,2] - quant[1,2];
    width[3] <- quant[2,3] - quant[1,3];
    width[4] <- quant[2,4] - quant[1,4];
    
    if(!silent){
        #### Histogram ####
        hist(x,breaks="FD")
        abline(v=quant[1,1],col="red")
        abline(v=quant[2,1],col="red")
        abline(v=quant[1,2],col="blue")
        abline(v=quant[2,2],col="blue")
        abline(v=quant[1,3],col="darkgreen")
        abline(v=quant[2,3],col="darkgreen")
        abline(v=quant[1,4],col="purple")
        abline(v=quant[2,4],col="purple")
        abline(v=quantA[1],col="orange",lwd=2)
        abline(v=quantA[2],col="orange",lwd=2)
        abline(v=centre,col="darkgray",lwd=2)
        legend("topright",legend=c("Standard","2 SD","HM","MAD","Theoretical","Centre"),
               col=c("red","blue","darkgreen","purple","orange","darkgray"),lwd=c(rep(1,4),2,2))
    }
    
    return(structure(list(coverage=coverage,distances=distances,width=width,quant=quant),class="intervalStuff"));
}

##### *This function prints output of intervalsSimulator* #####
print.intervalStuff <- function(x,...){
    cat("Overal coverage: \n");
    print(x$coverage);
    
    cat("\nDistances: \n");
    print(x$distances);
    
    cat("\nWidth: \n");
    print(x$width);
    
    cat("\nQuantiles: \n");
    print(x$quant);
}