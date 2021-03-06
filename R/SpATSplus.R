
R.square <- function(Model){
  response      <- Model$data[,Model$model$response]  
  mean.response <- mean(response,na.rm = T)
  fitted        <- Model$fitted
  SS.fitted     <- sum( (response-fitted)^2 , na.rm = T)
  SS.response   <- sum( (response-mean.response)^2 , na.rm = T )
  R <- 1- SS.fitted/SS.response
  names(R) <- "r.square"
  return(round(R,3))
}

CV.spats <- function(Model){
  response      <- Model$data[,Model$model$response]  
  mean.response <- mean(response,na.rm = T)
  fitted        <- Model$fitted
  MSE           <- mean( (response-fitted)^2 , na.rm = T)
  RMSE          <- sqrt(MSE)
  NRMSE         <- RMSE/mean.response
  cv_prcnt      <- NRMSE*100
  names(cv_prcnt) <- "CV"
  return(round(cv_prcnt,2))
} 


res_data <- function(Model){
  dt <- Model$data
  VarE<- Model$psi[1]   
  Data <- data.frame(Index=1:length(residuals(Model)), Residuals=residuals(Model))
  u <- +3*sqrt(VarE)
  l <- -3*sqrt(VarE)
  Data$Classify <- NA
  Data$Classify[which(abs(Data$Residuals)>=u)] <- "Outlier" 
  Data$Classify[which(abs(Data$Residuals)<u)  ] <- "Normal"
  Data$l <- l
  Data$u <- u
  Data$gen <-  dt[,Model$model$geno$genotype]
  Data$col <-  dt[,Model$terms$spatial$terms.formula$x.coord]
  Data$row <-  dt[,Model$terms$spatial$terms.formula$y.coord]
  Data$fit <-  fitted.values(Model)
  Data$response <- dt[,Model$model$response]
  return(Data)
}

res_index <- function(data_out){
  k <- dplyr::filter(data_out,!is.na(Classify)) %>% 
         ggplot(aes(x=Index,y=Residuals,color=Classify))+
         geom_point(size=2,alpha = 0.5, na.rm = T)+theme_bw()+
         scale_color_manual(values=c("grey80", "red"))+
         geom_hline(yintercept = data_out$u,color="red")+
         geom_hline(yintercept = data_out$l,color="red")+
         geom_hline(yintercept = 0,linetype="dashed")
  plotly::ggplotly(k)
}

res_map <- function(data_out){
  k <- dplyr::filter(data_out,!is.na(Classify)) %>% 
         ggplot(aes(x=col,y=row,color=Classify))+
         geom_point(size=2, na.rm = T)+theme_bw()+
         scale_color_manual(values=c("grey80", "red"))
  plotly::ggplotly(k)
}


res_fitted <- function(data_out){
  k <- dplyr::filter(data_out,!is.na(Classify)) %>% 
        ggplot(aes(x=fit,y=Residuals,color=Classify))+
        geom_point(size=2,alpha = 0.5, na.rm = T)+theme_bw()+
        scale_color_manual(values=c("grey80", "red"))+xlab("Fitted Values")+
        geom_hline(yintercept = 0,linetype="dashed")
  plotly::ggplotly(k)
}

res_qqplot <- function(data_out){
  q <- dplyr::filter(data_out,!is.na(Classify)) %>% 
       ggpubr::ggqqplot(x="Residuals",fill="Classify",ggtheme=theme_bw(), ylab = "Sample Quantile", xlab = "Theoretical Quantile")
  plotly::ggplotly(q)
}

res_hist <- function(data_out){
  hi <- hist(data_out[,"Residuals"],plot = FALSE)
  br <- hi$breaks
  p <- ggplot(data_out, aes(x=Residuals))+
        geom_histogram(aes(y=..density..), alpha=0.8, breaks=c(br), na.rm = T)+
        theme_bw()+
        geom_density(alpha=0.5, na.rm = T) +
        geom_vline(xintercept = c(data_out$u,data_out$l), linetype=2 , color="red" )
  plotly::ggplotly(p)
}

