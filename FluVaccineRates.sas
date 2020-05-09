/* 
************************************************************************
Scrub the region level and national level data. Leaves state data only
************************************************************************
*/
PROC SQL; 
CREATE TABLE WORK.States_Only 
AS 
SELECT CLEANFLU.Names, CLEANFLU.Year, CLEANFLU.Percent, CLEANFLU.LL, CLEANFLU.UL, CLEANFLU.CI, CLEANFLU.SAMPLE, CLEANFLU.TARGET 
FROM WORK.CLEANFLU CLEANFLU /*Flu dataset from CDC */
WHERE 
   ( CLEANFLU.Names NOT IN 
      ( 'Region  1           ', 'Region  2           ', 'Region  3           ', 'Region  4           ', 'Region  5           ', 'Region  6           ', 'Region  7           ', 'Region  8           ', 'Region  9           ', 'Region 10           ', 'United States       ' ) 
   ) ; 
QUIT;

%web_open_table(WORK.States_Only);

/* 
************************************************************************
SAS Code to create descriptive statics and distribution analysis from 
the percent data. 
************************************************************************
*/
ods noproctitle;
ods graphics / imagemap=on;

proc means data=WORK.STATES_ONLY chartype mean std min max n vardef=df;
	var Percent;
run;

/* Graph template to construct combination histogram/boxplot */
proc template;
	define statgraph histobox;
		dynamic AVAR ByVarInfo;
		begingraph;
		entrytitle "Distribution of " AVAR ByVarInfo;
		layout lattice / rows=2 columndatarange=union rowgutter=0 rowweights=(0.75 
			0.25);
		layout overlay / yaxisopts=(offsetmax=0.1) xaxisopts=(display=none);
		histogram AVAR /;
		endlayout;
		layout overlay /;
		BoxPlot Y=AVAR / orient=horizontal;
		endlayout;
		endlayout;
		endgraph;
	end;
run;

/* Macro to subset data and create a histobox for every by group */
%macro byGroupHistobox(data=, level=, num_level=, byVars=, num_byvars=, avar=);
	%do j=1 %to &num_byvars;
		%let varName&j=%scan(%str(&byVars), &j);
	%end;

	%do i=1 %to &num_level;

		/* Get group variable values */
		data _null_;
			i=&i;
			set &level point=i;

			%do j=1 %to &num_byvars;
				call symputx("x&j", strip(&&varName&j), 'l');
			%end;
			stop;
		run;

		/* Build proc sql where clause */
        %let dsid=%sysfunc(open(&data));
		%let whereClause=;

		%do j=1 %to %eval(&num_byvars-1);
			%let varnum=%sysfunc(varnum(&dsid, &&varName&j));

			%if(%sysfunc(vartype(&dsid, &varnum))=C) %then
				%let whereClause=&whereClause.&&varName&j.="&&x&j"%str( and );
			%else
				%let whereClause=&whereClause.&&varName&j.=&&x&j.%str( and );
		%end;
		%let varnum=%sysfunc(varnum(&dsid, &&varName&num_byvars));

		%if(%sysfunc(vartype(&dsid, &varnum))=C) %then
			%let whereClause=&whereClause.&&varName&num_byvars.="&&x&num_byvars";
		%else
			%let whereClause=&whereClause.&&varName&num_byvars.=&&x&num_byvars;
		%let rc=%sysfunc(close(&dsid));

		/* Subset the data set */
		proc sql noprint;
			create table WORK.tempData as select * from &data
            where &whereClause;
		quit;

		/* Build plot group info */
        %let groupInfo=;

		%do j=1 %to %eval(&num_byvars-1);
			%let groupInfo=&groupInfo.&&varName&j.=&&x&j%str( );
		%end;
		%let groupInfo=&groupInfo.&&varName&num_byvars.=&&x&num_byvars;

		/* Create histogram/boxplot combo plot */
		proc sgrender data=WORK.tempData template=histobox;
			dynamic AVAR="&avar" ByVarInfo=" (&groupInfo)";
		run;

	%end;
%mend;

proc sgrender data=WORK.STATES_ONLY template=histobox;
	dynamic AVAR="Percent" ByVarInfo="";
run;

proc datasets library=WORK noprint;
	delete tempData;
	run;