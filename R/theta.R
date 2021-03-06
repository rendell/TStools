theta <- function(y,m=NULL,h=10,outplot=0,sign.level=0.05,
                  cost0=c("MSE","MdSE","MAE","MdAE"),
                  cost2=c("MSE","MdSE","MAE","MdAE"),
                  costs=c("MSE","MdSE","MAE","MdAE"),
                  multiplicative=c(TRUE,FALSE),cma=NULL,
                  outliers=NULL){
# Theta method 
# This implementation of Theta method tests automatically for seasonality and trend.
# Seasonal decomposition can be done either additively or multiplicatively and the seasonality
# is treated as a pure seasonal model. The various components of Theta can be optimised 
# using different cost functions. The originally proposed Theta method always assume 
# multiplicative seasonality and presence of trend, while all theta lines are optimised 
# using MSE. Seasonality is estimated using classical decomposition.
#
# Inputs
#   y               Time series to model. Can be either a vector or a ts object
#   m               Periods in a season of the time series. If insample is a ts object then 
#                   this is taken from its frequency, unless overriden. 
#   h               Forecast horizon. Default is 10.
#   outplot         Provide plot:
#                     0: No plot
#                     1: Series and forecast
#                     2: As above with theta lines
#   sign.level      Significance level for trend and seasoanlity statistical tests.
#   cost0           Cost function of theta0 line.
#   cost2           Cost function of theta2 line.
#   costs           Cost function of seasonal element. 
#                   Costs may be: MSE, MdSE, MAE, MdAE.
#   multiplicative  If TRUE then multiplicative decomposition is performed. 
#                   Otherwise additive is used.
#   cma             Input pre-calculated centred moving average. 
#                   Use NULL to calculate internally.
#   outliers        Optional. Provide vector of location of observations that are considered outliers.
#                   These will be included in theta0 estimation. To consider no outliers then use NULL.
#
# Output
#   frc         Forecasts.
#   exist       exist[1] is the result for trend, exist[2] is for season.
#   theta0      Forecasted values of theta0 line.
#   theta2      Forecasted values of theta2 line.
#   season      Forecasted values of seasonal element.
#   a           SES parameters of theta2.
#   b           Regression parameters of theta0.
#   p           Coefficients of outliers from theta0 and theta2 estimation.
#   g           Pure seasonal exponential smoothing parameters of season.
#
# Example:
#   theta(referrals,outplot=2)
#  
# Nikolaos Kourentzes, 2014 <nikolaos@kourentzes.com>

  # Defaults
  cost0 <- cost0[1]
  cost2 <- cost2[1]
  costs <- costs[1]
  multiplicative <- multiplicative[1]
  
  n <- length(y)
  
  # Get m (seasonality)
  if (is.null(m)){
    if (class(y) == "ts"){
      m <- frequency(y)
    } else {
      stop("Seasonality not defined (y not ts object).")
    }
  }
  
  # Check if CMA is given
  if (!is.null(cma)){
    if (n != length(cma)){
      stop("Length of series and cma do not match.")
    }
  } else {
    # Calculate CMA
    cma <- cmav(y,ma=m,outplot=0,fast=TRUE)
  }
  
  # Test for trend
  trend.exist <- coxstuart(cma)$p.value <= sign.level/2
  
  # Get seasonal matrix and test for seasonality
  if (m>1 && (length(y)/m)>=2){
    k <- m - (n %% m)
    if (multiplicative == TRUE){
      ynt <- y / cma
    } else {
      ynt <- y - cma
    }
    k <- m - (n %% m)
    ynt <- c(as.vector(ynt),rep(NA,times=k))
    ns <- length(ynt)/m
    ynt <- matrix(ynt,nrow=ns,ncol=m,byrow=TRUE)
    season.exist <- friedman.test(ynt)$p.value <= sign.level 
  } else {
    season.exist <- FALSE
  }
  
  # If seasonality exist then decompose 
  if (season.exist == TRUE){
    # y.des <- y/rep(ynt,ceiling(n/m)+1)[1:n]
    y.des <- cma
  } else {
    y.des <- y
  }
  
  # Create theta lines
  
  # Include in theta0 outliers if any provided
  if (is.null(outliers)){
    X.out <- NULL
    n.out <- 0
  } else {
    n.out <- length(outliers)
#     X.out <- array(0,c(n,n.out))
#     X.out[outliers+n*(0:(n.out-1))] <- 1
    # Through the MA the outlier is spread across m observations, create dummies to account for that
    m.half <- floor((m + (m+1) %% 2)/2)
    X.out <- array(0,c(n,n.out))
    for (i in 1:n.out){
      X.out[max(1,outliers[i]-m.half):min(n,outliers[i]+m.half),i] <- 1
    }
  }
  # Include trend component in theta0
  if (trend.exist == TRUE){
    X.trend <- matrix(c(1:n), nrow=n, ncol=1)
  } else {
    X.trend <- NULL
  }
  X <- cbind(matrix(1,nrow=n,ncol=1),X.trend,X.out)
  
#   if (trend.exist == TRUE || !is.null(outliers)){
  if ((n.out + trend.exist)>=1){
    b0 <- solve(t(X)%*%X)%*%t(X)%*%y.des # Initialise theta0 parameters
    b <- opt.trnd(y.des,X,cost0,b0)      # Optimise theta0
  } else {
    # If no trend then theta0 is just a mean
    b <- mean(y.des)
  }

  # Create theta0 line without outliers
  # 0*y.des To take ts object properties
  theta0 <- X[,1:(1+trend.exist)]%*%matrix(b[1:(1+trend.exist)],ncol=1) + 0*y.des               
  
  # Estimate SES
  theta2 <- 2*y.des - theta0              # Construct theta2 
  a0 <- rbind(0.1,theta2[1],rep(0,n.out)) # Initialise theta2 parameters
  a <- opt.ses(theta2,cost2,a0,2,X.out)   # Optimise theta2 
  
  # In-sample fit
  in.theta0 <- theta0
  in.theta2 <- fun.ses(theta2,a,X.out)$ins
  if (!is.null(X.out)){
    # Remove outlier from fit - the complete outlier will be modelled afterwards
    in.theta2 <- in.theta2 - X.out %*% matrix(a[3:(2+n.out)])
  }
  in.fit <- (in.theta0 + in.theta2)/2
  
  # Separate theta0 and theta2 parameters into a, b and outliers (p[,1:2])
  if (n.out > 0){
    p <- matrix(b[(2+trend.exist):(1+trend.exist+n.out)],nrow=n.out)
    p <- cbind(p,a[3:(2+n.out)])
    colnames(p) <- c('Theta0','Theta2')
  } else {
    p <- NULL
  }
  if (trend.exist == FALSE){
    b <- rbind(b[1], 0)
  } else {
    b <- b[1:2]
  } 
  b <- matrix(b,ncol=1)
  a <- matrix(a[1:2],ncol=1)

  # Prediction
  frc.theta0 <- b[1] + b[2]*((n+1):(n+h))
  if (!is.null(X.out)){
    a.frc <- rbind(a,array(p[,2],c(n.out,1)))
  } else {
    a.frc <- a
  }
  frc.theta2 <- fun.ses(theta2,a.frc,X.out)$outs * rep(1,h)
  frc <- (frc.theta0 + frc.theta2)/2
  
  # Convert to ts object
  if (class(y) == "ts"){
    s <- end(y)
    if (length(s)==2){
      if (s[2]==m){
        s[1] <- s[1]+1
        s[2] <- 1
      } else {
        s[2] <- s[2]+1
      }
    } else {
      s <- s + 1/m
    }
    frc <- ts(frc,start=s,frequency=m)  
  } 

  # Reseasonalise
  if (season.exist == TRUE){
    # Seasonality is modelled with a pure seasonal smoothing
    sout <- opt.sfit(ynt,costs,n,m,y,in.fit,multiplicative,outliers)
    season <- sout$season
    # sstd <- sd(season)
    season <- rep(season, h %/% m + 1)[1:h]
    g <- sout$g
    if (n.out > 0){
      p <- cbind(p,matrix(sout$p,ncol=1,dimnames=list(NULL,'Season')))
    }
    # sout$in.season includes the outlier
    if (multiplicative == TRUE){
      frc <- frc * season
      in.fit <- in.fit * sout$in.season
    } else {
      frc <- frc + season
      in.fit <- in.fit + sout$in.season
    }
  } else {
    g <- NULL
    season <- NULL
    # sstd <- NULL
  }

  if (outplot==1){
    # Simple in-sample and forecast
    if (class(y) == "ts"){
      ts.plot(y,frc,gpars=list(col=c("black","blue"),lwd=c(1,2)))
    } else {
      ymin <- min(min(y),min(frc))
      ymax <- max(min(y),max(frc))
      yminmax <- c(ymin-0.1*(ymax-ymin),ymax+0.1*(ymax-ymin))
      plot(1:n,y,type="l",xlim=c(1,(n+h)),ylab="",xlab="Time",ylim=yminmax)
      lines((n+1):(n+h),frc,col="blue",type="l",lwd=2)
    }
  } 
  
  if (outplot==2){
    # As previous, including theta lines
    if (class(y) == "ts"){
      s <- end(y)
      s <- end(y)
      if (length(s)==2){
        if (s[2]==m){
          s[1] <- s[1]+1
          s[2] <- 1
        } else {
          s[2] <- s[2]+1
        }
      } else {
        s <- s + 1/m
      }
      frc.theta0 <- ts(frc.theta0,start=s,frequency=m)  
      frc.theta2 <- ts(frc.theta2,start=s,frequency=m)  
      ts.plot(y,in.theta0+y*0,frc.theta0,in.theta2+y*0,frc.theta2,frc,in.fit,
              gpars=list(col=c("black","forestgreen","forestgreen","red","red","blue","blue"),
                         lwd=c(1,1,1,1,1,2,1),lty=c(1,1,2,1,2,1,1)))
    } else {
    ymin <- min(min(y),min(theta0),min(theta2),min(frc),min(frc.theta0),min(frc.theta2))
    ymax <- max(min(y),max(theta0),max(theta2),max(frc),max(frc.theta0),max(frc.theta2))
    yminmax <- c(ymin-0.1*(ymax-ymin),ymax+0.1*(ymax-ymin))
    plot(1:n,y,type="l",xlim=c(1,(n+h)),ylab="",xlab="Time",ylim=yminmax)
    lines(1:n,in.theta0,col="forestgreen",type="l")
    lines(1:n,in.theta2,col="red",type="l")
    lines((n+1):(n+h),frc.theta0,col="forestgreen",type="l",lty=2)
    lines((n+1):(n+h),frc.theta2,col="red",type="l",lty=2)
    lines((n+1):(n+h),frc,col="blue",type="l",lwd=2)
    lines(1:n,in.fit,col="blue",lwd=1)
    }
  }
  
  # Prepare output
  exist <- rbind(trend.exist,season.exist)
  rownames(exist) <- c("Trend","Season")
  rownames(a) <- c("Alpha","Initial level")
  rownames(b) <- c("Intercept","Slope")
  if (season.exist==TRUE){
    g <- matrix(g,nrow=1,ncol=m+1)
    colnames(g) <- c("Gamma",paste("s",1:m,sep=""))
  }
  costf <- rbind(cost0,cost2,costs)
  rownames(costf) <- c("Theta0","Theta2","Seasonal")
  return(list("frc"=frc,"exist"=exist,"theta0"=frc.theta0,"theta2"=frc.theta2,
              "season"=season,"cost"=costf,"a"=a,"b"=b,"p"=p,"g"=g, "fit"=in.fit)) # ,"std.season"=sstd))
  
}