res_compare <- function(Model, variable, factor){
  data <- Model$data
  data$Residuals <- residuals(Model)
  data <- type.convert(data)
  req(variable)
  label <- class(data[,variable])
  if(factor){
    data[,variable] <- as.factor(data[,variable])
    p <- ggplot(data, aes_string(x=variable,y="Residuals", fill=variable))+
      geom_boxplot(na.rm = T)+theme_bw()
  } else{
    data[,variable] <- as.numeric(data[,variable])
    p <- ggplot(data, aes_string(x=variable,y="Residuals"))+
      geom_point(size=2,alpha = 0.5, color="grey80", na.rm = T)+theme_bw()
  }
  plotly::ggplotly(p)
}


SpATS_mrbean <- function(data, response ,genotype, 
                         col, row, segm ,ncols, nrows, 
                         fix_fact, ran_fact, gen_ran, covariate,
                         clean_out= FALSE, iterations=1){
  dt <- data
  dt[ , genotype] <- as.factor(dt[ , genotype])
  dt$col =  dt[,col]
  dt$row = dt[,row]
  dt$col_f = factor( dt[,col])
  dt$row_f = factor( dt[,row])
  ncols = ifelse(is.null(ncols)|isFALSE(segm),length(unique(dt[,col])), ncols ) 
  nrows = ifelse(is.null(nrows)|isFALSE(segm),length(unique(dt[,row])), nrows )  
  for (i in 1:length(fix_fact)) {
    dt[, fix_fact[i]] <- as.factor(dt[, fix_fact[i]])
  }
  for (i in 1:length(ran_fact)) {
    dt[, ran_fact[i]] <- as.factor(dt[, ran_fact[i]])
  }
  if(is.null(fix_fact)&is.null(covariate)) Fijo <- as.formula(~NULL)
  else if(!is.null(fix_fact)&is.null(covariate)) Fijo <- as.formula(paste("", paste(fix_fact, collapse=" + "), sep=" ~ "))                        # as.formula(paste("", fix_fact, sep=" ~ "))
  else if(!is.null(fix_fact)&!is.null(covariate)) Fijo <- as.formula(paste("", paste(c(fix_fact,covariate), collapse=" + "), sep=" ~ "))
  else if(is.null(fix_fact)&!is.null(covariate)) Fijo <- as.formula(paste("",paste(covariate, collapse = " + "),sep = " ~ "))
  
  if(is.null(ran_fact)) Random <- as.formula(~ col_f+row_f)
  else Random <-  as.formula(paste("" ,paste(c(ran_fact,"col_f","row_f"), collapse=" + "), sep=" ~ "))   
  Modelo=try(SpATS(response=response,
                   genotype=genotype, genotype.as.random=gen_ran,
                   fixed= Fijo,
                   spatial = ~ PSANOVA(col, row, nseg = c(ncols,nrows), degree=c(3,3),nest.div=2),
                   random = Random, data=dt,
                   control = list(tolerance=1e-03, monitoring=0)),silent = T)
  tryCatch(
    { 
      if(class(Modelo)=="try-error") stop("Error in the components of model")
    },
    error = function(e) {
      shinytoastr::toastr_error(title = "Warning:", conditionMessage(e),position =  "bottom-right",progressBar = TRUE)
    }
  )
  if(class(Modelo)=="try-error") return()
  
  if(clean_out){
    resum_out <- msa_residuals(Modelo)
    if(resum_out>0){
      tmp_out <- 1
      counter <- 1
      while (tmp_out>0 & counter<=iterations) {
        c_datos <- res_raw_data(Modelo)
        c_datos[, response] <- ifelse(c_datos$Classify=="Outlier", NA, c_datos[, response] )
        c_datos <- c_datos %>% dplyr::select(-weights)
        Modelo = try(SpATS(response=response,
                           genotype=genotype, genotype.as.random=gen_ran,
                           fixed= Fijo,
                           spatial = ~ PSANOVA(col, row, nseg = c(ncols,nrows), degree=c(3,3),nest.div=2),
                           random = Random, data=c_datos,
                           control = list(tolerance=1e-03, monitoring=0)), silent = T)
        tmp_out <- msa_residuals(Modelo)
        if(iterations>1) resum_out <-  resum_out + tmp_out
        counter <- counter + 1
      }
    }
  }
  
  Modelo
}


