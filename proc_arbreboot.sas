/** Introduction**/

/***Il s'agit ici d'un arbre de décision unitaire qui selectionne m candidats parmi p pour une modélisation ultérieure en identifiant de façon
efficiente ces variable.*/
/*seules les variables numériques (quantitative et qualitative) fontionnent pour cette macro dont la proc fastclus est un pivot.*/
/*Dans le cas des varibles nominales: seg, objet_part-calc, libellé-avis (qui au passage va être ultra importante) type de financement.*/
/*C'est une technique de réduction de variables effective et de classification qui fonctionne par voting cf: présentation sur les random forest**/



/*Notre macro prend en argument: la librairie ici lib, la table ici file, */
/*le nombre de variables (noté m dans la présentation) ici varnum en général dans l'interval [60,1300] nous en avons 266 et la théorie de*/
/*Breiman suggère alors sqrt(26) ou [log(26) + 1] nous en prendrons 16, */
/*le nombre d'échantillon bootstrap (B dans la présentation) ici noté rep; en général dans l'interval [5000,25000] */


%macro Arbre_boot(lib,file,varnum,rep);

proc contents data=&lib..&file.  
out=work.vars(keep=name type) noprint;
run;

/*Le PROC CONTENTS avec l'instruction OUT écrit l'output de la procédure dans un SAS dataset. L'instruction KEEP*/
/*ne conserve que le nom de chaque variable avec le type de variable-1 pour les champs numériques et 2 pour les champs de caractères.*/

data work.vars;
set work.vars;
rename name = variable_name;
if type = 1;   /* uniquement des variables numériques */;
vote_count = 0;
run;

data work.var_votes;
set work.vars;
if _n_ < 1;
keep variable_name; 
run;


/*Une variable reçoit un "vote" pour chaque fois qu'elle est sélectionnée par PROC FASTCLUS dans la première division de la décision*/
/*arbre. Cette étape de création de données crée un ensemble de données SAS pour suivre le nombre de votes avec un enregistrement */
/*pour chaque valeur numérique.variable, initialisant le nombre des "votes" à zéro.*/


%do i = 1 %to &rep.;

data work.var_list;
set work.vars;
random = ranexp(0);
run;

proc sort data=work.var_list;
by random;
run;

data work.test_list;
set work.var_list (obs=&varnum. keep=variable_name);
run;

data _null_;
length allvars $1000;
retain allvars "";
set work.test_list end=eof;
allvars = trim(left(allvars))||' '||left(variable_name);
if eof then call symput
('varlist', allvars);
run;

%put &varlist;


/**La partie bootstrap du processus commence par la sélection d'un échantillon aléatoire de variables. Le même nombre de*/
/*variables est sélectionnées à chaque fois, défini par le argument macro varnum. */

/*Ceci est accompli en assignant au hasard un nombre à chaque variable */
/*(c'est-à-dire, chaque enregistrement dans la liste des variables) et le tri par le nombre aléatoire. */

/*Une étape data est utilisé pour capturer le nombre de lignes données par varnum. */

/*Comme l'ordre des variables est aléatoire, la sélection des b0 premieres ligne de varnum constitue un échantillon aléatoire des variables.
/*Les noms des variables sélectionnées sont*/
/*concaténé en une chaîne et converti en une variable macro nommée varlist. Cette liste de variables sélectionnées au hasard est écrite */
/*dans le journal.*/

 
proc fastclus data=&lib..&file. maxclusters=3
outstat=work.cluster_stat noprint;
var &varlist;
run; 

/*la PROC FASTCLUS est utilisée afin de créer un arbre de décision en utilisant la liste de variables sélectionnée au hasard. */
/*La déclaration maxclusters = 2 aboutit à seulement deux clusters de sortie et par conséquent à un seul split. Trivialement c'est un arbre à un critère */
/*de sélection donc deux clusters*/

data work.rsq;
set work.cluster_stat;

if _type_ = 'RSQ';
drop _type_ cluster over_all;

run;  

proc transpose data=work.rsq out=work.rsq2;
run; 

data work.rsq2;
set work.rsq2;
length variable_name $32.;
variable_name = _name_;
run;

/** Les statistiques récapitulatives du PROC FASTCLUS sont écrites dans un SAS dataset. Cela produit des statistiques pour chaque*/
/*variable. L'ensemble de données généré par PROC FASTCLUS contient une colonne pour chaque variable. L'identité de la variable sélectionnée*/ 
/*pour la première division est extraite en transposant les données, résultant sur une rangée pour chaque variable candidate **/


proc sort data=work.rsq2;
by descending col1;
run;

data work.var_votes;
set work.var_votes work.rsq2(obs=1);
run;

%end;

%mend Arbre_boot;
