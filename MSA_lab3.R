### Multivariate statistical analysis, 2020 ###
### Mixed-effects models (part 1) ###

### Description
### Рассмотрим пример оценивания моделей со смешанными эффектами на кросс-секционных данных из статьи [Luke D.A., Krauss M., 2004] 
### (статью можете скачать по ссылке https://yadi.sk/i/w_dgDbu8blukXA). 
### Авторы изучают факторы голосования членов Конгресса США в интересах табачной индустрии. 
### В фокусе внимания - различия во взаимосвязи размера финансирования комитетами политического действия (PAC) 
### от табачных корпораций и голосования в интересах табачной индустрии. 
### В частности, авторы тестируют, есть ли различия в этой взаимосвязи между представителями Демократической и Республиканской партий.

### Краткое описание данных:
# state - штат (группирующая переменная)
# lastname - член Конгресса
## Переменные на первом уровне:
# votepct - доля голосов, отданных членом Конгресса в поддержку табачной индустрии (зависимая переменная)
# party - дамми-переменная: представитель Демократической или Республиканской партии (1 - Республиканская партия)
# money - размер финансирования от PAC табачных корпораций (тысячи долларов)
## Предиктор на втором уровне:
# acres - площадь табачных плантаций ((тысячи акров))

install.packages("haven")
install.packages("psych")
install.packages("arm")
install.packages("multilevel")
install.packages("lattice")
install.packages("sjPlot")
install.packages("influence.ME")
install.packages("ggplot2")
install.packages("lmerTest")

library(haven)
library(psych)
library(arm)
library(multilevel)
library(lattice)
library(sjPlot)
library(influence.ME)
library(ggplot2)
library(lmerTest)

# open your data 
ME <- read_dta("MSA_lab3.dta")

# ID for each state (the second level): transform a nominal variable into a factor one
state_id <- as.factor(ME$state) 
ME <- na.omit(data.frame(ME, state_id))

# examine descriptive statistics
head(ME)
describe(ME)

### Preliminary visualization
ggplot(ME, aes(x=money, y=votepct, color=state_id)) +
  geom_smooth(method=lm, se=FALSE)

ggplot(ME, aes(x=money, y=votepct)) + 
  geom_smooth(method = "lm", se = FALSE) +
  geom_point() +
  facet_wrap("state_id")

# run a null-model
null <- lmer(votepct ~ 1 + (1|state_id), REML = FALSE, data = ME)
summary(null)
# it is better to calculate ICC manually since the group sizes are unequal
0.03478 / (0.03478+0.09313) 

# extra option: ICC using anova model (only when group sizes are equal)
anovaicc <- aov(votepct ~ state_id, data = ME) 
summary(anovaicc)
ICC1(anovaicc)

# see whether the group variance is equally distributed
graph.ran.mean(ME$votepct, ME$state_id, nreps=1000, bootci=TRUE)

# show random effects
ranef(null)

# run a model with fixed effects for individual-level indicators
options(scipen = 999)
model1 <- lmer(votepct ~ money + (1|state_id), REML = FALSE, data = ME)
summary(model1)

# show random effects (BLUP)
ranef(model1)
# visualize random effects with confidence intervals
# Are random effects significant?
dotplot(ranef(model1, condVar=TRUE))

# get intercept for each state
# unique intercept
model1_intercept <- coef(model1)$state_id[,1] 
model1_intercept
# make sure that we estimated the same slope for each state
model1_slope <- coef(model1)$state_id[,2] 
model1_slope

# without repeated observations (duplicates)
state_unique <- unique(state_id)
data.frame(state_unique, model1_intercept, model1_slope)

# compare models
anova(null, model1)

# add individual-level predictors
model2 <- lmer(votepct ~ money + party + (1|state_id), REML = FALSE, data = ME)
summary(model2)
anova(model1, model2)

# add fixed effects for state-level predictors (acres)
model3 <- lmer(votepct ~ money + party + acres + (1|state_id), REML = FALSE, data = ME)
summary(model3)
anova(model2, model3)

# add random effects
model4.1 <- lmer(votepct ~ money + party + (1 + party|state_id), REML = FALSE, data = ME)
summary(model4.1) 
ranef(model4.1) 
dotplot(ranef(model4.1, condVar=TRUE))
anova(model2, model4.1)

# the effect of lnmoney does not vary significantly across states
model4.2 <- lmer(votepct ~ money + party + (1 + money|state_id), REML = FALSE, data = ME)
summary(model4.2) # random effects are correlated
ranef(model4.2) 
dotplot(ranef(model4.2, condVar=TRUE))

###################################################################################################################################################
# optional: Why does the effect of party vary across states? 
model5 <- lmer(votepct ~ money + party + acres + party*acres + (1 + party|state_id), REML = FALSE, data = ME)
summary(model5)

### diagnostics for variance components
plot_model(model4.1, type = "diag")[1]
plot_model(model4.1, type = "diag")[2]
plot_model(model4.1, type = "diag")[3]

### influential observations
inf <- influence(model4.1, group = "state_id", data = ME)
cooks.distance.estex(inf, sort=TRUE)
plot(inf, which = "cook", xlab = "COOK'S MEASURE", cutoff = 4/length(state_unique))  
dfbetas.estex(inf)
plot(inf, which = "dfbetas", xlab = "DFBETAS", cutoff = sqrt(4/length(state_unique)))  

### Correlation between BLUP Intercepts and Slopes
random <- ranef(model4.1)
random$state_id
unique <- cbind((random$state_id[1]),(random$state_id[2]))
plot(unique, 
     xlab = 'Intercepts', ylab = "Slopes ",
     main = "Correlation between BLUP Intercepts and Slopes")
###################################################################################################################################################
# mixed-effects models: nlme package
model_nlme <- lme(votepct ~  money + party, random = ~1+party|state_id, method = "ML", data = ME)
summary(model_nlme)
intervals(model_nlme)

### Specify the Variance-Covariance matrix structure for random effects 
### no correlation between random effects
### If the random effects are correlated, what does it mean?
model_nlme_1 <- lme(votepct ~  money + party, random = list(state_id = pdDiag(~1 + ~party)), method = "ML", data = ME)
summary(model_nlme_1)
anova(model_nlme_1, model_nlme)
intervals(model_nlme_1)