check_spats <- function(data, response, genotype, experiment, col, row, two.stage = FALSE){
  
  if(is.null(response)|response=="") return()
  if(is.null(genotype)|genotype=="") return()
  if(is.null(experiment)|experiment=="") return()
  
  data[,genotype] <- as.factor(data[,genotype])
  data[,experiment] <- as.factor(data[,experiment])
  
  if(isFALSE(two.stage)){
    if(is.null(col)|col=="") return()
    if(is.null(row)|row=="") return()
    data[,col] <- as.factor(data[,col])
    data[,row] <- as.factor(data[,row])
    if(nlevels(data[,experiment])<=1){
      shinytoastr::toastr_info(title = "Error:", "Only one level in the experiment factor.",position =  "bottom-full-width",
                                showMethod ="slideDown", hideMethod="hide", hideEasing = "linear")
      return()
      }

    dt <- data %>% dplyr::group_by(.data[[experiment]]) %>% 
      dplyr::summarise(missing = sum(is.na(.data[[response]])),
                       percentage = round(sum(is.na(.data[[response]]))/dplyr::n(),3) ,
                       ncol = dplyr::n_distinct(.data[[col]]),
                       nrow = dplyr::n_distinct(.data[[row]]),
                       ngen = dplyr::n_distinct(.data[[genotype]]))
    return(dt)
  } else {
    if(nlevels(data[,experiment])<=1) return()
    dt <- data %>% dplyr::group_by(.data[[experiment]]) %>% 
      dplyr::summarise(missing = sum(is.na(.data[[response]])),
                       percentage = round(sum(is.na(.data[[response]]))/dplyr::n(),3) ,
                       ngen = dplyr::n_distinct(.data[[genotype]]))
    return(dt)
  }

}

number_gen <- function(filter_data){
  names(filter_data)[1] <- "Experiment"
  g0 <- filter_data %>% 
    echarts4r::e_charts(Experiment) %>% 
    echarts4r::e_bar(ngen, name = "Number of genotypes",bind = Experiment) %>% 
    echarts4r::e_title("Number of genotypes",subtext = "by experiment") %>% 
    echarts4r::e_tooltip() %>%
    echarts4r::e_legend(show = FALSE) %>% 
    echarts4r::e_toolbox_feature(feature = "saveAsImage") %>% 
    echarts4r::e_toolbox_feature(feature = "dataView") %>% 
    echarts4r::e_labels() %>% 
    echarts4r::e_x_axis(axisLabel = list(interval = 0, rotate = 65, fontSize=12 , margin=8  ))  %>% # rotate
    echarts4r::e_grid(height = "65%", top = "15%") %>% 
    echarts4r::e_color( "#28a745" )
  g0
}

gen_share <- function(data=NULL, genotype="line", exp="Exp", response=NA){
  data <- as.data.frame(data)
  nomb <- c(genotype,exp)
  if(sum(nomb%in%names(data))!=2){
    message("columns not found in the data")
    return()
  }
  data=type.convert(data)
  data[,genotype] <- as.factor(data[,genotype])
  data[,exp] <- as.factor(data[,exp])
  if(!is.na(response)) data <- data[ !is.na(data[,response]) , ]
  nexp <- nlevels(data[,exp] )
  ngen <- nlevels(data[,genotype] )
  share <- matrix(NA,nrow=nexp,ncol = nexp) 
  rownames(share) <- levels(data[,exp] )
  colnames(share) <- levels(data[,exp] )
  ind = which(names(data)%in%exp)
  for (i in 1:nexp) {
    eitmp <- levels( droplevels( data[data[,ind]==colnames(share)[i],] )[,genotype]  )
    for (j in 1:nexp) {
      ejtmp <- levels( droplevels( data[data[,ind]==colnames(share)[j],] )[,genotype] )
      share[i,j] <- sum(eitmp%in%ejtmp)
    }
  }
  return(share)
}

