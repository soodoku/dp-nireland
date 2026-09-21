# Research design

## Question

Can respondents articulate reasons supporting and opposing contentious school
policies, and do returning Deliberative Poll participants articulate more of
them than contemporaneously interviewed controls?

## Identified quantities

The primary quantity is the difference in mean respondent-level reason counts
between returning participants and T3 controls. It is an associational estimand.
Attendance was not randomized, and the outcome was not measured at recruitment,
so the contrast does not identify an average treatment effect of deliberation.

The adjusted specification conditions on age, sex, Catholic versus Protestant
community, and degree status. It addresses measured composition only. Variables
measured after briefing or deliberation, including contemporaneous factual
knowledge, are not adjustment covariates.

The first secondary quantity is the within-returnee change from T2 to T3. It
removes time-invariant respondent differences but combines retention, response
effort, context, and any mode differences. The second secondary quantity compares
all T2 participants with T3 controls. It is noncontemporaneous and includes
briefing exposure before T2.

Directional outcomes divide the classifiable repertoire into reasons supporting
and opposing each respondent's initial policy position. Signed balance is
`(supporting - opposing) / (supporting + opposing)` and absolute imbalance is
its absolute value. Both are undefined when the denominator is zero. The T3
participant--control contrast remains associational. The paired T2--T3 change
removes stable respondent differences but remains confounded with survey context,
effort, and mode. Because completed adjudication substantially reduces the
paired sample, coder-specific estimates are reported as measurement
sensitivities.

## Units and inference

The unit is the respondent. The primary outcome sums forty possible response
slots: five slots on each side of four policy proposals. Participants can share
shocks induced by their moderated discussion group, whereas controls were not
grouped. Inference therefore treats each observed participant discussion group
as a cluster and each control respondent as a singleton cluster. One participant
without a recorded group is also treated as a singleton. CR2 standard errors and
Satterthwaite degrees of freedom provide the small-sample correction. The
available project files do not document a survey weight for these comparisons,
so estimates are unweighted.

## Small groups

The historical manuscript says participants were randomly assigned to small
groups. No assignment protocol, randomization seed, allocation file, or balance
record was found. Group-composition effects are therefore not part of the current
evidentiary core. They can be restored only after the assignment mechanism is
verified and inference is tied to that mechanism. Accounting for within-group
dependence does not itself identify a causal effect of group composition or event
attendance.

## What would identify the causal effect

A stronger design would measure the open-ended outcome before invitations or
briefing materials, randomize access among willing respondents, and repeat the
same instrument after the event and at follow-up. This would separate selection,
immediate learning, and retention.