opt.sfit <- function(ynt,costs,n,m,y,in.fit,multiplicative,outliers){
  # Optimise pure seasonal model and predict out-of-sample seasonality
  if (is.null(outliers)){
    g0 <- c(0.001,colMeans(ynt,na.rm=TRUE))       # Initialise seasonal model
    season.sample <- matrix(t(ynt),ncol=1)        # Transform back to vector
    season.sample <- season.sample[!is.na(season.sample)]
    X.out <- NULL
    n.out <- 0
  } else {
    n.out <- length(outliers)
    g0 <- c(0.001,colMeans(ynt,na.rm=TRUE),rep(0,n.out))       # Initialise seasonal model
    if (multiplicative == TRUE){
      season.sample <- as.numeric(y / in.fit)
    } else {
      season.sample <- as.numeric(y - in.fit)
    }
    X.out <- array(0,c(n,n.out))
    X.out[outliers+n*(0:(n.out-1))] <- 1
  }
  opt <- optim(par=g0, cost.sfit, method = "Nelder-Mead", season.sample=season.sample, 
               cost=costs, n=n, m=m, X.out = X.out, control = list(maxit = 2000))
  g <- opt$par
  sfit <- fun.sfit(season.sample,g,n,m,X.out)
  out.season <- sfit$outs
  in.season <- sfit$ins
  # Size of outliers
  if (n.out > 0){
    p <- g[(m+2):(m+1+n.out)]
  } else {
    p <- NULL
  }
  return(list("season"=out.season,"in.season"=in.season,"g"=g[1:(1+m)],"p"=p))
}