plot_shared <- function(share){
  Share <- share %>%
    echarts4r::e_charts() %>%
    echarts4r::e_correlations(order = "hclust",visual_map = F) %>%
    echarts4r::e_tooltip() %>%   
    echarts4r::e_visual_map( 
      min = min(share),
      max = max(share),
      orient= 'horizontal',
      left= 'center',
      bottom = 'bottom'
    ) %>%
    echarts4r::e_title("Shared genotypes", "By experiment") %>% 
    echarts4r::e_x_axis(axisLabel = list(interval = 0, rotate = -45, fontSize=12 , margin=8  ))  %>% # rotate
    echarts4r::e_grid(left = "20%",height = "60%")
  Share
}

dup_check <- function(data, experiment, column, row){
  tt <- split(data, f = data[,experiment])
  lapply(tt, function(x) sum(duplicated(x[,c(column,row)])))
}

res_raw_data <- function(Model){
  dt <- Model$data
  VarE<- Model$psi[1]   
  Data <- data.frame(Index=1:length(residuals(Model)), Residuals=residuals(Model))
  u <- +3*sqrt(VarE)
  l <- -3*sqrt(VarE)
  Data$Classify <- NA
  Data$Classify[which(abs(Data$Residuals)>=u)] <- "Outlier" 
  Data$Classify[which(abs(Data$Residuals)<u)  ] <- "Normal"
  
  dt$Classify <- Data$Classify
  return(dt)
}


# MSA

VarG_msa <- function(model){
  gen <- model$model$geno$genotype
  gen_ran <- model$model$geno$as.random
  if(gen_ran){
    vargen <- round(model$var.comp[gen],3)
    names(vargen) <- "Var_Gen"
    return(vargen)
  } else{
    # pred <- predict(model,which = gen)[,"predicted.values"]
    # CV <- round(sd(pred)/mean(pred),3)
    # names(CV) <- "CV"
    CV = NA
    return(CV)
  }
}

VarE_msa <- function(model){
  v <- round(model$psi[1],3)
  names(v) <- "Var_Res"
  return(v)
}

h_msa <- function(model){
  gen_ran <- model$model$geno$as.random
  if(gen_ran){
    h <-  getHeritability(model)
    return(h)
  } else {
    return(NA) 
  }
}

msa_residuals <- function(model){
  value <- sum(res_data(model)$Classify=="Outlier", na.rm = T)
  return(value)
}

msa_table <- function(models, gen_ran){
  exp <- names(models)
  gv <- unlist(lapply(models, VarG_msa))
  ev <- unlist(lapply(models, VarE_msa))
  he <- unlist(lapply(models, h_msa ))
  out <- unlist(lapply(models, msa_residuals ))
  r2 <- unlist(lapply(models, R.square ))
  cv <- unlist(lapply(models, CV.spats ))
  summ <- data.frame(Experiment=exp, varG = gv, varE = ev, h2 = he, outliers=out , r2=r2 , cv = cv , row.names = NULL)
  return(summ)
}

msa_effects <- function(model){
  gen <- model$model$geno$genotype
  effects <- predict(model, which = gen)[,c(gen, "predicted.values", "standard.errors")] %>% 
             dplyr::mutate_if(is.numeric, round, 3) %>% data.frame()
  if(!model$model$geno$as.random){
    effects <- weight_SpATS(model)$data_weights
  }
  return(effects)
}

multi_msa_effects <- function(models){
  blups <- lapply(models, msa_effects)
  blups <- data.table::data.table(plyr::ldply(blups[], data.frame, .id = "Experiment")) 
  return(blups)
}


table_outlier <- function(models, id = "trait"){
  dt <- lapply(models, res_data)
  dt <- data.table::data.table(plyr::ldply(dt[], data.frame, .id = id)) 
  dt <- dt[dt$Classify=="Outlier",] %>% dplyr::mutate_if(is.numeric, round, 3)
  return(dt)
}


