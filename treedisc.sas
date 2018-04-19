*%inc '/sas/m611/stat/sampsrc/xmacro.sas';
%macro treedisc(data=,depvar=,ordinal=,nominal=,ordfloat=,
                 format=,freq=,order=,
                 merge=,split=,alpha=,afuzz=,bonf=,gabriel=,
                 branch=,leaf=,options=,printp=,pformat=,
                 outtree=,intree=,code=,trace=,indent=,space=,listvar=,
                 draw=,drawvar=,box=,netopt=,actopt=,pattern=,
                 ctext=,clines=,cfill=,cback=,pos=,
                 maxread=,limit=,maxdepth=,nomsplit=,ordsplit=);


 %xinit(treedisc);

 %global _numv_; %let _numv_=0;
 %local neginf; %let neginf=-1e38;
 %local delds; %let delds=;
 %local temp;

 %if %bquote(&intree)= %then %do;
    %let temp=_LAST_;
    %xchkdef(intree)
 %end;
 %else %do;
    %let temp=;
    %xchkdata(intree)
    %xdsinfo(&intree)
    %if %bquote(&intree)^= %then %if &_xdstype^=TREEDISC %then %do;
       %xerrset(The INTREE= data set &intree is TYPE=&_xdstype%str(;)
                it must be TYPE=TREEDISC);
    %end;
 %end;

 %xchkdata(data,&temp)
 %if %bquote(&data)^= %then %do;
    %xdsinfo(&data);
    %if &_xdstype=TREEDISC %then %do;
       %put NOTE: %qcmpres(The DATA= data set &data is TYPE=&_xdstype
           and will therefore be treated as an INTREE= data set.);
       %let intree=&data;
       %let data=;
    %end;
 %end;


 %xchkname(depvar)
 %let depvar=%qupcase(&depvar);
 %xchklist(ordinal)
 %xchklist(nominal)
 %xchklist(ordfloat)
 %xchklist(format,,%str(NI:-.$))
 %xchkname(freq)
 %xchkkey(order,INTERNAL, INTERNAL FORMATTED DATA FREQ)
 %xchknum(merge,.0001,0<=MERGE and MERGE<=1)
 %xchknum(split,.049,0<=SPLIT and SPLIT<=1)
 %xchknum(alpha,0.1,0<=ALPHA and ALPHA<=1)
 %xchknum(afuzz,1e-35,0<=AFUZZ and AFUZZ<=.0001)
 %let afuzz=%unquote(&afuzz);
 %xchkint(bonf,1,0,3)
 %xchkint(gabriel,1,0,1)
 %xchkint(leaf,1,1)
 %xchkint(branch,%eval(2*&leaf),1)
 %xchkkey(trace,0, NONE:0 SHORT:1 MEDIUM:2 LONG:3 VERYLONG:4
    ENORMOUS:5 HUMONGOUS:6
    0 1 2 3 4 5 6 7 8 9 10 11 99 100)
 %xchkuint(indent,4)
 %xchkuint(space,2)
 %xchkdef(listvar,)
 %xchkeq(options)
 %xchkuint(printp,-1)
 %local pmin; %if %bquote(&pformat)= %then %let pmin=.0001;
                                     %else %let pmin=0;
 %xchkeq(pformat,6.4)
 %xchkdsn(outtree,_DATA_)
 %xchkeq(code)
 %xchkint(box,21,8,204)


 %xchkkey(draw,,
    NONE:NO LP LINEPRINTER:LP FS FULLSCREEN:FS GRAPHICS);
 %xchkeq(drawvar)
 %xchkdef(netopt,%str(OUT=_NETDR_))

 %xchkeq(cback)
 %xchkeq(cfill)
 %if &_xsysver>=608 %then %let temp=TREE CENTERSUBTREE;
                    %else %let temp=;
 %if &draw=GRAPHICS %then %do;
    %xchklist(pos,,I,2,2)
    %if %bquote(&pos)= %then %let temp=&temp COMPRESS;
    %else %do;
       goptions hpos=%scan(&pos,1,%str( )) vpos=%scan(&pos,2,%str( ));
    %end;
    %xchkdef(actopt, %qcmpres(NODEFID RECTILINEAR &temp))
    %if %bquote(&cfill)= %then %xchkdef(pattern, PATTERN1 VALUE=EMPTY);
    %else %xchkdef(pattern, PATTERN1 VALUE=SOLID COLOR=&cfill);
    %if %bquote(&cback)= %then %do;
       data _null_;
          length cback $8;
          rc=ginit();
          call gask('cback',cback,rc);
          call symput('cback',cback);
       run;
    %end;
    %else %do;
       goptions cback=&cback;
    %end;
    %local gtemp;
    %let gtemp=%qupcase(&cfill);
    %if &gtemp= %then %let gtemp=%qupcase(&cback);
    %if &gtemp=BLACK | &gtemp=GRAY | &gtemp=GREY | &gtemp=BLUE |
        &gtemp=CX000000 %then %do;
       %xchkeq(ctext,WHITE)
       %xchkeq(clines,YELLOW)
    %end;
    %else %do;
       %xchkeq(ctext,BLACK)
       %xchkeq(clines,BLACK)
    %end;
 %end;
 %else %do;
    %xchkdef(actopt, NODEFID VBETWEEN=3 &temp);
    %xchkdef(pattern,)
    %if &draw=FS %then %do;
       %xchkeq(ctext)
       %xchkeq(clines)
    %end;
 %end;


 %xchkuint(limit,10)      %* loop limit;
 %xchkint(maxdepth,100,1)
 %xchkint(nomsplit,10)
 %xchkint(ordsplit,100)

 ************ process options ************;

 %local read dofreq fs noformat nolist dolist ichaid
        n token;
 %let read=0;
 %let dofreq=0;
 %let fs=;
 %let noformat=0;
 %let nolist=0;
 %let dolist=0;
 %let ichaid=0;

 %let n=1;
 %let token=%qscan(%bquote(&options),&n,%str( ));
 %do %while(&token^=);
    %let token=%qupcase(&token);
    %if %xsubstr(&token,1,4)=READ %then %let read=1; %else
    %if %xsubstr(&token,1,6)=DOFREQ %then %let dofreq=1; %else
    %if %xsubstr(&token,1,8)=NOFORMAT %then %let noformat=1; %else
    %if %xsubstr(&token,1,6)=NOLIST %then %let nolist=1; %else
    %if %xsubstr(&token,1,4)=LIST %then %let dolist=1; %else
    %if %xsubstr(&token,1,5)=CHAID %then %let ichaid=1; %else
    %do;
       %let _xrc_=Unrecognized option &token;
       %put ERROR: &_xrc_..;
    %end;
    %let n=%eval(&n+1);
    %let token=%qscan(%bquote(&options),&n,%str( ));
 %end;


 %if &read %then %let temp=2000000000; %else %let temp=1000;
 %xchkint(maxread,&temp,1)

 * if no output options are specified, try to figure out what to do;

 %if %bquote(&draw)= %then %if %bquote(&drawvar)^= %then %let draw=LP;
 %if &dolist=0 %then %if %bquote(&listvar)^= %then %let dolist=^&nolist;
 %if %bquote(&code)= %then %if %bquote(&draw)= %then %if &dolist=0 %then
    %do;
    %if &nolist %then %let draw=LP;
    %else %if %bquote(&intree)^= %then %let draw=LP;
    %else %let dolist=1;
 %end;
 %if %bquote(&draw)= %then %let draw=NO;
 %else %if %bquote(&drawvar)=
    %then %let drawvar=SPLIT_ VALUES_ COUNT_ PVALUES_;

 %xbug(TREEDISC options:, read dofreq noformat dolist ichaid);



 *______________ check ORDER, NOFORMAT, and FREQU ___________*;

 %if &dofreq=1 and &noformat=1 %then %xerrset(Options FREQ and NOFORMAT
     are both specified%str(,) but PROC FREQ uses formatted values);

 %if &noformat=1 and &order^=INTERNAL %then %xerrset(ORDER%str(=)&order
     and the NOFORMAT option may not both be specified);

 *________________check OUTTREE, INTREE, and DATA _____________*;

  %let temp=%qupcase(&outtree);

  %IF &TEMP=_DFDSIN_ OR &TEMP=_DFEST_ OR &TEMP=_DFOUT_
    OR &TEMP=_TABLE_ OR &TEMP=DFTABLE OR &TEMP=DFTABLE1
    %THEN %xerrset(Output data set name &OUT is a reserved name);

  %if %bquote(&intree)^= %then %do;
     %xchkend(&intree)
     %if &_xrc_^=OK %then %goto exit;
     %let outtree=%unquote(&intree);
     %goto output;
  %end;


  %*let outtree=%unquote(&outtree);

  %let temp=%qupcase(&data);
  %IF &TEMP=_DFDSIN_ OR &TEMP=_DFEST_ OR &TEMP=_DFOUT_
    OR &TEMP=_TABLE_ OR &TEMP=DFTABLE OR &TEMP=DFTABLE1
    %THEN %xerrset(Input data set name &DATA is a reserved name);

 %xchkvar(&data, ,&depvar &freq &ordinal &nominal &ordfloat)
 %if &_xrc_^=OK %then %goto chkend;

 *_____________ check DEPVAR  _____*;

  %xvlist(data=&data,_list=depvar,_name=_dep,_fmt=_yfmt,
          valid=123,format=&format);

 *_____________ check FREQ _____________*;

  %if %bquote(&freq)^= %then %do;
    %xvlist(data=&data,_list=freq,_ltype=_tp,valid=01);
    %end;

 *_________________ predictor names validation ____________*;


 %if %bquote(&ordinal)^= %then
     %xvlist(data=&data,_list=ordinal,_name=_ord,replace=1,
             _count=_nord,valid=0123,format=&format);
 %else %do;
    %global _nord;
    %let _nord=0;
    %end;
 %if %bquote(&ordfloat)^= %then
     %xvlist(data=&data,_list=ordfloat,_name=_orf,replace=1,
             _count=_norf,valid=0123,format=&format);
 %else %do;
    %global _norf;
    %let _norf=0;
    %end;

 %if %bquote(&nominal)^= %then
     %xvlist(data=&data,_list=nominal,_name=_nom,replace=1,
             _count=_nnom,valid=0123,format=&format);
 %else %do;
    %global _nnom;
    %let _nnom=0;
    %end;


 %if &_xrc_^=OK %then %goto chkend;

 *____________________________________________________________*

   Inputs depvar, freq, ordinal, nominal, and ordfloat should
   be mutually exclusive. And the union of the three types
   of predictors should be non empty.
 *____________________________________________________________*;
 %let _varlist=&ordinal &nominal &ordfloat;
 %if %bquote(&_varlist)= %then %xerrset(%str(No predictor variables have
    been specified. The ORDINAL=, NOMINAL=, and ORDFLOAT= lists are all
    empty));
 %else %if &_check_>=2 %then %trdichk2;

 *************** finished checking arguments *****************;
 %chkend:
 %xchkend(&data);
 %if &_xrc_^=OK %then %goto exit;
 %if &_check_<=2 %then %xnobs(_xnobs,&data); %*else xchkend set _xnobs;


 %let data=%unquote(&data);

 %if %bquote(&freq)= %then %do;
    %if &branch>&_xnobs %then %xerrset(BRANCH%str(=)&branch is greater
       than the number of observations in data set &data);
 %end;

 ************ get levels of the dependent variable ****************;
 %if &noformat=0 %then %do;
    %trdidep;
 %end;

 *************** get categories of predictors *****************;
 %local del;
 %let del=0;
 %if &noformat=0 %then %do;
    %trdicat;
    %if &_xrc_^=OK %then %goto exit;
 %end;


 ******************* sort and freq data set *******************;
 %if &dofreq %then %do;
    %trdifrq;
    %if &_xrc_^=OK %then %goto exit;
 %end;

 ****************** maxread ************************************;
 %local npred;
 %let npred=0;

 %if &maxread>&_xnobs %then %let maxread=&_xnobs;
 %else %do;
   data _trdata_;
     set &data;
     run;
   %let data=_trdata_;
   %let delds=&delds _trdata_;
 %end;



 ****** compute decision tree ******************************;

 %mtrdiml;

 %if &_numv_ %then %xdelete(_val1-_val&_numv_);

 %if %bquote(&_xrc_)^=OK %then %do;
    %put ERROR: &_xrc_..;
    %goto exit;
 %end;

 %if &_debug_>=3 %then %do;
    proc print data=_tree_; run;
    proc print data=_stat_; run;
    proc print data=_desc_; run;
 %end;

 ************ construct tree data set ***************;
 %let delds=&delds
    _desc_ _split_ _count_ _values_ _tree_ _stat_ _node_ _format_;

 %if %qupcase(&outtree)=_NULL_ %then %goto exit;
 %trdidat
 %if &_xrc_^=OK %then %goto exit;

 ********************* output ***********************;
 %output:
    %trdisym;
    %if &_xrc_^=OK %then %goto exit;

 ******************* list tree ***********************;
 %if &dolist %then %do;
    %trdilst;
    %if &_xrc_^=OK %then %goto exit;
 %end;

 ******************* code for decision tree ***********************;
 %if %bquote(&code)^= %then %do;
    %trdicod;
    %if &_xrc_^=OK %then %goto exit;
 %end;


 ******************* draw tree ***********************;
 %if &draw^=NO %then %do;
    %trdidrw;
    %if &_xrc_^=OK %then %goto exit;
 %end;

 %goto exit;


 ******** miscellaneous error ****************;
 %error:
    %xerrmisc()

 ******** computations finished ****************;
 %exit:

 ******** delete temporary datasets **********;
 %xnotes(0)
 %if %bquote(&delds)^= %then %xdelete(&delds _ __:);

 %let temp=%index(&outtree,%str(%());
 %if &temp %then %let outtree=%xsubstr(&outtree,1,&temp-1);

 options _last_=&outtree;
 %xnotes(1)

 %xterm;

 %mend treedisc;


 %************ extra argument checking ****************;
 %macro trdichk2;
  data _xtmp0;
  set &data;
  stop;
  run;
  %let delds=&delds _xtmp0;
  %let checker=0;
  %if %bquote(&ordinal)^= %then %do;
  %let _list=%bquote(&depvar &freq);
  %trdicom(_xtmp0,%bquote(&_list),%bquote(&ordinal));
  %let checker=%eval(&checker+&_v_err);
  %end;
  %if %bquote(&nominal)^= %then %do;
  %let _list=%bquote(&depvar &freq &ordinal);
  %trdicom(_xtmp0,%bquote(&_list),%bquote(&nominal));
  %let checker=%eval(&checker+&_v_err);
  %end;
  %if %bquote(&ordfloat)^= %then %do;
  %let _list=%bquote(&depvar &freq &ordinal &nominal);
  %trdicom(_xtmp0,%bquote(&_list),%bquote(&ordfloat));
  %let checker=%eval(&checker+&_v_err);
  %end;
  %let delds=&delds _vars1_ _vars2_ _common_;
  %if &checker>0 %then %do;
  %let _xrc_=%qcmpres(%str(The DEPVAR, FREQ, ORDINAL, NOMINAL,
  and ORDFLOAT lists are not mutually exclusive));
  %xput(ERROR: &_xrc_.., depvar freq ordinal nominal ordfloat,
  %str(       ))
  %end;
 %mend trdichk2;


 %************ get levels of the dependent variable ****************;
 %macro trdidep;
  proc freq data=&data order=&order;
  %if %bquote(&freq)^= %then %do; weight &freq; %end;
  %if %bquote(&format)^= %then %do; format %unquote(&format); %end;
  tables &depvar / list noprint missing out=_ycate_(rename=
  (count=_nobs_ &depvar=_ycate) drop=percent);
  run;
  %if &syserr>4 %then %goto error;
  %let delds=&delds _ycate_;
  %xnobs(_nobs,_ycate_)
  %if &_xrc_^=OK %then %goto exit;
  %if &_nobs=0 %then %do;
  %let _xrc_=%qcmpres(No observations in data set &data);
  %put ERROR: &_xrc_..;
  %end;
  %else %if &_nobs=1 %then %do;
  %let _xrc_=%qcmpres(Dependent variable &depvar has only one
  category);
  %put ERROR: &_xrc_..;
  %end;
  data _ycate_(drop=_temp);
  set _ycate_(rename=(_ycate=_temp));
  _ycate=put(_temp,&_yfmt1);
  run;
  %if &syserr>4 %then %goto error;
  %goto exit;
 %error:
  %xerrmisc(getting levels of the dependent variable)
 %exit:
 %mend trdidep;


 %*************** get categories of predictors *****************;
 %macro trdicat;
  %xvlist(data=&data,_list=_varlist,_name=_var,
  _fmt=_fmt_,_count=_numv_,format=&format);
  %let delds= &delds __var;
  %if &_xrc_^=OK %then %goto exit;
  %let _xrc_=%qcmpres(%str(&_numv_ predictors may be too many to
  process without specifying OPTIONS=NOFORMAT.  If there are error
  messages about I/O errors or too many data sets being open,
  either use OPTIONS=NOFORMAT (be sure that the unformatted data
  values define the correct categories in the correct order) or
  increase the number of data sets allowed to be open by whatever
  means is appropriate in your operating system));


  %if &_numv_>50 %then %put WARNING: &_xrc_..;
  %else %if &_numv_>20 %then %put NOTE: &_xrc_..;

  proc freq data=&data order=&order;
  %if %bquote(&format)^= %then %do; format %unquote(&format); %end;
  %do i=1 %to &_numv_;
  tables &&_var&i / list noprint missing
  out=_val&i(drop=count percent);
  %end;
  run;
  %if &syserr>4 %then %do;
  %let _xrc_=%qcmpres(PROC FREQ failed computing marginal
  frequencies);
  %put ERROR: &_xrc_..;
  %goto exit;
  %end;
  %let _xrc_=OK;

  ******** transfer data to formatted values ******;

  %let _rnlist= ;
  %do i=1 %to &_numv_;
  data _val&i(drop=_temp);
  set _val&i(rename=(&&_var&i=_temp));
  &&_var&i=put(_temp,&&_fmt_&i);
  run;
  %if &syserr>4 %then %goto error;
  %let _rnlist=&_rnlist &&_var&i=_temp&i;
  %end;


  %let _rnlist=&_rnlist &depvar=_temp_;
  data _trdata_;
  set &data(rename=(&_rnlist));
  %do i=1 %to &_numv_;
  &&_var&i=put(_temp&i,&&_fmt_&i);
  %end;
  &depvar=put(_temp_,&_yfmt1);
  keep &_varlist &depvar &freq;
  run;
  %if &syserr>4 %then %goto error;

  %let data=_trdata_;
  %if &read %then %let del=1;
  %else %let delds= &delds _trdata_;

  %goto exit;
 %error:
  %xerrmisc(getting levels of the predictor variables)
 %exit:
 %mend trdicat;

 %******************* sort and freq data set *******************;
 %macro trdifrq;
  proc sort data=&data out=_trdata_;
  by &ordinal &nominal &ordfloat;
  run;
  %if &syserr>4 %then %goto error;

  proc freq;
  by &ordinal &nominal &ordfloat;
  tables &depvar /list missing noprint nopercent out=_trdata_;
  %if %bquote(&freq)^= %then %do; weight &freq; %end;
  run;

  %if &syserr>4 %then %goto error;
  %let data=_trdata_;
  %let freq=count;
  %if &read %then %let del=1;
  %else %let delds= &delds _trdata_;


  %goto exit;
 %error:
  %xerrmisc(reducing data set to frequencies)
 %exit:
 %mend trdifrq;

 %************ construct tree data set ***************;
 %macro trdidat;

  *** do missing values ***;
  data _desc_; set _desc_;
  if _type_='VALUES_' then if _value_=' ' then _value_='.';
  run;
  %if &syserr>4 %then %goto error;

  *** do p-values ***;
  data _stat_; set _stat_; length pvalues_ $41;
  if pval1_=. then pvalues_=' ';
  else do;
  pvalues_=put(&pmin<>pval1_,&pformat);
  if pval2_^=. then
  pvalues_=trim(pvalues_)||' '||put(&pmin<>pval2_,&pformat);
  end;
  run;
  %if &syserr>4 %then %goto error;
  %if &_debug_>=2 %then %do;
  proc print data=_stat_; run;
  %end;

  *** do split var, type, and scale ***;
  proc sort data=_desc_; by _from_; run;
  %if &syserr>4 %then %goto error;


  proc transpose
  data=_desc_(where=(_type_ in
  ('SPLIT_' 'TYPE_' 'SCALE_' 'UPPERB_' 'LOWERB_')))
  out=_split_(drop=_name_);
  id _type_;
  var _value_;
  by _from_;
  run;
  %if &syserr>4 %then %goto error;
  %if &_debug_>=2 %then %do;
  proc print data=_count_; run;
  %end;

  *** do dependent variable counts ***;
  proc transpose data=_desc_(where=(_type_='COUNT_'))
  out=_count_(drop=_name_)
  prefix=_cou;
  var _value_;
  by _from_;
  run;
  %if &syserr>4 %then %goto error;
  %if &_debug_>=2 %then %do;
  proc print data=_count_; run;
  %end;

  %xnvar(ndvc,_count_,_cou:)
  %if &_xrc_^=OK %then %goto exit;

  %trdisqz(_count_,_cou1-_cou&ndvc,count_)
  %if &_xrc_^=OK %then %goto exit;

  data _count_; set _count_;
  drop _p;
  array _cou _cou1-_cou&ndvc;
  array _pct $8 _pct1-_pct&ndvc;
  array _pcn $8 _pcn1-_pcn&ndvc;
  retain total_ 0;
  size_=0;
  errors_=0;
  do over _cou;
  _p=input(_cou,12.);
  size_+_p;
  errors_=max(errors_,_p);
  end;
  errors_=size_-errors_;
  if _n_=1 then total_=size_;
  do over _cou;
  _p=100*input(_cou,12.)/total_;
  if _p>9.5 | _p=0 then _pct=put(_p,3.)||'%';
  else if _p>.95 then _pct=put(_p,5.1)||'%';
  else if _p>.095 then _pct=put(_p,6.2)||'%';
  else _pct=put(_p,7.3)||'%';
  _p=100*input(_cou,12.)/size_;
  if _p>9.5 | _p=0 then _pcn=put(_p,3.)||'%';
  else if _p>.95 then _pcn=put(_p,5.1)||'%';
  else if _p>.095 then _pcn=put(_p,6.2)||'%';
  else _pcn=put(_p,7.3)||'%';
  end;
  run;
  %if &syserr>4 %then %goto error;


  %trdisqz(_count_,_pct1-_pct&ndvc,pctotal_)
  %if &_xrc_^=OK %then %goto exit;

  %trdisqz(_count_,_pcn1-_pcn&ndvc,pcnode_)
  %if &_xrc_^=OK %then %goto exit;

  *** do category values ***;
  proc transpose data=_desc_(where=(_type_='VALUES_'))
  out=_values_(drop=_name_)
  prefix=_val;
  var _value_;
  by _from_;
  run;
  %if &syserr>4 %then %goto error;
  %if &_debug_>=2 %then %do;
  proc print data=_values_; run;
  %end;

  %trdisqz(_values_,_val:,values_)
  %if &_xrc_^=OK %then %goto exit;

  *** do formats ***;
  data _format_;
  set
  %if %bquote(&ordinal)^= %then __ord;
  %if %bquote(&ordfloat)^= %then __orf;
  %if %bquote(&nominal)^= %then __nom;
  ;
  length _format_ $15;
  split_=name;
  if type=1 then _vtype_='N';
  else _vtype_='C';
  %if &noformat %then %do;
  _format_=' ';
  %end;
  %else %do;
  if format=' ' then do;
  if type=1 then do;
  if formatl=0 then _format_='BEST';
  end;
  else _format_='$';
  end;
  else _format_=format;
  if formatl then _format_=trim(_format_)||
  trim(left(put(formatl,3.)));
  _format_=trim(_format_)||'.';
  if formatd then _format_=trim(_format_)||
  trim(left(put(formatd,3.)));
  %end;
  keep split_ _vtype_ _format_;
  run;
  %if &syserr>4 %then %goto error;
  proc sort data=_format_; by split_; run;
  %if &syserr>4 %then %goto error;
  proc sort data=_split_; by split_; run;
  %if &syserr>4 %then %goto error;
  data _split_;
  merge _split_ _format_;
  by split_;
  if _from_=. then delete;
  run;
  %if &syserr>4 %then %goto error;



  *** merge everything ***;
  proc sort data=_split_; by _from_; run;
  %if &syserr>4 %then %goto error;
  proc sort data=_stat_; by _from_; run;
  %if &syserr>4 %then %goto error;
  proc sort data=_tree_; by _from_; run;
  %if &syserr>4 %then %goto error;

  %xnotes(1)
  data &outtree(type=treedisc);
  merge _tree_ _split_ _stat_ _count_ _values_;
  by _from_;
  node_=_from_;

  *** find INTO, ties, post prob ***;
  drop _n _m _sum _i _x _dv1-_dv&ndvc;
  array _cou[*] _cou:;
  array _val[*] _val:;
  if dim(_cou)=0|dim(_val)=0 then return;
  if _from_=1 then if first._from_ then do;
  %do i=1 %to &ndvc;
  _dv&i=_val&i;
  * put _dv&i=;
  %end;
  end;
  array _dv[*] _dv1-_dv&ndvc;
  retain _dv1-_dv&ndvc;
  _n=-1;
  tie_=0;
  _m=0;
  _sum=0;
  do _i=1 to dim(_cou);
  _x=input(_cou[_i],12.);
  _sum+_x;
  if _m=_x then tie_+1; else
  if _m<_x then do;
  _m=_x;
  tie_=0;
  _n=_i;
  end;
  end;
  if tie_=0 then do;
  into_=_dv[_n];
  post_=_m/_sum;
  end;
  else do;
  tie_+1;
  into_=' ';
  post_=.;
  end;




  run;
  %if &syserr>4 %then %goto error;
  %let outtree=&syslast;

  %goto exit;
 %error:
  %xerrmisc(constructing OUTTREE= data set)
 %exit:
 %mend trdidat;


 %macro trdisqz(data,var,new);
  %local len;
  %let len=0;

  data _null_; set &data end=_end;
  array _var[*] &var;
  retain _maxlen 1;
  if dim(_var) then _len=length(left(_var[1]));
  do _i=2 to dim(_var);
  if _var[_i]=' ' then goto break;
  _len+&space+length(left(_var[_i]));
  end;
 break:
  if _len>=200 then do;
  _len=200;
  _end=1;
  end;
  _maxlen=max(_maxlen,_len);
  if _end then do;
  call symput("len",trim(left(put(_maxlen,5.))));
  stop;
  end;
  run;
  %if &syserr>4 %then %goto error;
  %if &_debug_ %then %put TRDISQZ: len=&len;
  %if &len<8 %then %let len=8;


  data &data; set &data;
  drop _i _j _l _v;
  array _var[*] &var;
  length &new $ &len;
  if dim(_var) then &new=left(_var[1]);
  _l=length(&new);
  do _i=2 to dim(_var);
  if _var[_i]=' ' then goto break;
  _v=left(_var[_i]);
  _j=length(_v);
  if _l+&space+_j>&len then do;
  _l=min(_l,%eval(&len-&space-5));
  substr(&new,_l+%eval(&space+1),5)=' etc.';
  goto break;
  end;
  substr(&new,_l+%eval(&space+1),_j)=substr(_v,1,_j);
  _l+&space+_j;
  end;
 break:
  run;
  %if &syserr>4 %then %goto error;

  %goto exit;
 %error:
  %xerrmisc(concatenating variables)
 %exit:
 %mend trdisqz;


 %**************** get macro vars from data set *******************;
 %macro trdisym;
  data _null_; set &outtree;
  if _from_=1 then do;
  call symput("depvar",split_);
  stop;
  end;
  run;
  %if &syserr>4 %then %xerrmisc(reading INTREE=/OUTTREE= data set);
  %xbug(From intree/outree data set, depvar)
 %mend trdisym;



 %******************* list tree ***********************;
 %macro trdilst;
  %local n line;
  %xnotes(0)
  proc sort data=&outtree; by _order_; run;
  %if &syserr>4 %then %goto error;
  %xnobs(_ntree,&outtree)
  %if &_ntree<2 %then %let _ntree=2;
  data _null_;
  file print column=_col;
  if _n_=1 then
  put "TREEDISC Analysis of Dependent Variable (DV) &depvar"/;
  array _size [&_ntree] _temporary_
  ( %do i=1 %to &_ntree; 99 %end; );
  retain _indent 1 _ns 1;
  set &outtree;
  by _from_ notsorted;
  if _from_<1 then return;
  if first._from_ then do;
  %if %bquote(&listvar)= %then %do;
  put @_indent split_ 'value(s): ' values_;
  put @_indent 'DV counts: ' count_ @;
  if pvalues_^=' ' then put ' Best p-value(s): ' pvalues_ @;
  put /;
  %end;
  %else %do n=1 %to 99;
  %let line=%qscan(&listvar,&n,/);
  %if &line= %then %do;
  %if %qsubstr(&listvar,%length(&listvar),1)=%str(/)
  %then put%str(;);
  %let n=99;
  %end;
  %else %do;
  put @_indent %unquote(&line) @@;
  if _col>_indent+2 then put;
  %end;
  %end;
  _size[_ns]=_size[_ns]-1;
  _ns+1;
  _size[_ns]=0;
  _indent+&indent;
  end;
  if _to_^=. then _size[_ns]+1;
  if last._from_ then do;
  do while(_size[_ns]=0);
  _ns=_ns-1;
  _indent=_indent-&indent;
  end;
  end;
  run;
  %if &syserr>4 %then %goto error;
  %goto exit;
 %error:
  %xerrmisc(listing tree)
 %exit:
 %mend trdilst;



 %**************** generate code for decision tree *****************;
 %macro trdicod;
  %local ntree ncou nval;
  %xnotes(0)
  proc sort data=&outtree; by _order_; run;
  %if &syserr>4 %then %goto error;
  data _null_;
  set &outtree nobs=_ntree;
  call symput("ntree",trim(left(put(_ntree,12.))));
  array _cou[*] _cou:;
  array _val[*] _val:;
  _ncou=dim(_cou);
  _nval=dim(_val);
  call symput("ncou",trim(left(put(_ncou,12.))));
  call symput("nval",trim(left(put(_nval,12.))));
  if _ncou=0|_nval=0 then return;
  if _from_<1 then return;
  _dvn=1;
  _dvl=1;
  do _i=1 to _nval;
  if _val[_i]^=' ' then do;
  _dvn=_i;
  _dvl=max(_dvl,length(_val[_i]));
  end;
  end;
  call symput("dvn",trim(left(put(_dvn,12.))));
  call symput("dvl",trim(left(put(_dvl,12.))));
  call symput("dvtype",trim(left(type_)));
  stop;
  run;
  %if &syserr>4 %then %goto error;
  %if &ntree<2 %then %let ntree=2;
  %xbug(,ntree ncou nval dvn dvl dvtype)
  data _null_;
  file %unquote(&code);


  array _size [&ntree] _temporary_
  ( %do i=1 %to &ntree; 999 %end; );
  retain _indent 1 _first _ns 1;
  retain _backsp_ -1;
  length _lb _ub $18;

  set &outtree end=_end;
  by _from_ notsorted;
  if _from_<1 then return;

  array _cou[*] _cou:;
  array _val[*] _val:;

  if first._from_ & _from_=1 then do;
  put "*** TREEDISC Decision Tree Code ***;" ;
  %if &dvtype=C %then %do;
  length _into_ $ %eval(&dvl+2);
  put @%eval(&indent+1) "length into_ $ &dvl;" ;
  %do i=1 %to &dvn;
  _dv&i="'"||trim(left(_val[&i]))||"'";
  %end;
  %end;
  %else %do;
  length _into_ $ &dvl;
  %do i=1 %to &dvn;
  _dv&i=input(_val[&i],12.);
  %end;
  %end;
  end;


  array _dv[*] _dv1-_dv&dvn;
  retain _dv1-_dv&dvn;

  if first._from_ then do;
  if _from_>1 then do;
  if scale_='ORDINAL' & _format_=' ' then do;
  put @_indent "if " @@;
  _lb=lowerb_;
  _ub=upperb_;
  if type_='C' then do;
  if _lb^=' ' then _lb="'"||trim(_lb)||"'";
  if _ub^=' ' then _ub="'"||trim(_ub)||"'";
  end;
  else do;
  if _lb='.' then do;
  put "nmiss( " split_ ") " @@;
  _lb="&neginf";
  if _ub='.' then goto then;
  put " or " @@;
  end;
  end;
  if _lb=_ub then do;
     if _ub=' ' then put split_ "= ' ' " @@;
     else put split_ "= " _ub " " @@;
  end;
  else do;
  if _lb^=' ' then
  put _lb "<= " @@;
  put split_ @@;
  if _ub^=' ' then
  put "<= " _ub @@;
  end;
 then:
  put "then do;" ;
  end;
  else do; * formatted or not ORDINAL;
  if _format_=' ' then do;
  if _first then if _vtype_='N' then do;
  _first=0;
  put @_indent "if nmiss( " split_ ") then "
  split_ "= .;" ;
  end;
  put @_indent "if " split_ "in ( " @@;
  end;
  else do;
  fsplit_='_'||substr(split_,1,7);
  if _first then do;
  _first=0;
  put @_indent "drop " fsplit_ +_backsp_ ";" ;
  if _vtype_='N' then do;
  put @_indent fsplit_
  "= left(putn( "
  split_
  ", '"
  _format_ +_backsp_
  "'));" ;
  end;
  else do;
  put @_indent fsplit_
  "= left(putc( "
  split_
  ", '"
  _format_ +_backsp_
  "'));" ;
  end;
  end;
  put @_indent "if "
  fsplit_
  "in ( " @@;
  end;
  do _i=1 to &nval;
  if _val[_i]=' ' then _i=&nval;
  else do;
  if type_='C' then do;
  put "'" @@;
  if _val[_i]='.'
  then put ' ' @@;
  else put _val[_i] +_backsp_ @@;
  put "' " @@;
  end;
  else put _val[_i] @@;
  end;
  end;
  put ") then do;" ;
  end;
  end;
  _size[_ns]=_size[_ns]-1;
  _ns+1;
  _size[_ns]=0;
  _indent+&indent;


  put @_indent "* DV counts: " count_ ";" ;
  put @_indent "node_ = " _from_ +_backsp_ ";" ;
  _n=-1;
  _tie_=0;
  _m=0;
  _sum=0;
  do _i=1 to &ncou;
  _x=input(_cou[_i],12.);
  _sum+_x;
  if _m=_x then _tie_+1; else
  if _m<_x then do;
  _m=_x;
  _tie_=0;
  _n=_i;
  end;
  end;
  if _tie_ then do;
  _tie_+1;
  _into_=
  %if &dvtype=C %then "' '"; %else .;
  ;
  _post_=.;
  end;
  else do;
  _into_=_dv[_n];
  _post_=_m/_sum;
  end;
  put @_indent "into_ = " _into_ +_backsp_ ";" ;
  put @_indent "tie_ = " _tie_ +_backsp_ ";" ;
  put @_indent "post_ = " _post_ +_backsp_ ";" ;


  end;

  if _to_^=. then do;
  _size[_ns]+1;
  end;

  if last._from_ then do;
  _first=1;
  do while(_size[_ns]=0);
  _ns=_ns-1;
  if _ns<1 then do;
  error 'ERROR: Tree structure is invalid ';
  stop;
  end;
  _indent=_indent-&indent;
  if _ns>1 then do;
  put @_indent "end;" ;
  if _size[_ns]>0 then do;
  put @_indent "else" ;
  _first=0;
  end;
  end;
  end;
  end;

  if _end then do;
  if _ns^=1 then do;
  error 'ERROR: Tree structure is invalid ';
  stop;
  end;
  end;

  run;
  %if &syserr>4 %then %goto error;
  %goto exit;
 %error:
  %xerrmisc(listing tree)
 %exit:
 %mend trdicod;

 %******************* draw tree ***********************;
 %macro trdidrw;
  %xchkvar(&outtree,,&drawvar)
  %if &_xrc_^=OK %then %goto exit;
  %xnotes(1)
  &pattern;
  proc netdraw data=&outtree %unquote(&draw) %unquote(&netopt);
  actnet  / id=(&drawvar) boxwidth=&box %unquote(&actopt)
  %if %bquote(&ctext)^= %then ctext=&ctext;
  %if %bquote(&clines)^= %then %do;
     carcs=&clines
     %if &draw=GRAPHICS %then coutline=&clines;
  %end;
  ;
  where _from_>0;
  run;
  %if &syserr>4 %then %goto error;
  %goto exit;
 %error:
  %xerrmisc(drawing tree)
 %exit:
 %mend trdidrw;


 %macro trdicom(data,varlist1,varlist2);
  %global _v_err;
  %let _v_err=0;

  proc contents data=&data(keep=&varlist1)
  noprint out=_vars1_(keep=name);run;
  proc contents data=&data(keep=&varlist2)
  noprint out=_vars2_(keep=name);run;
  proc sql;
  create table _common_ as select _vars1_.name from
  _vars1_,_vars2_ where _vars1_.name=_vars2_.name;
  data _null_;
  if 0 then set _common_ nobs=count;
  if count>0 then call symput('_v_err','1');
  stop;
  run;
 %mend trdicom;

  ********************************************************************
  call IML program
  *******************************************************************;

 %macro mtrdiml;

 %global _xrc_;

 %local bigp biggerp;
 %let bigp=10;    %* must be greater than any possible pvalue;
 %let biggerp=21; %* must be at least 2*bigp for nominal split alg.;


 proc iml;

 call symput("_xrc_","IML failed during TREEDISC computation");

 depvar={ &depvar };
 %if %bquote(&freq)= %then  %let mfreq= ; %else %do;
   freq={ &freq };
   %let mfreq=freq;
 %end;
 %if %bquote(&ordinal)= %then %let mord= ; %else %do;
   ordinal={ &ordinal };
   %let mord=ordinal;
 %end;
 %if %bquote(&nominal)= %then %let mnom= ; %else %do;
   nominal={ &nominal };
   %let mnom=nominal;
 %end;
 %if %bquote(&ordfloat)= %then %let mflo= ; %else %do;
   ordfloat={ &ordfloat };
   %let mflo=ordfloat;
 %end;

 parm={ &merge, &split, &alpha, &maxdepth, &nomsplit, &ordsplit, &trace,
 &maxread, &limit, &read };


 reset nolog noname noautoname nocenter;

 *________________________START MODULE TABPROB_________________________*

  Calculates the chi-squared probability of the input contingency table.

  Inputs:
  table: a contingency table, assumed no all-zero rows.

  c: number of rows of table.

  Output:
  pvalue: the chi-squared tail probability.

 *________________________________________________________________________*;

 START TABPROB(TABLE,C) GLOBAL (_CHISQ,_trace,_cols);

  if _trace>=100 then print "Tabprob: Contingency table", table;
  R=TABLE[+,];
  S=LOC(R>0);
  R=R[,S];
  _cols=NCOL(S);
  IF _cols<=1 THEN do;
  _chisq=0;
  pvalue=&bigp;
  end;
  else do;
  f=TABLE[,+];
  EXPN=f*R;
  EXPN=EXPN/SUM(R);
  _CHISQ=(TABLE[,S]-EXPN)##2;
  _CHISQ=_CHISQ/EXPN;
  _CHISQ=SUM(_CHISQ);
  pvalue=pvalue(_chisq,c,_cols);
  f=sum(f<&leaf);
  if f>0 then pvalue=pvalue+2-1/f;
  if _trace>=99 then print "Tabprob: Chi-sq =" _chisq " p =" pvalue;
  end;
  RETURN(PVALUE);


 FINISH;

 start pvalue(x,c,d);
  df=(c-1)#(d-1);
  if x>df+3#sqrt(2#df) then p=probf(df/x,1e9,df);
  else p=1-probchi(x,df);
  return(p);
 finish;


 *____________________START ORDMG_________________________________________*

  Repeat merging ordinal categories until every contiguous pair are
  significanlt different.

  Input:
  alpham: merge criterion.
  ptable: cross tabulation  of the predictor and the dependent variable.
  nxcate: number of categories of the predictor in the current group.
  pvalue: chi-squared probability values of each contiguous pair of
  categories. Suppose there are k categories than pvalue is
  1x(k-1) with the i-th element being the probabilty between
  the i-th and (i+1)th category.
  catenm: numbering of the categories.
  newcate:indicator matrix of categories.


  Output:
  pvalue,catenm,newcate.

 *________________________________________________________________________*;

 START ORDMG(flag,_updatep,CATES,NAMES,PV,NXCATE,PTABLE,ALPHAM,ichaid)
  global(_ginturn,_prednam,_trace);

  newcate=cates; catenm=names; pvalue=pv;
  _NCATE=NROW(NEWCATE);

  _h=_updatep;
  DOX=1:NXCATE;
  flag=0;
  if _ncate<=2 then cont=0;
  else CONT=1;

  DO WHILE (CONT=1);

  _NCATE=NROW(NEWCATE);
 if _trace>=9 then print _ginturn _prednam
  "Ordinal merge ncat" _ncate;

  DO J=1 TO _NCATE-1;

  IF PVALUE[1,J] > &bigp THEN do;


  table=NEWCATE[J:J+1,]*PTABLE;
  d=table[,+];
  d=d[><];
  PVALUE[1,J]=TABPROB(TABLE,2);
  end;

  END;
  if _h=_updatep then pv=pvalue;

 if _trace>=10 then print _ginturn _prednam
  "Ordinal merge p-values" pvalue;
  D=PVALUE[<:>];
 if _trace>=9 then print _ginturn _prednam
  "Ordinal merge best" d (pvalue[d]);
  IF PVALUE[D] > ALPHAM  THEN


  DO;

  NEWCATE[D,]=NEWCATE[D,]+NEWCATE[D+1,];
  NEWCATE=REMOVE(NEWCATE,NXCATE#D+1:NXCATE#(D+1));
  NEWCATE=SHAPE(NEWCATE,0,NXCATE);
  IF D>1 THEN PVALUE[1,D-1]=&biggerp  ;
  IF D<_NCATE-1 THEN PVALUE[1,D+1]=&biggerp  ;
  PVALUE=REMOVE(PVALUE,D);
  IF SUM(NEWCATE[D,])>=3 THEN
  CATENM[1,D]=MAX(CATENM[<>],NXCATE)+1;
  ELSE CATENM[1,D]=MAX(SETDIF(DOX,CATENM));
  CATENM=REMOVE(CATENM,D+1);
  _ncate=_ncate-1;
  IF _ncate=2 THEN CONT=0;

  _H=TABPROB(NEWCATE*PTABLE,_NCATE);
 if _trace>=9 then print "After merge overall p =" _h _ncate;
  if (_h<min(1,_updatep+&afuzz) | ichaid=1) then do;
  cates=newcate;names=catenm;pv=pvalue;
  flag=1;
  _updatep=_h;
  end;
  END;
  ELSE CONT=0;
 *print "_updatep = " _updatep;
  END;


 FINISH;


 *_________________________START ORDSPL_________________________________________*

  Inspect each compound category for possible binary split where the orginal
  categories are on a ordinal scale.


  Input:
  alphas: splitting creterion.
  ptable,nxcate,catenm,pvalue,newcate: see modules ordmg.
  compcate: compound categories position.

  Output:
  ptable,nxcate,catenm,pvalue,newcate: see modules ordmg.
  flag: control flag, if binary split happens need to check if they can
  be collapsed with others.


 *_____________________________________________________________________*;


 START ORDSPL(FLAG,_updatep,CATES,NAMES,PV,COMPCATE,NXCATE,
  PTABLE,ALPHAS,ordsplit,ichaid)
  global(_ginturn,_prednam,_trace);

 if _trace>=9 then do;
  ncate=nrow(cates);
  print _ginturn _prednam
  "Ordinal split ncat" ncate;
 end;
  newcate=cates;catenm=names;pvalue=pv;
  _h=_updatep;
  DOX=1:NXCATE;
  cont=1;
  FLAG=0;
 *print "_updatep" _updatep;
  do while (cont=1);
  _ncate=ncol(compcate);
  if _ncate>0 then do;
  COMPCATE=CATENM[1,COMPCATE];


  DO D=1 TO _ncate;

  J=LOC(CATENM=COMPCATE[1,D]);

  P=&bigp  ;
  POS=LOC(NEWCATE[J,]=1);
  nmember=ncol(pos);
  if nmember>ordsplit then do;
  if _trace>=9 then print _ginturn _prednam
  "No ordinal splits considered for compound category" d
  " of size " nmember;
  end;
  else do;
  PSPLIT=J(2,NXCATE,0);
  DO K=1 TO NCOL(POS)-1;
  PSPLIT[1,POS[1,1:K]]=1;
  PSPLIT[2,]=NEWCATE[J,]-PSPLIT[1,];
  table=PSPLIT*PTABLE;
  l=table[,+];
  l=l[><];
  Q=TABPROB(TABLE,2);
 if _trace>=9 then print _ginturn _prednam
  "Ordinal split" k "p-value" q;
  IF P>Q THEN do;
  SPLIT=POS[K];
  P=Q;
  END;
  END;

  end;
  IF P < ALPHAS THEN posbspl=posbspl//(compcate[d]||split||p);
  ELSE CATENM[1,J]=MAX(SETDIF(DOX,CATENM));
  END;
  free compcate psplit pos;
  end;
  if _h=_updatep then names=catenm;
  IF nrow(posbspl)>0 THEN
  DO;
 *print "posbspl" posbspl;
  d=posbspl[>:<,3];
  j=loc(catenm=posbspl[d,1]);
  split=j(1,nxcate,0);
  q=posbspl[d,2]+1;
  split[q:nxcate]=newcate[j,q:nxcate];
  p=posbspl[d,3];
 if _trace>=9 then print _ginturn _prednam
  "Ordinal split best" j "p-value" p;
  ncate=nrow(newcate);
  NEWCATE=INSERT(NEWCATE,split,J+1,0);
  NEWCATE[J,]=newcate[j,]-split;
  free split;


  IF J>1 THEN PVALUE[1,J-1]=&biggerp  ;
  PVALUE=INSERT(PVALUE,p,0,J);
  IF J<NCATE THEN PVALUE[1,J+1]=&biggerp  ;
 if _trace>=9 then print "P-values after split" pvalue;
  CATENM=INSERT(CATENM,0,0,J);

  IF SUM(NEWCATE[J,])>=3 THEN do;
  CATENM[1,J]=MAX(CATENM[<>],NXCATE)+1;
  compcate=j;
  end;
  ELSE CATENM[1,J]=MAX(SETDIF(DOX,CATENM));

  IF SUM(NEWCATE[J+1,])>=3 THEN do;
  CATENM[1,J+1]=MAX(CATENM[<>],NXCATE)+1;
  compcate=compcate||J+1;
  end;
  ELSE CATENM[1,J+1]=MAX(SETDIF(DOX,CATENM));

  posbspl=remove(posbspl,3#d-2:3#d);
  if ncol(posbspl)>0 then
  posbspl=shape(posbspl,ncol(posbspl)/3);

  _ncate=nrow(newcate);
  _h=tabprob(newcate*ptable,_ncate);
 if _trace>=9 then
  print "After split overall p =" _h _ncate;
  if (ichaid=1 | (_h<1 & _h<_updatep-nxcate#&afuzz)) then do;
  cates=newcate;names=catenm;pv=pvalue;
  flag=1;
  _updatep=_h;
  end;
  END;

  ELSE CONT=0;
 *print "_updatep = " _updatep;
  end;

 FINISH;


 *____________________________START NOMMG______________________________________*

  Repeat collapsing nominal categories until all are mutually different.

  Input:
  alpham,ptable,nxcate,catenm,newcate: see ordmg.
  pvalue: (k-1)x(k-1) if there are k categories. The (i,j)th, i<j, element
  stores the probability between i-th and (j+1)th category.
  Output:
  newcate,catenm,pvalue.


 *_____________________________________________________________________________*;


 START NOMMG(flag,_updatep,CATES,NAMES,PV,NXCATE,PTABLE,ALPHAM,ichaid)
  global(_ginturn,_prednam,_trace);

  newcate=cates;catenm=names;pvalue=pv;
  flag=0;
  _NCATE=NROW(NEWCATE);
  _h=_updatep;
  DOX=1:NXCATE;
  if _ncate<=2 then cont=0;
  else CONT=1;

  DO WHILE (CONT=1);

  L=NROW(PVALUE);
  DO A=1 TO L;
  DO B=A TO L;
  IF PVALUE[A,B] > &bigp THEN
  DO;
  CTABLE=INSERT(NEWCATE[A,],NEWCATE[B+1,],2,0);
  CTABLE=CTABLE*PTABLE;
  d=ctable[,+];
  d=d[><];
  PVALUE[A,B]=TABPROB(CTABLE,2);
  END;
  END;
  END;
  free ctable;
  IF L=NXCATE-1 THEN PVALUE=PVALUE><(2#PVALUE`-PVALUE);

 if _trace>=10 then print _ginturn _prednam
  "Nominal p-values" pvalue;
  if _h=_updatep then pv=pvalue;


  D=PVALUE[<:>];
  IF PVALUE[D] > ALPHAM THEN
  DO;

  B=MOD(D-1,L)+2;
  A=INT((D-1)/L)+1;
 if _trace>=9 then print _ginturn _prednam
  "Nominal merge best" A B (pvalue[d]);

  NEWCATE[A,]=NEWCATE[A,]+NEWCATE[B,];
  NEWCATE=INSERT(NEWCATE,NEWCATE[A,],L+2,0);
  DINDEX=1:NROW(NEWCATE);
  DINDEX=REMOVE(DINDEX,A||B);
  NEWCATE=NEWCATE[DINDEX,];

  IF SUM(NEWCATE[L,])>=3 THEN
  CATENM=INSERT(CATENM,MAX(CATENM[<>]+1,NXCATE+1),0,L+2);
  ELSE CATENM=INSERT(CATENM,MAX(SETDIF(DOX,CATENM)),0,L+2);
  CATENM=CATENM[1,DINDEX];

  PVALUE=INSERT(PVALUE,J(1,L,-1),L+1,0);
  PVALUE=INSERT(PVALUE,J(L+1,1,&biggerp  ),0,L+1);


  DINDEX=DO(0,L,1)#(L+1)+B-1;
  PVALUE=REMOVE(PVALUE,DINDEX);
  IF A=1 THEN DINDEX=DO(0,L,1)#L+1;
  ELSE  DINDEX=DO(0,L,1)#L+A-1;
  PVALUE=REMOVE(PVALUE,DINDEX);

  DINDEX=DO(1,L-1,1)+(A-1)#(L-1);
  PVALUE=REMOVE(PVALUE,DINDEX);
  IF B=L+1 THEN DINDEX=DO(1,L-1,1)+(L-1)#(L-1);
  ELSE DINDEX=DO(1,L-1,1)+(B-2)#(L-1);
  PVALUE=REMOVE(PVALUE,DINDEX);
  PVALUE=SHAPE(PVALUE,0,L-1);
  if l=2 then CONT=0;

  _NCATE=_NCATE-1;
  _H=TABPROB(NEWCATE*PTABLE,_NCATE);
 if _trace>=9 then print "After merge overall p =" _h _ncate;
  if (ichaid=1 | _h<min(1,_updatep+&afuzz)) then do;
  cates=newcate;names=catenm;pv=pvalue;
  flag=1;
  _updatep=_h;
  end;
  END;

  ELSE CONT=0;
 *print "_updatep = " _updatep;

  END;
 FINISH;


 *_______________________  START NOMSPL   ___________________________________*

  Look for binary split of compound categories where the original categories
  are nominal.


  Inputs and Outputs: see module ordspl.

 *____________________________________________________________________________*;


 START NOMSPL(FLAG,_updatep,CATES,NAMES,PV,COMPCATE,NXCATE,
  PTABLE,ALPHAS,nomsplit,ichaid)
  global(_ginturn,_prednam,_trace);

  newcate=cates;catenm=names;pvalue=pv;
  _h=_updatep;
  DOX=1:NXCATE;
  FLAG=0;
  cont=1;
 *print "_updatep" _updatep;
  do while (cont=1);
  _ncate=ncol(compcate);

  if _ncate>0 then do;

  COMPCATE=CATENM[1,COMPCATE];
 *print "compcate" compcate;
  DO D=1 TO _ncate;

  J=LOC(CATENM=COMPCATE[1,D]);

  POS=LOC(NEWCATE[J,]=1);
  NMEMBER=NCOL(POS);
  P=&bigp  ;
  dcnum=newcate[j,]*ptable;
  dcnum=loc(dcnum>0);
 * print "nmember =" nmember " nomsplit =" nomsplit;
  if nmember>nomsplit then do;
  if _trace>=9 then print _ginturn _prednam
  "No nominal splits considered for compound category" d
  " of size " nmember;
  end;
  else if ncol(dcnum)=2 then do;
  table=ptable[,dcnum];
  table=table[pos,];
  dcnum=rank(table[,1]/table[,+]);
  _temp=table[,1];table[dcnum,1]=_temp;
  _temp=table[,2];table[dcnum,2]=_temp;


  L=nrow(table);
  DO K=1 TO L-1;
  psplit=j(2,L,0);
  PSPLIT[1,1:K]=1;
  PSPLIT[2,]=J(1,L,1)-PSPLIT[1,];
  ctable=psplit*table;
  m=ctable[,+];
  m=m[><];
  Q=TABPROB(CTABLE,2);
  IF P>Q THEN do;
  SPLIT=K;
  P=Q;
  END;
  END;

  split=loc(dcnum<=split);
  split=pos[split];
  psplit=j(2,nxcate,0);
  psplit[1,split]=1;
  psplit[2,]=newcate[j,]-psplit[1,];
  split=psplit;
  free psplit;
  end;
  else do;
  PSPLIT=J(2,NXCATE,0);
  SPVEC=J(1,NMEMBER,0);
  L=1;
  DO UNTIL (L > 2##(NMEMBER-1)-1);

  R=SPVEC[>:<];
  SPVEC[,1:R]=J(1,R,1)-SPVEC[,1:R];
  L=L+1;
  PSPLIT[1,POS]=SPVEC;
  PSPLIT[2,]=NEWCATE[J,]-PSPLIT[1,];
  ctable=psplit*ptable;
  m=ctable[,+];
  m=m[><];
  Q=TABPROB(CTABLE,2);
  IF P>Q THEN DO;
  SPLIT=PSPLIT;
  P=Q;
  END;
  END;


  end;
 if (_trace>=9 & p<&bigp) then print _ginturn _prednam
  "Nominal split compound category" d "best p" p;

  IF P < ALPHAS THEN
  posbspl=posbspl//(p||compcate[d]||split[1,]||split[2,]);
  ELSE CATENM[1,J]=MAX(SETDIF(DOX,CATENM));
  end;
  free compcate psplit;
  end;
  if _h=_updatep then names=catenm;
  IF nrow(posbspl)>0 then DO;

 *print "posbspl" posbspl;
  d=posbspl[>:<,1];
  j=loc(catenm=posbspl[d,2]);
  p=posbspl[d,1];
  split=posbspl[d,3:nxcate+2]//posbspl[d,nxcate+3:2#nxcate+2];
  posbspl=remove(posbspl,(2#nxcate+2)#(d-1)+1:(2#nxcate+2)#d);
  if ncol(posbspl)>0 then
  posbspl=shape(posbspl,ncol(posbspl)/(2#nxcate+2));

  NCATE=NROW(NEWCATE);
  NEWCATE=INSERT(NEWCATE,SPLIT,NCATE+1,0);
  NEWCATE=REMOVE(NEWCATE,(J-1)#NXCATE+1:J#NXCATE);
  NEWCATE=SHAPE(NEWCATE,0,NXCATE);

  IF SUM(SPLIT[1,])>=3 THEN do;
  CATENM=INSERT(CATENM,MAX(CATENM[<>],NXCATE)+1,0,NCATE+1);
  compcate=ncate;
  end;
  ELSE CATENM=INSERT(CATENM,MAX(SETDIF(DOX,CATENM)),0,NCATE+1);
  IF SUM(SPLIT[2,])>=3 THEN do;
  CATENM=INSERT(CATENM,MAX(CATENM[<>],NXCATE)+1,0,NCATE+2);
  compcate=compcate||ncate+1;
  end;
  ELSE CATENM=INSERT(CATENM,MAX(SETDIF(DOX,CATENM)),0,NCATE+2);
  CATENM=REMOVE(CATENM,J);


  IF NCATE=1 THEN PVALUE=P;
  ELSE IF NCATE=2 THEN
  PVALUE={&biggerp &biggerp  }//(-1||P);
  ELSE DO;
  IF J=NCATE THEN PVALUE=PVALUE[1:NCATE-2,];
  ELSE DO;
  DINDEX=DO(1,NCATE-1,1)+(J-1)#(NCATE-1);
  PVALUE=REMOVE(PVALUE,DINDEX);
  END;

  IF J=1 THEN DINDEX=DO(0,NCATE-3,1)#(NCATE-1)+1;
  ELSE DINDEX=DO(0,NCATE-3,1)#(NCATE-1)+J-1;
  PVALUE=REMOVE(PVALUE,DINDEX);
  PVALUE=SHAPE(PVALUE,NCATE-2,0);

  PVALUE=INSERT(PVALUE,J(2,NCATE-2,-1),NCATE-1,0);
  PVALUE=INSERT(
  PVALUE,J(NCATE,2,&biggerp  ),0,NCATE-1);
  PVALUE[NCATE,NCATE-1:NCATE]=-1||P;
  END;

  _ncate=nrow(newcate);
  _h=tabprob(newcate*ptable,_ncate);
 if _trace>=9 then print "After split overall p =" _h _ncate;
  if (ichaid=1 | (_h<1 & _h<_updatep-nxcate#&afuzz)) then do;
  cates=newcate;names=catenm;pv=pvalue;
  flag=1;
  _updatep=_h;
  end;
 *print "catenm" names,"newcate" cates;
 *print "_______________________________________________________________";


  END;

  ELSE CONT=0;
 *print "_updatep = " _updatep;

  end;
 FINISH;


 *________________________START FLOMG_________________________________________*

  Repeat collapsing categories of a floating predictor.

  Input:
  alpham,ptable,nxcate,catenm,newcate: see module ordmg.
  pvalue: suppose are there k categories. If the missing value is
  merged with others then pvalue is the same as that in ordinal
  case. If it is isolated, then pvalue is A|B. A is 1x(k-1) with
  its i-th element being  prob. value between the missing value
  and the (i+1)th category. B is 1x(k-2) with its i-th element
  being the prob. between (i+1)th and (i+2)th category.


  Output: see ordmg.

 *____________________________________________________________________________*;


 START FLOMG(flag,_updatep,CATES,NAMES,PV,NXCATE,PTABLE,ALPHAM,ichaid)
  global(_trace);

  newcate=cates;catenm=names;pvalue=pv;
  flag=0;
  _ncate=nrow(newcate);
  _h=_updatep;
  DOX=1:NXCATE;
  if _ncate<=2 then cont=0;
  else CONT=1;
 *print "_updatep " _updatep;
  DO WHILE (CONT=1);

  NCATE=NROW(NEWCATE);

  IF (NCOL(PVALUE)=2#NCATE-3 & NCATE>2) THEN
  DO;
  DO K=1 TO NCATE-1;
  IF PVALUE[1,K]>&bigp THEN
  DO;
  CTABLE=(NEWCATE[1//K+1,])*PTABLE;
  m=ctable[,+];
  m=m[><];
  PVALUE[1,K]=TABPROB(CTABLE,2);
  END;
  END;

  DO K=NCATE TO 2#NCATE-3;
  IF PVALUE[1,K]>&bigp THEN
  DO;
  CTABLE=NEWCATE[K-NCATE+2:K-NCATE+3,]*PTABLE;
  m=ctable[,+];
  m=m[><];
  PVALUE[1,K]=TABPROB(CTABLE,2);
  END;
  END;


  if _h=_updatep then pv=pvalue;
 *print "pvalue" pv;
 *print "_________________________________________________________________";

  IF PVALUE[<>] > ALPHAM THEN
  DO;
  D=PVALUE[<:>];

  IF D<NCATE THEN
  DO;
  NEWCATE[D+1,1]=1;
  NEWCATE=NEWCATE[2:NCATE,];
  IF SUM(NEWCATE[D,])>2
  THEN CATENM[1,D+1]=MAX(CATENM[<>]+1,NXCATE+1);
  ELSE CATENM[1,D+1]=MAX(SETDIF(DOX,CATENM));
  CATENM=CATENM[1,2:NCATE];
  PVALUE=PVALUE[1,NCATE:2#NCATE-3];
  IF D>1 THEN PVALUE[1,D-1]=&biggerp  ;
  IF D<NCATE-1 THEN PVALUE[1,D]=&biggerp  ;
  END;

  ELSE
  DO;
  D=D-NCATE+2;
  NEWCATE[D,]=NEWCATE[D,]+NEWCATE[D+1,];
  NEWCATE=REMOVE(NEWCATE,D#NXCATE+1:(D+1)#NXCATE);
  NEWCATE=SHAPE(NEWCATE,0,NXCATE);

  IF SUM(NEWCATE[D,])>2 THEN CATENM[1,D]=MAX(CATENM[<>]+1,NXCATE+1);
  ELSE CATENM[1,D]=MAX(SETDIF(DOX,CATENM));
  CATENM=REMOVE(CATENM,D+1);


  PVALUE=REMOVE(PVALUE,D||(D+NCATE-2));
  PVALUE[1,D-1]=&biggerp  ;
  IF D>2 THEN PVALUE[1,D+NCATE-4]=&biggerp  ;
  IF D<NCATE-1 THEN PVALUE[1,D+NCATE-3]=&biggerp  ;
  END;

  if ncate=3 then cont=0;

  _NCATE=NROW(NEWCATE);
  _H=TABPROB(NEWCATE*PTABLE,_NCATE);
 if _trace>=9 then print "After merge overall p =" _h _ncate;
  if (ichaid=1 | _h<min(1,_updatep+&afuzz)) then do;
  cates=newcate;names=catenm;pv=pvalue;
  flag=1;
  _updatep=_h;
  end;

  END;

  ELSE CONT=0;

 *print newcate catenm;
 *if nrow(pvalue)>0 then print pvalue;
  END;

  ELSE
  DO;
  DO J=1 TO NCATE-1;
  IF PVALUE[1,J] > &bigp THEN
  DO;
  CTABLE=NEWCATE[J:J+1,]*PTABLE;
  m=ctable[,+];
  m=m[><];
  PVALUE[1,j]=TABPROB(CTABLE,2);
  END;
  END;
  if _h=_updatep then pv=pvalue;
 *print pvalue;
  IF PVALUE[<>] > ALPHAM  THEN
  DO;
  D=PVALUE[<:>];
  NEWCATE[D,]=NEWCATE[D,]+NEWCATE[D+1,];
  NEWCATE=REMOVE(NEWCATE,D#NXCATE+1:(D+1)#NXCATE);
  NEWCATE=SHAPE(NEWCATE,0,NXCATE);


  IF D>1 THEN PVALUE[1,D-1]=&biggerp  ;
  IF D<NCATE-1 THEN PVALUE[1,D+1]=&biggerp  ;
  PVALUE=REMOVE(PVALUE,D);

  CATENM=REMOVE(CATENM,D+1);
  IF SUM(NEWCATE[D,])>=3 THEN CATENM[1,D]=MAX(CATENM[<>],NXCATE)+1;
  ELSE CATENM[1,D]=MAX(SETDIF(DOX,CATENM));

  IF NCATE=3 THEN CONT=0;

  _NCATE=NROW(NEWCATE);
  _H=TABPROB(NEWCATE*PTABLE,_NCATE);
 if _trace>=9 then print "After merge overall p =" _h _ncate;
  if (ichaid=1 | (_h<1 & _h<_updatep+&afuzz)) then do;
  cates=newcate;names=catenm;pv=pvalue;
  flag=1;
  _updatep=_h;
  end;


  END;
  ELSE CONT=0;
 *print newcate catenm;
 *if nrow(pvalue)>0 then print pvalue;

  END;
 *print "_updatep = " _updatep;

  END;

 FINISH;


 *__________________________START FLOSPL_______________________________________*

  Inspect binary split of each compound category where the predictor is
  floating.

  Inputs and outputs: see ordspl.


 *____________________________________________________________________________*;


 START FLOSPL(FLAG,_updatep,CATES,NAMES,PV,COMPCATE,NXCATE,
  PTABLE,ALPHAS,ichaid)
  global(_trace,_ginturn,_prednam);

  newcate=cates;catenm=names;pvalue=pv;
  _h=_updatep;
  DOX=1:NXCATE;
  FLAG=0;
  cont=1;
  MISCATE=1||J(1,NXCATE-1,0);
 *print "_updatep " _updatep;
  do while (cont=1);
  _ncate=ncol(compcate);

  if _ncate>0 then do;
  COMPCATE=CATENM[1,COMPCATE];
 *print "compcate" compcate;

  DO D=1 TO _ncate;

  J=LOC(CATENM=COMPCATE[1,D]);
  P=&bigp  ;
  POS=LOC(NEWCATE[J,]=1);
  PSPLIT=J(2,NXCATE,0);

  IF NEWCATE[J,1]=0 THEN
  DO K=1 TO NCOL(POS)-1;
  PSPLIT[1,POS[,1:K]]=1;
  PSPLIT[2,]=NEWCATE[J,]-PSPLIT[1,];
  ctable=psplit*ptable;
  m=ctable[,+];
  m=m[><];
  Q=TABPROB(CTABLE,2);

  IF P>Q THEN DO;
  SPLIT=PSPLIT;
  P=Q;
  END;
  END;

  ELSE do;
  SPLIT=PSPLIT;
  SPLIT[1,]=MISCATE;
  SPLIT[2,]=NEWCATE[J,]-MISCATE;
  P=TABPROB(SPLIT*PTABLE,2);
  DO K=2 TO NCOL(POS)-1;
  PSPLIT[1,POS[,1:K]]=1;
  PSPLIT[2,]=NEWCATE[J,]-PSPLIT[1,];
  ctable=psplit*ptable;
  m=ctable[,+];
  m=m[><];
  Q=TABPROB(CTABLE,2);


  IF P>Q THEN DO;
  P=Q;
  SPLIT=PSPLIT;
  END;
  PSPLIT[,1]={0,1};
  Q=TABPROB(PSPLIT*PTABLE,2);
  IF P>Q THEN DO;
  P=Q;
  SPLIT=PSPLIT;
  END;
  END;
  end;
 if _trace>=9 then print _ginturn _prednam
  "Ordfloat split compound category" d "best p" p;
  IF P < ALPHAS THEN
  posbspl=posbspl//(p||compcate[d]||split[1,]||split[2,]);
  ELSE CATENM[1,J]=MAX(SETDIF(DOX,CATENM));
  end;
  free compcate psplit;
  end;
  if _h=_updatep then names=catenm;

  if nrow(posbspl)>0 then do;
 *print "posbspl" posbspl;
  d=posbspl[>:<,1];
  j=loc(catenm=posbspl[d,2]);
  p=posbspl[d,1];
  split=posbspl[d,3:nxcate+2]//posbspl[d,nxcate+3:2#nxcate+2];
  posbspl=remove(posbspl,(2#nxcate+2)#(d-1)+1:(2#nxcate+2)#d);
  if ncol(posbspl)>0 then
  posbspl=shape(posbspl,ncol(posbspl)/(2#nxcate+2));


  ncate=nrow(newcate);

  IF NEWCATE[J,1]=0 THEN do;

  NEWCATE=INSERT(NEWCATE,SPLIT[2,],J+1,0);
  NEWCATE[J,]=SPLIT[1,];

  CATENM=INSERT(CATENM,-1,0,J);
  IF SUM(NEWCATE[J,])>=3 then do;
  CATENM[1,J]=MAX(CATENM[<>],NXCATE)+1;
  compcate=j;
  end;
  ELSE CATENM[1,J]=MAX(SETDIF(DOX,CATENM));


  IF NEWCATE[1,]=MISCATE THEN do;
  PVALUE=INSERT(PVALUE,P,0,NCATE+J-2);
  PVALUE=INSERT(PVALUE,&biggerp  ,0,J);
  PVALUE[1,J-1]=&biggerp  ;
  IF J>2 THEN PVALUE[1,NCATE+J-2]=&biggerp  ;
  IF J<NCATE THEN PVALUE[1,NCATE+J]=&biggerp  ;
  END;
  ELSE do;
  PVALUE=INSERT(PVALUE,P,0,J);
  IF J>1 THEN PVALUE[1,J-1]=&biggerp  ;
  IF J<NCATE THEN PVALUE[1,J+1]=&biggerp  ;
  END;
  END;

  else do;

  IF SPLIT[1,]=MISCATE THEN
  DO;

  CATENM=INSERT(CATENM,MAX(SETDIF(DOX,CATENM)),0,1);

  NEWCATE[J,]=SPLIT[2,];
  NEWCATE=INSERT(NEWCATE,SPLIT[1,],1,0);

  IF NCATE>1 THEN
  DO;
  IF J>1 THEN
  PVALUE[1,J-1]=&biggerp  ;
  IF J<NCATE THEN
  PVALUE[1,J]=&biggerp  ;
  PVALUE=INSERT(
  PVALUE,J(1,NCATE,&biggerp  ),0,1);
  PVALUE[1,J]=P;
  END;
  ELSE PVALUE=P;
  END;


  ELSE
  DO;
  NEWCATE[J,]=SPLIT[1,];
  NEWCATE=INSERT(NEWCATE,SPLIT[2,],J+1,0);

  CATENM=INSERT(CATENM,-1,0,J);
  IF SUM(NEWCATE[J,])>=3 then do;
  CATENM[1,J]=MAX(CATENM[<>],NXCATE)+1;
  compcate=j;
  end;
  ELSE CATENM[1,J]=MAX(SETDIF(DOX,CATENM));

  IF NCATE=1 THEN PVALUE=P;
  ELSE
  DO;
  PVALUE=INSERT(PVALUE,P,0,J);
  IF J>1 THEN PVALUE[1,J-1]=&biggerp  ;
  IF J<NCATE THEN PVALUE[1,J+1]=&biggerp  ;
  END;
  END;
  end;

  IF SUM(NEWCATE[J+1,])>=3 THEN do;
  CATENM[1,J+1]=MAX(CATENM[<>],NXCATE)+1;
  compcate=compcate||j+1;
  end;
  ELSE CATENM[1,J+1]=MAX(SETDIF(DOX,CATENM));

  _ncate=nrow(newcate);
  _h=tabprob(newcate*ptable,_ncate);
 if _trace>=9 then print "After split overall p =" _h _ncate;
  if (ichaid=1 | (_h<1 & _h<_updatep-nxcate#&afuzz)) then do;
  cates=newcate;names=catenm;pv=pvalue;
  _updatep=_h;
  flag=1;
  end;

 *print "catenm" names,"newcate" cates;
 *print "_______________________________________________________________";
  end;
  else cont=0;
 *print "_updatep = " _updatep;

  end;

 FINISH;



 *___________________START MODULE TRDIML_______________________________*;


 START TRDIML(_DEPVAR,_TYPEORD,_TYPENOM,_TYPEFLO,_FREQNM,_DELETE,_parm)
  global(_groupnm,_ginturn,_chisq,_trace,_prednam,_cols) ;



 _alpham=_parm[1];
 _alphas=_parm[2];
 _alphap=_parm[3];
 _maxdpth=_parm[4];
 _nomspl=_parm[5];
 _ordspl=_parm[6];
 _trace=_parm[7];
 _maxread=_parm[8];
 _limit=_parm[9];
 _read=_parm[10];


 IF NROW(_DELETE)=0 THEN _DELETE=0;

 if _trace>=1 then do;
  print 'TREEDISC Analysis of Dependent variable: ' (trim(_depvar));
 end;

 %IF %bquote(&ORDINAL)^= %THEN %do;
  %let npred=&_nord;
  _INDVAR=_INDVAR||(_TYPEORD//J(1,&_nord,'O'));
  %end;
 %IF %bquote(&NOMINAL)^= %THEN %do;
  _INDVAR=_INDVAR||(_TYPENOM//J(1,&_nnom,'N'));
  %let npred=%eval(&npred+&_nnom);
  %end;
 %IF %bquote(&ordfloat)^= %THEN %do;
  _INDVAR=_INDVAR||(_TYPEFLO//J(1,&_norf,'F'));
  %let npred=%eval(&npred+&_norf);
  %end;


 _npred=&npred;

 _J=CHAR(_npred);

 _counts=concat('_ob',_J);
 _counts=rowcatc(_counts);
 _counts='_ob1':_counts;

 _tables=concat('_tb',_J);
 _tables=rowcatc(_tables);
 _tables='_tb1':_tables;

 _J=CONCAT('C_C',_J);
 _J=ROWCATC(_J);
 _J='C_C1':_J;
 _INDVAR=_INDVAR//_J;


 %if &noformat=0 %then %do;
  USE _YCATE_;
  READ ALL;
  %do i=1 %to &npred;
  use _val&i;
  read all;
  c_c&i=&&_var&i;
  %end;
 %end;

 USE &DATA NOBS _N;


 IF _MAXREAD<_N THEN _READ=0;

 _VARNM=_DEPVAR||_INDVAR[1,];

 IF NROW(_FREQNM)>0 THEN  _VARNM=_VARNM||_FREQNM;


 %IF &noformat=1 %THEN %DO;
  _J=CEIL(_N/_MAXREAD);
  DO _K=1 TO _J;
  IF _K<_J THEN READ NEXT &maxread VAR _VARNM;
  ELSE READ AFTER VAR _VARNM ;


  _YCATE_=UNIQUE(&DEPVAR);
  _YCATE=unique(_YCATE||_YCATE_);

  IF _K=_J THEN DO;
  IF NCOL(_YCATE)=1 THEN DO;
  CALL SYMPUT("_XRC_","Dependent variable has only one category");
  GOTO _EXIT;
  END;
  _YCATE=_YCATE`;
  END;

  %do i=1 %to &npred;
  _XCATE=UNIQUE(VALUE(_INDVAR[1,&i]));
  c_c&i=unique(c_c&i||_XCATE);
  IF _K=_J THEN do;
  c_c&i=c_c&i`;
  if _trace>=2 then print
  "Values of " (trim(_INDVAR[1,&i])) ":" (c_c&i`);
  end;
  %end;
  END;


 %END;


 FREE _RX _YCATE_ _FREQVEC _nobs_;


 *_______________START TRDIML PROCEDURE________________________________*;

 IF _MAXREAD=_N THEN _GROUPNM=J(_N,1,1);

 _GINDEX={1,1}//_N//1;


 _NYCATE=NROW(_YCATE);
 _NGROUP=1;



 if _trace>=1 then do;
  print 'Dependent variable (DV): ' (trim(_depvar));
  print 'DV values: ' (_ycate`);
 end;

 _anydesc=0;

 _from_=.;
 _to_=.;
 _order_=0;
 create _tree_ var { _from_ _to_ _order_ };
 append;

 pval1_=.;
 pval2_=.;
 create _stat_ var {_from_ depth_ pval1_ pval2_};
 append;


 DO WHILE (NROW(_GINDEX) > 0) ;



  if _trace>=3 then print 'Active nodes: ' (_gindex[1,]) [format=6.];

  _chisq=-1;
  free _prtpred _prtscal _prtchis _prtprob;

  _r=ncol(_gindex);
  _ginturn=_gindex[1,_r];
  _startpt=_gindex[2,_r];
  _nobs=_gindex[3,_r];
  depth_=_gindex[4,_r];
  if _r>1 then _gindex=_gindex[,1:_r-1];
  else free _gindex;

  _deltmp=1;
  if _ginturn<0 then do;
  _ginturn=(-_ginturn);
  _infp=&bigp  ;
  _deltmp=0;
  goto splitout;
  end;

  if _trace>=1 then print '---------------------- Split node: '
  _ginturn [format=6.];

  if _maxread=_n then do;
  _LOCA=LOC(_GROUPNM=_GINTURN);
  IF _READ>0 THEN DO;
  if _ginturn=1 then do;
  close &data;
  use &data;
  read all var _varnm;
  if _delete>0 then call delete(&data);
  end;
  _DVAR=VALUE(_DEPVAR)[_LOCA,1];
  IF NROW(_FREQNM)>0 THEN _FREQVEC=VALUE(_FREQNM)[_LOCA,1];
  END;
  ELSE DO;
  close &data;
  use &data;
  READ POINT _LOCA VAR _VARNM ;


  _DVAR=VALUE(_DEPVAR);

  IF NROW(_FREQNM)>0 THEN DO;
  _FREQVEC=VALUE(_FREQNM);
  FREE &DEPVAR &FREQ;
  END;
  ELSE FREE &DEPVAR;
  END;
  end;
  else do;
  create _chatmp_ var _varnm;
  close &data;
  use &data;
  if _startpt>1 then read point (_startpt-1) var _depvar;
  end;


  %do i=1 %to &npred;
  _nxcate=nrow(c_c&i);
  _tb&i=j(_nxcate,_nycate,0);
  _ob&i=j(_nxcate,1,0);
  %end;

  _J=CEIL(_NOBS/_MAXREAD);
  DO _K=1 TO _J;
  IF _maxread<_n then do;
  if _K=_J THEN
  read point (_startpt+(_j-1)#_maxread:_startpt+_nobs-1) var _varnm;
  else READ NEXT &maxread VAR _VARNM;
  append;
  _dvar=value(_depvar);
  free &depvar;
  if nrow(_freqnm)>0 then do;
  _freqvec=value(_freqnm);
  free &freq;
  end;
  end;


  %do i=1 %to &npred;
  _XCATE=c_c&i;
  _nxcate=nrow(_xcate);
  _PTABLE=J(_NXCATE,_NYCATE,0);
  if _read>0 THEN _PVAR=VALUE(_indvar[1,&I])[_LOCA];
  else _pvar=value(_indvar[1,&i]);

  DO _R=1 TO _NXCATE;
  _RX=LOC(_PVAR=_XCATE[_R,1]);
  _ob&i[_r]=_ob&i[_r]+ncol(_rx);
  IF NROW(_RX)=0 THEN _PTABLE[_R,]=0;
  ELSE DO;
  DO _S=1 TO _NYCATE-1;
  IF NROW(_FREQNM)=0 THEN
  _PTABLE[_R,_S]=NCOL(LOC(_DVAR[_RX]=_YCATE[_S,1]));
  ELSE DO;
  _M=LOC(_DVAR[_RX]=_YCATE[_S,1]);
  IF NROW(_M)=0 THEN _PTABLE[_R,_S]=0;
  ELSE _PTABLE[_R,_S]=SUM(_FREQVEC[_RX[_M]]);
  END;
  END;
  IF NROW(_FREQNM)=0 THEN
  _PTABLE[_R,_NYCATE]=NCOL(_RX)-SUM(_PTABLE[_R,]);
  ELSE  _PTABLE[_R,_NYCATE]=SUM(_FREQVEC[_RX])-SUM(_PTABLE[_R,]);
  END;
  END;
  _tb&i=_tb&i+_ptable;
  %end;


  END;
  free _dvar _pvar;
  if _maxread<_n then read point 1;


  _INFP=&bigp  ;
  _optscal=' ';

  _nomord=0;
  if nrow(_typenom)>0 then do;
  _rx=loc(_tb1[+,]>0);
  if ncol(_rx)=2 then _nomord=1;
  end;

  DO _I=1 TO _npred;

  _prednam=trim(_indvar[1,_i]);
  if _trace>=4 then print "Begin processing " _ginturn _prednam;

  _XCATE=value(_indvar[3,_i]);


  _ptable=value(_tables[_i]);



  _RX=LOC(_PTABLE[,+]>0);
  _XCATE=_XCATE[_RX,1];
  _NXCATE=NROW(_XCATE);

  if _trace>=6 then do;
  print "Full contingency table for: " _prednam;
  print (_ptable);
  end;


  _PTABLE=_PTABLE[_RX,];

  if _trace>=5 then do;
  print "Contingency table with zeros suppressed for: " _prednam;
  print (_ptable);
  end;

  _bonmult=1;

  IF _NXCATE<=1 THEN do;
  if _trace>=3 then
  print "   Cannot split on " _prednam
  ", only one nonzero category";

  end;
  else DO;

  _DOX=1:_NXCATE;
  _NEWCATE=I(_NXCATE);
  _CATENM=_DOX-1;
  _updatep=tabprob(_ptable,_nxcate);

  IF (_INDVAR[2,_I]={F} & _rx[1]=1) THEN
  DO;
  _scale='OrdFloat';
  _PVALUE= J(1,2#_NXCATE-3,&biggerp);

  do _loop=(-_nxcate) to _limit;
  RUN FLOMG(_FLAG,_updatep,_NEWCATE,_CATENM,_PVALUE,
  _NXCATE,_PTABLE,_ALPHAM,&ichaid);
  _CMPCATE=LOC(_CATENM>_NXCATE);
  IF (NROW(_CMPCATE)>0 & _flag=1) THEN
  RUN FLOSPL(_FLAG,_updatep,_NEWCATE,_CATENM,_PVALUE,
  _CMPCATE,_NXCATE,_PTABLE,_ALPHAS,&ichaid);
  IF _FLAG=0 THEN _loop=_limit;
  end;
  if _flag then do;
  print "ERROR: Loop limit exceeded processing" _prednam
  "in node" _ginturn;
  stop;
  end;


  _NCATE=NROW(_NEWCATE);

  _m=_newcate*_ptable;
  _H=tabprob(_m,_ncate);

  if _h<1 then do;
  _bonmult=^(&bonf);
  %if &bonf>=1 %then %do;
  _DOX=LOG(_DOX);
  %end;
  %if &bonf>=2 %then %do;
  do _ncate=2 to _nxcate;
  %end;
  %if &bonf>=1 %then %do;
  if _ncate=_nxcate then _temp=1;
  else do;
  _temp=EXP(SUM(_DOX[1,_NCATE:_NXCATE-1])-
  SUM(_DOX[1,1:_NXCATE-_NCATE]));
  _temp=_temp#(_NXCATE#_NCATE+_NCATE-_NCATE##2-1);
  _temp=_temp/(_NXCATE-1);
  end;
  _bonmult=_bonmult+_temp;
  %end;
  %if &bonf>=2 %then %do;
  end;
  %end;
  %if &bonf>=3 %then %do;
  _bonmult=_bonmult#_npred;
  %end;
  %if &bonf>=1 %then %do;
  _H=_H#_BONMULT;
  IF _H>1 THEN _H=1;
  %end;
  %if &gabriel %then %do;
  %if &bonf>=0 %then %do;
  _H=min(_H,pvalue(_chisq,_nxcate,_cols));
  %end;
  %else %do;
  _H=pvalue(_chisq,_nxcate,_cols);
  %end;
  %end;
  END;

  END;

  ELSE IF _INDVAR[2,_I]={N} THEN
  DO;
  _scale='Nominal ';

  if _nomord=0 then do;
  _PVALUE=J(_NXCATE-1,_NXCATE-1,&biggerp);

  do _loop=(-_nxcate) to _limit;
  RUN NOMMG(_flag,_updatep,_NEWCATE,_CATENM,_PVALUE,
  _NXCATE,_PTABLE,_ALPHAM,&ichaid);
  _CMPCATE=LOC(_CATENM>_NXCATE);
  IF (NROW(_CMPCATE)>0 & _flag=1) THEN
  RUN NOMSPL(_FLAG,_updatep,_NEWCATE,_CATENM,_PVALUE,
  _CMPCATE,_NXCATE,_PTABLE,_ALPHAS,_nomspl,&ichaid);
  IF _FLAG=0 THEN _loop=_limit;
  end;
  end;
  else do;
  _dvindex=loc(_ptable[+,]>0);
  _ptable=_ptable[,_dvindex];
  _j=rank(_ptable[,1]/_ptable[,+]);
  _temp=_ptable[,1];_ptable[_j,1]=_temp;
  _temp=_ptable[,2];_ptable[_j,2]=_temp;
  _temp=_xcate;_xcate[_j]=_temp;


  _PVALUE=J(1,_NXCATE-1,&biggerp);

  do _loop=(-_nxcate) to _limit;
  RUN ORDMG(_flag,_updatep,_NEWCATE,_CATENM,_PVALUE,_NXCATE,
  _PTABLE,_ALPHAM,&ichaid);
  _CMPCATE=LOC(_CATENM>_NXCATE);
  IF (NROW(_CMPCATE)>0 & _flag=1) THEN
  RUN ORDSPL(_FLAG,_updatep,_NEWCATE,_CATENM,_PVALUE,
  _CMPCATE,_NXCATE,_PTABLE,_ALPHAS,_ordspl,&ichaid);
  IF _FLAG=0 THEN _loop=_limit;
  end;
  end;

  if _flag then do;
  print "ERROR: Loop limit exceeded processing" _prednam
  "in node" _ginturn;
  stop;
  end;

  _NCATE=NROW(_NEWCATE);

  _m=_newcate*_ptable;
  _H=tabprob(_m,_ncate);

  if _h<1 then do;
  _bonmult=^(&bonf);
  %if &bonf>=2 %then %do;
  do _ncate=2 to _nxcate;
  %end;
  %if &bonf>=1 %then %do;
  if _ncate=_nxcate then _temp=1;
  else do;
  _ADD=LOG(DO(1,_NCATE,1));
  _ADD=EXP(-SUM(_ADD));
  _temp=_NCATE##_NXCATE#_ADD;
  DO _L=_NCATE TO 2 BY -1 ;
  _ADD=-_ADD#_L/(_NCATE-_L+1);
  _temp=_temp+(_L-1)##_NXCATE#_ADD;
  END;
  end;
  _bonmult=_bonmult+_temp;
  %end;
  %if &bonf>=2 %then %do;
  end;
  %end;
  %if &bonf>=3 %then %do;
  _bonmult=_bonmult#_npred;
  %end;
  %if &bonf>=1 %then %do;
  _H=_H#_BONMULT;
  IF _H>1 THEN _H=1;
  %end;
  %if &gabriel %then %do;
  %if &bonf>=0 %then %do;
  _H=min(_H,pvalue(_chisq,_nxcate,_cols));
  %end;
  %else %do;
  _H=pvalue(_chisq,_nxcate,_cols);
  %end;
  %end;
  END;


  END;

  ELSE
  DO;
  _scale='Ordinal ';
  _PVALUE=J(1,_NXCATE-1,&biggerp);

  do _loop=(-_nxcate) to _limit;
  RUN ORDMG(_flag,_updatep,_NEWCATE,_CATENM,_PVALUE,
  _NXCATE,_PTABLE,_ALPHAM,&ichaid);
  _CMPCATE=LOC(_CATENM>_NXCATE);
  IF (NROW(_CMPCATE)>0 & _flag=1) THEN
  RUN ORDSPL(_FLAG,_updatep,_NEWCATE,_CATENM,_PVALUE,
  _CMPCATE,_NXCATE,_PTABLE,_ALPHAS,_ordspl,&ichaid);
  IF _FLAG=0 THEN _loop=_limit;
  end;
  if _flag then do;
  print "ERROR: Loop limit exceeded processing" _prednam
  "in node" _ginturn;
  stop;
  end;

  _NCATE=NROW(_NEWCATE);
  _m=_newcate*_ptable;
  _H=tabprob(_m,_ncate);

  if _h<1 then do;
  _bonmult=^(&bonf);
  %if &bonf>=1 %then %do;
  _DOX=LOG(_DOX);
  %end;
  %if &bonf>=2 %then %do;
  do _ncate=2 to _nxcate;
  %end;
  %if &bonf>=1 %then %do;
  if _ncate=_nxcate then _temp=1;
  else do;
  _temp=EXP(SUM(_DOX[1,_NCATE:_NXCATE-1])-
  SUM(_DOX[1,1:_NXCATE-_NCATE]));

  end;
  _bonmult=_bonmult+_temp;
  %end;
  %if &bonf>=2 %then %do;
  end;
  %end;
  %if &bonf>=3 %then %do;
  _bonmult=_bonmult#_npred;
  %end;
  %if &bonf>=1 %then %do;
  _H=_H#_BONMULT;
  IF _H>1 THEN _H=1;
  %end;
  %if &gabriel %then %do;
  _gabp=pvalue(_chisq,_nxcate,_cols);
  %if &bonf>=0 %then %do;
  _H=min(_H,_gabp);
  %end;
  %else %do;
  _H=_gabp;
  %end;
  %end;
  END;


  END;
  _m=0;

  if _trace>=4 then do;
  print "Final contingency table for: " (trim(_indvar[1,_i]));
  print (_newcate*_ptable);
  end;

  if _trace>=3 then print '   Consider split: ' (trim(_indvar[1,_i]))
  _scale "Chi**2 =" _chisq [format=8.2]
  "Adj p =" _h [format=&pformat]
  "Bon mult =" _bonmult;

  if _h<&bigp then do;
  _prtpred=_prtpred//_indvar[1,_i];
  _prtscal=_prtscal//_scale;
  _prtchis=_prtchis//_chisq;
  _prtprob=_prtprob//_h;
  end;

  IF _H<=_INFP THEN
  DO;
  _INFP=_H;
  _OPTCATE=_NEWCATE;
  _OPTPRED=_indvar[1,_I];
  if _maxread=_n then do;
  if _read>0 THEN _predval=VALUE(_indvar[1,_I])[_LOCA];
  else _predval=value(_indvar[1,_i]);
  end;
  _nobsvec=value(_counts[_i]);
  _nobsvec=_nobsvec[_rx,];
  if _nomord=1 & _indvar[2,_i]={n} then do;
  _temp=_nobsvec;
  _nobsvec[_j]=_temp;
  _opttab=j(ncol(_rx),_nycate,0);
  _opttab[,_dvindex]=_ptable;
  _ptable=_opttab;
  end;
  _OPTTAB=_OPTCATE*_PTABLE;
  _nobsvec=_newcate*_nobsvec;
  _PRDCATE=_XCATE;
  _optscal=_scale;
  END;
  END;


  END;



  if nrow(_prtprob) then do;
  _prtrank=rank(_prtprob);
  _temp=_prtpred; _prtpred[_prtrank]=_temp;
  _temp=_prtscal; _prtscal[_prtrank]=_temp;
  _temp=_prtchis; _prtchis[_prtrank]=_temp;
  _temp=_prtprob; _prtprob[_prtrank]=_temp;
  %if &printp>=0  %then %do;
  _temp=max(2,&printp);
  _prtpred=_prtpred[1:_temp];
  _prtscal=_prtscal[1:_temp];
  _prtchis=_prtchis[1:_temp];
  _prtprob=_prtprob[1:_temp];
  %end;
  %if &printp %then %do;
  %if &printp<0 %then %do;
  if _trace>=2 then do;
  %end;
  _hdrpred="Predictor";
  _hdrscal="Type";
  _hdrchis="Chi-Square";
  _hdrprob="Adjusted p";
  %if &printp>0 %then
  print "Best &printp Splits Considered for Node";
  %else
  print "Splits Considered for Node";
  _ginturn [format=6.];
  print _prtpred [colname=_hdrpred]
  _prtscal [colname=_hdrscal]
  _prtchis [colname=_hdrchis format=8.2]
  (&pmin<>_prtprob) [colname=_hdrprob format=&pformat];
  %if &printp<0 %then %do;
  end;
  %end;
  %end;
  if _trace>=1 then print 'Best split: ' (trim(_optpred))
  (trim(_optscal)) "with p ="  _infp [format=&pformat];


  if _trace>=3 then do;
  print "Best contingency table for: " (trim(_optpred));
  print (_opttab);
  end;
  end;
  else do;
  if _trace>=1 then print 'No possible split';
  end;

 splitout:
  _from_=_ginturn;
  pval1_=.;
  pval2_=.;
  setout _stat_;
  if nrow(_prtprob)>=1 then do;
  pval1_=_infp;
  if nrow(_prtprob)>=2 then pval2_=_prtprob[2];
  end;
  append;

  IF _INFP>=_ALPHAP THEN do;
  if _infp<&bigp
  then if _trace>=1 then print '*** Reject split';

  _from_=_ginturn;
  _to_=.;
  _order_=_order_+1;
  setout _tree_;
  append;

  end;

  else DO;

  if _trace>=1 then print '*** Perform split';

  if _anydesc=0 then do;
  _anydesc=1;


  * outtree;
  _from_=1;
  _type_='SPLIT_  ';
  _value_={'                '};
  create _desc_ var {_from_ _type_ _value_ };
  _value_=_depvar;
  append;
  _type_='TYPE_';
  _value_=type(_ycate);
  append;
  _type_='VALUES_';
  do _m=1 to _nycate;
  if type(_ycate)={C}
  then _value_=_ycate[_m];
  else _value_=char(_ycate[_m]);
  append;
  end;
  _type_='COUNT_';
  do _m=1 to ncol(_opttab);
  _value_=char(_opttab[+,_m]);
  append;
  end;
  end;

  depth_=depth_+1;
  _L=NROW(_OPTCATE);

  DO _K=_L to 1 by -1;
  _locate=LOC(_OPTCATE[_K,]=1);
  _A_=_PRDCATE[_locate,];


  _NAME=_NGROUP+_K;


  if _trace>=1 then do;
  print '   New node: ' _name [format=6.]
  (trim(_optpred)) "=" (_a_`);
  print '       DV count: ' (_opttab[_k,]) [format=8.];
  end;


  _h=1;
  _gobs=_OPTTAB[_K,+];
  if depth_=_maxdpth+1 then do;
  if _trace>=1 then print '       Depth is ' _maxdpth [format=8.];
  end;
  else IF _gobs<&branch then do;
  if _trace>=1 then print
  "        Number of obs " _gobs [format=8.]
  "is less than BRANCH=&branch";
  end;
  else if ncol(loc(_opttab[_k,]))<=1 THEN do;
  if _trace>=1 then print
  '       Only one nonempty category of DV';
  end;
  else do;
  _gindex=_gindex||(_name//0//_nobsvec[_k]//depth_);
  _h=0;
  end;


  if _h then
  _GINDEX=_GINDEX||(-_NAME//0//_nobsvec[_k]//depth_);

  if _maxread=_n then do;
  _INDSTR=0;
  DO _M=1 TO NROW(_A_);
  _INDSTR=INSERT(_INDSTR,LOC(_PREDVAL=_A_[_M,]),0,1);
  END;
  _INDSTR=_INDSTR[1:ncol(_indstr)-1];
  _INDSTR=_LOCA[1,_INDSTR];
  _GROUPNM[_INDSTR,1]=_NAME;
  end;

  _from_=_ginturn;
  _to_=_name;
  _order_=_order_+1;
  setout _tree_;
  append;

  setout _desc_;
  _from_=_name;
  _type_='SPLIT_';
  _value_=_optpred;
  append;
  _type_='SCALE_';
  _value_=upcase(_optscal);
  append;
  _type_='TYPE_';
  _value_=TYPE(_A_);
  append;


  if upcase(_optscal)={ORDINAL} then do;

  _type_='UPPERB_';
  if _k=_l then _value_=' ';
  else if type(_a_)={C} then _value_=_a_[nrow(_a_)];
  else do;
  _h=_locate[ncol(_locate)];
  _value_=_prdcate[_h];
  if nmiss(_value_) then do;
  _value_='.';
  end;
  else do;
  _m=_prdcate[_h+1];
  if nmiss(_m) then _value_=char(_value_);
  else _value_=char((_value_+_m)/2);
  end;
  end;
  append;

  _type_='LOWERB_';
  if type(_a_)={C} then do;
  if _k=1 then _value_=' ';
  else _value_=_a_[1];
  end;
  else do;
  _h=_locate[1];
  _value_=_prdcate[_h];
  if nmiss(_value_) then do;
  _value_='.';
  end;
  else do;
  if _k=1 then _value_="&neginf";
  else do;
  _m=_prdcate[_h-1];
  if nmiss(_m) then _value_="&neginf";
  else _value_=char((_value_+_m)/2);
  end;
  end;
  end;
  append;


  end;

  IF type(_a_)={N} THEN _A_=CHAR(_A_);
  _type_='VALUES_';
  do _m=1 to nrow(_a_);
  _value_=_a_[_m];
  append;
  end;
  _type_='COUNT_';
  do _m=1 to ncol(_opttab);
  _value_=char(_opttab[_k,_m]);
  append;
  end;

  FREE _INDSTR;

  END;


  _rx=do(ncol(_gindex)-_l+1,ncol(_gindex),1);
  _nobsvec=_gindex[3,_rx];
  _nobsvec=cusum(_nobsvec);
  _nobsvec=remove(_nobsvec,_L);
  _nobsvec=0||_nobsvec;
  _nobsvec=_nobsvec+_startpt;
  _gindex[2,_rx]=_nobsvec;

  if _maxread<_n then do;
  _temp=_nobsvec;
  _nobsvec[do(_l,1,-1)]=_temp;
  _i=ceil(_nobs/_maxread);
  do _j=1 to _i;
  edit _chatmp_;
  if _j=_i then _rx=(_j-1)#_maxread+1:_nobs;
  else _rx=(_j-1)#_maxread+1:_j#_maxread;
  read point _rx var _varnm;
  DO _K=_L to 1 by -1;
  _A_=_PRDCATE[LOC(_OPTCATE[_K,]=1),];
  do _m=1 to nrow(_a_);
  _loca=loc(value(_optpred)=_a_[_m]);
  _h=ncol(_loca);
  if _h>0 then do;
  _temp=_nobsvec[_k];
  _nobsvec[_k]=_temp+_h;
  _rx[_loca]=do(_temp,_temp+_h-1,1);
  end;
  end;
  end;


  edit &data;
  replace point _rx var _varnm;

  end;
  end;

  _NGROUP=_NGROUP+_L;
  FREE _PREDVAL;

  END;

  if _deltmp=1 & _maxread<_n then  call delete(_chatmp_);

 END;

 if _anydesc=0 then do;
  if _trace>=1 then print
  "There are no significant factors in this analysis.";
  reset log;
  print "NOTE: There are no significant factors in this analysis.";
  _from_=1;
  _type_='SPLIT_';
  _value_={'                '};
  create _desc_ var {_from_ _type_ _value_ };
  _value_=_depvar;
  append;
  _type_='TYPE_';
  _value_=type(_ycate);
  append;
  _type_='VALUES_';
  do _m=1 to _nycate;
  if type(_ycate)={C}
  then _value_=_ycate[_m];
  else _value_=char(_ycate[_m]);
  append;
  end;
  _type_='COUNT_';
  do _m=1 to ncol(_opttab);
  _value_=char(_opttab[+,_m]);
  append;
  end;


 end;

 close _desc_;
 setout _tree_; delete point 1; close _tree_;
 setout _stat_; delete point 1; close _stat_;

 call symput("_xrc_","OK");

 GOTO _EXIT;

 END_PGM:

  reset log;
  PRINT "NOTE: TRDIML terminated due to errors.";

 _EXIT:


 FINISH;

 *___________________________END MODULE TRDIML_________________________*;

 run trdiml(depvar,&mord,&mnom,&mflo,&mfreq,&del,parm);

 quit;

 %mend mtrdiml;

 %* close comment possibly generated by xmacro */;


  ************************************************************;
  ******************* END TREEDISC MACRO *********************;
  ************************************************************;