fun.sfit <- function(season.sample,g,n,m,X.out){
  # Fit pure seasonal model
  s.init <- g[2:(m+1)]
  season.fit <- c(s.init,rep(NA,n))
  for (i in 1:n){
    season.fit[i+m] <- season.fit[i] + g[1]*(season.sample[i] - season.fit[i])
  }
  if (!is.null(X.out)){
    n.out <- length(X.out[1,])
    g.out <- matrix(g[(m+2):(m+1+n.out)],ncol=1)
    X.out <- rbind(X.out, array(0,c(m,n.out)))
    season.fit <- season.fit + X.out %*% g.out
  }
  return(list("ins"=season.fit[1:n],"outs"=season.fit[(n+1):(n+m)]))  
}

cost.sfit <- function(g,season.sample,cost,n,m,X.out){
  # Cost function of pure seasonal model
  err <- season.sample-fun.sfit(season.sample,g,n,m,X.out)$ins
  err <- cost.err(err,cost,NULL)
  if (g[1]<0 | g[1]>1){
    err <- 9*10^99
  }
  return(err)   
}

fun.ses <- function(line,a,X.out=NULL){
  # Fit SES model on theta line
  n <- length(line)
  ses <- matrix(NA,nrow=n+1,ncol=1)
  ses[1] <- a[2]
  for (i in 2:(n+1)){
    ses[i] <- a[1]*line[i-1] + (1-a[1])*ses[i-1]
  }
  # If X.out is !null then model outliers
  if (!is.null(X.out)){
    n.out <- length(X.out[1,])
    a.out <- matrix(a[3:(n.out+2)],ncol=1)
    X.out <- rbind(X.out, array(0,c(1,n.out)))
    ses <- ses + X.out %*% a.out
  }
  return(list("ins"=ses[1:n],"outs"=ses[n+1]))
}

