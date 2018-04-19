/** Introduction**/

/***Il s'agit ici d'un arbre de d�cision unitaire qui selectionne m candidats parmi p pour une mod�lisation ult�rieure en identifiant de fa�on
efficiente ces variable.*/
/*seules les variables num�riques (quantitative et qualitative) fontionnent pour cette macro dont la proc fastclus est un pivot.*/
/*Dans le cas des varibles nominales: seg, objet_part-calc, libell�-avis (qui au passage va �tre ultra importante) type de financement.*/
/*C'est une technique de r�duction de variables effective et de classification qui fonctionne par voting cf: pr�sentation sur les random forest**/



/*Notre macro prend en argument: la librairie ici lib, la table ici file, */
/*le nombre de variables (not� m dans la pr�sentation) ici varnum en g�n�ral dans l'interval [60,1300] nous en avons 266 et la th�orie de*/
/*Breiman sugg�re alors sqrt(26) ou [log(26) + 1] nous en prendrons 16, */
/*le nombre d'�chantillon bootstrap (B dans la pr�sentation) ici not� rep; en g�n�ral dans l'interval [5000,25000] */


%macro Arbre_boot(lib,file,varnum,rep);

proc contents data=&lib..&file.  
out=work.vars(keep=name type) noprint;
run;

/*Le PROC CONTENTS avec l'instruction OUT �crit l'output de la proc�dure dans un SAS dataset. L'instruction KEEP*/
/*ne conserve que le nom de chaque variable avec le type de variable-1 pour les champs num�riques et 2 pour les champs de caract�res.*/

data work.vars;
set work.vars;
rename name = variable_name;
if type = 1;   /* uniquement des variables num�riques */;
vote_count = 0;
run;

data work.var_votes;
set work.vars;
if _n_ < 1;
keep variable_name; 
run;


/*Une variable re�oit un "vote" pour chaque fois qu'elle est s�lectionn�e par PROC FASTCLUS dans la premi�re division de la d�cision*/
/*arbre. Cette �tape de cr�ation de donn�es cr�e un ensemble de donn�es SAS pour suivre le nombre de votes avec un enregistrement */
/*pour chaque valeur num�rique.variable, initialisant le nombre des "votes" � z�ro.*/


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


/**La partie bootstrap du processus commence par la s�lection d'un �chantillon al�atoire de variables. Le m�me nombre de*/
/*variables est s�lectionn�es � chaque fois, d�fini par le argument macro varnum. */

/*Ceci est accompli en assignant au hasard un nombre � chaque variable */
/*(c'est-�-dire, chaque enregistrement dans la liste des variables) et le tri par le nombre al�atoire. */

/*Une �tape data est utilis� pour capturer le nombre de lignes donn�es par varnum. */

/*Comme l'ordre des variables est al�atoire, la s�lection des b0 premieres ligne de varnum constitue un �chantillon al�atoire des variables.
/*Les noms des variables s�lectionn�es sont*/
/*concat�n� en une cha�ne et converti en une variable macro nomm�e varlist. Cette liste de variables s�lectionn�es au hasard est �crite */
/*dans le journal.*/

 
proc fastclus data=&lib..&file. maxclusters=3
outstat=work.cluster_stat noprint;
var &varlist;
run; 

/*la PROC FASTCLUS est utilis�e afin de cr�er un arbre de d�cision en utilisant la liste de variables s�lectionn�e au hasard. */
/*La d�claration maxclusters = 2 aboutit � seulement deux clusters de sortie et par cons�quent � un seul split. Trivialement c'est un arbre � un crit�re */
/*de s�lection donc deux clusters*/

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

/** Les statistiques r�capitulatives du PROC FASTCLUS sont �crites dans un SAS dataset. Cela produit des statistiques pour chaque*/
/*variable. L'ensemble de donn�es g�n�r� par PROC FASTCLUS contient une colonne pour chaque variable. L'identit� de la variable s�lectionn�e*/ 
/*pour la premi�re division est extraite en transposant les donn�es, r�sultant sur une rang�e pour chaque variable candidate **/


proc sort data=work.rsq2;
by descending col1;
run;

data work.var_votes;
set work.var_votes work.rsq2(obs=1);
run;

%end;

%mend Arbre_boot;