# Weights 

weight_SpATS <- function(model){
  rand <- model$model$geno$as.random
  if(rand) return()
  
  C_inv <- as.matrix(rbind(cbind(model$vcov$C11_inv, model$vcov$C12_inv),  # Combine components into one matrix C
                           cbind(model$vcov$C21_inv, model$vcov$C22_inv)))
  gen_mat <- colnames(model$vcov$C11_inv)
  
  genotype <- model$model$geno$genotype
  dt <- predict(model, which = genotype) %>% droplevels() %>% dplyr::mutate_if(is.numeric, round, 3)
  gen_lvls <- as.factor(unique(as.character(dt[,genotype])))
  
  intc <- intersect(gen_mat, gen_lvls)
  diff <- setdiff(gen_lvls, gen_mat )
  
  vcov <- C_inv[c("Intercept",intc), c("Intercept",intc)]
  colnames(vcov)[1] <- rownames(vcov)[1] <- diff
  diag_vcov <- diag(vcov)
  
  L <- diag(ncol(vcov))
  dimnames(L) <- list(colnames(vcov), rownames(vcov))
  L[,1] <- 1
  Se2 <- diag(L%*%vcov%*%t(L))
  
  data_weights <- data.frame(gen=names(diag_vcov) , vcov = diag_vcov, inv_vcov = 1/diag_vcov,  weights = 1/Se2 )
  data_weights <- merge(dt, data_weights, by.x = genotype, by.y = "gen", sort = F )
  data_weights <- data_weights[,c(genotype, "predicted.values", "standard.errors","weights" )]   # "vcov","inv_vcov",
  
  return(list(vcov=vcov, diag=diag_vcov, diag_inv = 1/diag_vcov,
              se2 = Se2, se = sqrt(Se2), data_weights= data_weights))
}





# Daniel Ariza