opt.ses <- function(line,cost,a0,theta,X.out=NULL){
  # Optimise SES on theta
  opt <- optim(par=a0, cost.ses, method = "Nelder-Mead", line=line, cost=cost, 
               theta=theta, X.out=X.out, control = list(maxit = 2000))
  a <- opt$par
  return(a)
}

cost.ses <- function(a,line,cost,theta=2,X.out=NULL){
  # Cost function for SES optimisation
  err <- line-fun.ses(line,a,X.out)$ins
  err <- cost.err(err,cost,theta)
  if (!a[1]<0.99 | !a[1]>0.01){
    err <- 9*10^99
  }
  return(err)
}

opt.trnd <- function(y,X,cost,b0){
  # Optimise theta line 0
  opt <- optim(par=b0, cost.trnd, method = "Nelder-Mead", y=y, X=X, 
               cost=cost, control = list(maxit = 2000))
  b <- opt$par
  return(b)
}

cost.trnd <- function(b,y,X,cost){
  # Theta 0 cost function
  err <- y-X%*%b
  err <- cost.err(err,cost,NULL)
  return(err)
}

cost.err <- function(err,cost,theta=NULL){
  # Cost calculation
  if (cost == "MAE"){
    err <- mean(abs(err))
  }
  if (cost == "MdAE"){
    err <- median(abs(err))
  }
  if (cost == "MSE"){
    err <- mean((err)^2)
  }
  if (cost == "MdSE"){
    err <- median((err)^2)
  }
  if (cost == "MTE"){
    err <- mean(abs((err)^theta))
  }
  if (cost == "MdTE"){
    err <- median(abs((err)^theta))
  }
  return(err)
}