ggCor <- 
  function(myData, colours = c('#db4437','white','#FF9D00'),
           blackLabs = c(-0.7, 0.7), showSignif = TRUE,
           pBreaks = c(0, .0001, .001, .01, Inf), pLabels = c('***','**','*', 'ns'),
           showDiagonal = FALSE, Diag = NULL, returnTable = FALSE){
    
    #   Goal      : Return a ggplot object to plot a triangular correlation figure between 2 or more variables.
    #               Depends on the packages 'ggplot2' 'psych' and 'reshape'
    #
    #   Input     : myData       = A data.frame with numerical columns for each variable to be compared.
    #   Input     : colours      = A vector of size three with the colors to be used for values -1, 0 and 1.
    #   Input     : blackLabs    = A numeric vector of size two, with min and max correlation coefficient 
    #                              limits to display with black tags. Any value outside this range will be 
    #                              displayed with white tags.
    #   Input     : showSignif   = Logical scalar. Display significance values ?
    #   Input     : pBreaks      = Passed to function 'cut'. Either a numeric vector of two or more unique 
    #                              cut points or a single number (greater than or equal to 2) giving the
    #                              number of intervals into which x is to be cut.
    #   Input     : pLabels      = Passed to function 'cut'. labels for the levels of the resulting category.
    #                              By default, labels are constructed using "(a,b]" interval notation. 
    #                              If pLabels = FALSE, simple integer codes are returned instead of a factor.
    #   Input     : showDiagonal = Logical scalar. Display main diagonal values ?
    #   Input     : Diag         = A named vector of labels to display in the main diagonal. The names are 
    #                              used to place each value in the corresponding coordinates of the diagonal.
    #                              Hence, these names must be the same as the colnames of myData
    #   Input     : returnTable  = Return the table to display instead of a ggplot object
    #
    #   Output    : A ggplot object containing a triangular correlation figure with all numeric variables 
    #               in myData. If returnTable is TRUE, the table used to produce the figure is returned instead.
    #   Authors   : darizasu
    #    Last update: May 18, 2019
    
    
    # Drop non numeric columns in the dataset
    if (sum( !sapply(myData, is.numeric) )){
      
      message('Dropping non-numeric columns in the dataset:\n',
              paste(names( which(!sapply(myData, is.numeric)) ),
                    collapse = '\t'))
      
      myData = myData[,sapply(myData, is.numeric)]
    }
    
    # Calculate corr-coeffs and p values
    cors = psych::corr.test(myData, use = 'pairwise.complete.obs')
    
    # Use the adjusted p values for multiple testing instead of raw coeffs
    cors$p = t(cors$p)
    
    # Keep only the matrices with correlation coefficients and p values
    cors = cors[c(1,4)]
    
    # For each matrix, do ...
    cors = lapply(cors, function(x){
      
      # Keep the upper triangle of the matrix
      x[upper.tri(x)] = NA
      
      # Transpose the matrix to plot the lower triangle
      x  = as.data.frame(t(x))
      
      # Reshape the matrix to tidy format
      x[,'col'] = colnames(x)
      x  = reshape::melt(x, id='col')
      colnames(x) = c('col','row','value')
      
      # Round coefficients
      x$name = round(x$value,2)
      
      # Sort the x axis according to myData column order
      x$col = factor(x$col, levels = colnames(myData))
      
      # Reverse the y axis for a triangle plot from top-left to bottom-right
      x$row = factor(x$row, levels = rev(colnames(myData)))
      
      # Remove NAs
      x = na.omit(x)
      
    })
    
    # Combine both dataframes with p values and corr coefficients
    cors = merge(x = cors$r, y = cors$p, by = c('col','row'))
    
    # Keep x, y, p val and corr-coefficients columns
    cors = cors[,c(1,2,4,5)]
    
    if (showSignif){
      
      # Create a categorical variable for p values as defined by pBreaks
      cors$signi = cut(x = cors$value.y,  right = F,
                       breaks = pBreaks, labels = pLabels)
      
      # Join corr-coeff and p-value to display it as a label for each tile
      cors$label = paste(cors$name.x, cors$sign, sep='\n')
      
    } else {
      
      # The label for each tile is the corr-coeff only
      cors$label = cors$name.x
    }
    
    # If there are user-specified values to display in the diagonal
    if (! is.null(Diag)){
      
      # Check the names in Diag are the same than colnames of myData
      if ( sum(! names(Diag) %in% colnames(myData)) ){
        warning("These elements in 'Diag' do not correspond to column names in 'myData':\n",
                paste(names(Diag)[!names(Diag) %in% colnames(myData)],
                      collapse = '\t'))
      }
      
      # The tiles of the diagonal are gray
      cors[cors$col == cors$row, 'name.x'] = NA
      
      # Get the name of x and y levels
      d = as.character(cors[cors$col == cors$row, 'row'])
      
      # Modify the elements of the diagonal and make sure they are displayed
      cors[cors$col == cors$row, 'label'] = Diag[d]
      showDiagonal = TRUE
    }
    
    # Remove the elements of the main diagonal if you don't want to display
    if (!showDiagonal)  cors = cors[cors$col != cors$row,]
    
    # Show darker tiles with white labels for clarity
    cors$txtCol = ifelse(cors$name.x > blackLabs[1] & 
                           cors$name.x < blackLabs[2], 'black', 'white')
    
    # Do not show tile labels for empty tiles.
    # Make tile labels of the diagonal white
    cors$txtCol[is.na(cors$txtCol)] = 'white'
    
    if (returnTable) return(cors)
    
    require(ggplot2)
    
    p = ggplot(data = cors, aes(x = col, y = row, fill = name.x)) + 
      geom_tile(color = 'gray') + labs(x = NULL, y = NULL) + theme_minimal(base_size = 16) +
      geom_text(aes(x = col, y = row, label = label), color = cors$txtCol, size = 4) +
      scale_fill_gradient2(low = colours[1], mid = colours[2], high = colours[3]) + 
      theme(axis.text.x = element_text(angle = 40, hjust = 1), legend.position = 'none',
            panel.grid.minor.x = element_blank(), panel.grid.major = element_blank())
    
    return(p)
  }
